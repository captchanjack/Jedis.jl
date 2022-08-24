using Base: StatusEOF, StatusClosing, StatusClosing, StatusClosing, StatusPaused, StatusActive, StatusOpen,
    LibuvStream, UV_ECONNABORTED, UV_ECONNREFUSED, UV_ENOBUFS, UV_EOF, UV_ETIMEDOUT, TTY, _UVError, @handle_as, 
    notify_filled, notify, uv_alloc_buf, iolock_begin, iolock_end, preserve_handle, unpreserve_handle, 
    stop_reading, uv_error, StringVector

"""
    keepalive!(socket::TCPSocket, enable::Cint, delay::Cint)

Sets keep-alive of a TCP socket. Set `enable` as `1` to enable, `0` to disable. Set `delay` 
seconds for each keep-alive packet, ignored when `enable` is `0`. After delay has been reached, 
10 successive probes, each spaced 1 second from the previous one, will still happen. If the 
connection is still lost at the end of this procedure, then the handle is destroyed with a 
UV_ETIMEDOUT error passed to the corresponding callback.
"""
keepalive!(socket::TCPSocket, enable::Cint, delay::Cint) = ccall(:uv_tcp_keepalive, Cint, (Ptr{Nothing}, Cint, Cuint), socket.handle, enable, delay)

"""
    isactive(socket::TCPSocket)

Returns non-zero if the handle is active, zero if it’s inactive. Is active when it is doing 
something that involves i/o, like reading, writing, connecting, accepting new connections, etc.
"""
isactive(socket::TCPSocket) = ccall(:uv_is_active, Cint, (Ptr{Cvoid},), socket.handle)

"""
    netstat(port::Int)::Vector

Calls CLI tool `netstat` to get TCP connection statistics over a specific port.
Returns a vector os lines, each line represents (Proto, Recv-Q, Send-Q, Local Address, Foreign Address, state).
"""
function netstat(port::Int)::Vector
    try
        return [split(line) for line in readlines(pipeline(`netstat -na`, `grep $port`))]
    catch
        # Catches null pipeline
    end
    return
end

"""
    tcpstate(src_host::String, src_port::Int, dst_host::String, dst_port::Int)

Returns the TCP state given source and destination host and ports.
"""
function tcpstate(src_host::String, src_port::Int, dst_host::String, dst_port::Int)
    stats = netstat(src_port)
    isempty(stats) && return
    for (_, _, _, src_addr, dst_addr, state) in stats
        if (
            occursin(src_host, src_addr) &&
            occursin(string(src_port), src_addr) &&
            occursin(dst_host, dst_addr) &&
            occursin(string(dst_port), dst_addr)
        )
            return state
        end
    end
    return
end

"""
    tcpstate(socket::TCPSocket)

Returns TCP state given a socket object.
"""
function tcpstate(socket::TCPSocket)
    src_host, src_port = hostport(socket)
    dst_host, dst_port = peerhostport(socket)
    return tcpstate(src_host, src_port, dst_host, dst_port)
end

"""
    hostport(socket::TCPSocket)

Returns host and port given a socket object.
"""
function hostport(socket::TCPSocket)
    host, port = getsockname(socket)
    return string(host), Int(port)
end

"""
    hostport(socket::TCPSocket)

Returns host and port for a peer given a socket object.
"""
function peerhostport(socket::TCPSocket)
    host, port = getpeername(socket)
    return string(host), Int(port)
end

"""
    tryclose(socket::TCPSocket)

Closes a TCP socket connection if the TCP state is `CLOSE_WAIT`.
"""
function tryclose(socket::TCPSocket)
    if isactive(socket) == 0 tcpstate(socket) == "CLOSE_WAIT"
        close(socket)
    end
end

"""
    _uv_readcb(handle::Ptr{Cvoid}, nread::Cssize_t, buf::Ptr{Cvoid})

Taken from Base "stream.jl", adjusted to close redis client sockets correctly and raise
exception to subscription client on callback of server connection closing.
"""
function _uv_readcb(handle::Ptr{Cvoid}, nread::Cssize_t, buf::Ptr{Cvoid})
    stream_unknown_type = @handle_as handle LibuvStream
    nrequested = ccall(:jl_uv_buf_len, Csize_t, (Ptr{Cvoid},), buf)
    function readcb_specialized(stream::LibuvStream, nread::Int, nrequested::UInt)
        lock(stream.cond)
        try
            if nread < 0
                if nread == UV_ENOBUFS && nrequested == 0
                    # remind the client that stream.buffer is full
                    notify(stream.cond)
                elseif nread == UV_EOF
                    if isa(stream, TTY)
                        stream.status = StatusEOF # libuv called uv_stop_reading already
                        notify(stream.cond)
                    elseif stream.status != StatusClosing
                        # begin shutdown of the stream

                        # Line added to terminate subscriptions
                        stream.readerror = _UVError("readline", UV_ECONNABORTED)
                        
                        ccall(:jl_close_uv, Cvoid, (Ptr{Cvoid},), stream.handle)
                        stream.status = StatusClosing
                    end
                elseif nread == UV_ETIMEDOUT
                    # TODO: put keepalive timeout callback here
                else
                    stream.readerror = _UVError("read", nread)
                    # This is a fatal connection error. Shutdown requests as per the usual
                    # close function won't work and libuv will fail with an assertion failure
                    ccall(:jl_forceclose_uv, Cvoid, (Ptr{Cvoid},), stream)
                    stream.status = StatusClosing
                    notify(stream.cond)
                end
            else
                notify_filled(stream.buffer, nread)
                notify(stream.cond)
            end
        finally
            unlock(stream.cond)
        end

        # Stop background reading when
        # 1) there's nobody paying attention to the data we are reading
        # 2) we have accumulated a lot of unread data OR
        # 3) we have an alternate buffer that has reached its limit.
        if stream.status == StatusPaused ||
           (stream.status == StatusActive &&
            ((bytesavailable(stream.buffer) >= stream.throttle) ||
             (bytesavailable(stream.buffer) >= stream.buffer.maxsize)))
            # save cycles by stopping kernel notifications from arriving
            ccall(:uv_read_stop, Cint, (Ptr{Cvoid},), stream)
            stream.status = StatusOpen


            # Line added to close socket when server connection breaks
            # Closes the connection if the TCP state is CLOSE_WAIT
            # Must be called asynchronously
            # TODO: Differentiate UV_ENOBUFS event with server close event
            # @async tryclose(stream)
        end
        nothing
    end
    readcb_specialized(stream_unknown_type, Int(nread), UInt(nrequested))
end

function _start_reading(stream::LibuvStream)
    iolock_begin()
    if stream.status == StatusOpen
        if !isreadable(stream)
            error("tried to read a stream that is not readable")
        end
        # libuv may call the alloc callback immediately
        # for a TTY on Windows, so ensure the status is set first
        stream.status = StatusActive
        ret = ccall(:uv_read_start, Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
                    stream, @cfunction(uv_alloc_buf, Cvoid, (Ptr{Cvoid}, Csize_t, Ptr{Cvoid})),
                    @cfunction(_uv_readcb, Cvoid, (Ptr{Cvoid}, Cssize_t, Ptr{Cvoid})))
    elseif stream.status == StatusPaused
        stream.status = StatusActive
        ret = Int32(0)
    elseif stream.status == StatusActive
        ret = Int32(0)
    else
        ret = Int32(-1)
    end
    iolock_end()
    return ret
end

_readuntil_string(s::IO, delim::UInt8, keep::Bool) = String(_readuntil(s, delim, keep=keep))::String

function _readuntil(s::IO, delim::AbstractChar; keep::Bool=false)
    if delim ≤ '\x7f'
        return _readuntil_string(s, delim % UInt8, keep)
    end
    out = IOBuffer()
    for c in readeach(s, Char)
        if c == delim
            keep && write(out, c)
            break
        end
        write(out, c)
    end
    return String(take!(out))
end

function _readuntil(s::IO, delim::T; keep::Bool=false) where T
    out = (T === UInt8 ? StringVector(0) : Vector{T}())
    for c in readeach(s, T)
        if c == delim
            keep && push!(out, c)
            break
        end
        push!(out, c)
    end
    return out
end

function _readuntil(x::LibuvStream, c::UInt8; keep::Bool=false)
    iolock_begin()
    buf = x.buffer
    @assert buf.seekable == false
    if !occursin(c, buf) # fast path checks first
        x.readerror === nothing || throw(x.readerror)
        if isopen(x)
            preserve_handle(x)
            lock(x.cond)
            try
                while !occursin(c, x.buffer)
                    x.readerror === nothing || throw(x.readerror)
                    isopen(x) || break
                    _start_reading(x) # ensure we are reading
                    iolock_end()
                    wait(x.cond)
                    unlock(x.cond)
                    iolock_begin()
                    lock(x.cond)
                end
            finally
                if isempty(x.cond)
                    stop_reading(x) # stop reading iff there are currently no other read clients of the stream
                end
                unlock(x.cond)
                unpreserve_handle(x)
            end
        end
    end
    bytes = _readuntil(buf, c, keep=keep)
    iolock_end()
    return bytes
end

function _readline(s::IO=stdin; keep::Bool=false)
    line = _readuntil(s, 0x0a, keep=true)::Vector{UInt8}
    i = length(line)
    if keep || i == 0 || line[i] != 0x0a
        return String(line)
    elseif i < 2 || line[i-1] != 0x0d
        return String(resize!(line,i-1))
    else
        return String(resize!(line,i-2))
    end
end