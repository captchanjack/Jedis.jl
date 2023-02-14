const CRLF = "\r\n"

const RedisType = (
    simple_string = '+',
    error = '-',
    integer = ':',
    bulk_string = '$',
    array = '*'
)

"""
    resp(command::AbstractArray) -> String

Converts an array of redis command keywords to a RESP compliant String.
"""
function resp(command::AbstractArray)
    r = ""
    n = 0

    for cmd in command
        if isempty(cmd)
            continue
        end
        
        if cmd isa AbstractString
            cmd = strip(cmd)
        else
            cmd = string(cmd)
        end

        # Need sizeof for non-ascii byte size, length provides char count only
        r *= "$(RedisType.bulk_string)$(sizeof(cmd))$(CRLF)$(cmd)$(CRLF)"
        n += 1
    end
    
    if isempty(r)
        throw(RedisError("ERR", "Non-compliant command $command"))
    end

    return "$(RedisType.array)$(n)$(CRLF)" * r
end

function parse_simple_string(_, x)
    return x
end

function parse_integer(_, x)
    return parse(Int64, x)
end

function parse_error(_, x)
    err_type, err_msg = split(x, ' '; limit=2)
    return RedisError(err_type, err_msg)
end

function parse_bulk_string(io, x)
    if x == "-1"
        return nothing
    end

    x = parse(Int64, x) + 2
    buffer = Vector{UInt8}(undef, x)
    readbytes!(io, buffer, x)
    return String(buffer[1:end-2])
end

function parse_array(io, x)
    if x == "0"
        return []
    end
    return [recv(io) for _ in 1:parse(Int64, x)]
end

function resp_parser(b::Char)::Function
    if b == '+'
        return parse_simple_string
    elseif b == '-'
        return parse_error
    elseif b == ':'
        return parse_integer
    elseif b == '$'
        return parse_bulk_string
    elseif b == '*'
        return parse_array
    else
        throw(RedisError("INVALIDBYTE", "Parser for byte '$b' does not exist."))
    end
end

"""
    recv(io::Union{TCPSocket,Base.GenericIOBuffer})

Reads any bytes before next CRLF (\r\n) in a TCPScoket or IOBuffer, blocks if no bytes available.
"""
function recv(io::Union{TCPSocket,Base.GenericIOBuffer})
    line = _readline(io)

    if isempty(line)
        return nothing
    end

    parser = resp_parser(line[1])
    return parser(io, line[2:end])
end

"""
    recv(io::MbedTLS.SSLContext)

Copies all available decrypted bytes from an MbedTLS.SSLContext into an IOBuffer, then reads line by line.
"""
function recv(io::MbedTLS.SSLContext)
    MbedTLS.wait_for_decrypted_data(io)
    nb = bytesavailable(io)
    buffer = IOBuffer(Vector{UInt8}(undef, nb))
    readbytes!(io, buffer.data, nb)
    return recv(buffer)
end
