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

        r *= "$(RedisType.bulk_string)$(length(cmd))$(CRLF)$(cmd)$(CRLF)"
        n += 1
    end
    
    if isempty(r)
        throw(RedisError("ERR", "Non-compliant command $command"))
    end

    return "$(RedisType.array)$(n)$(CRLF)" * r
end

function handle_simple_string(_, x)
    return x
end

function handle_integer(_, x)
    return parse(Int64, x)
end

function handle_error(_, x)
    err_type, err_msg = split(x, ' '; limit=2)
    return RedisError(err_type, err_msg)
end

function handle_bulk_string(io, x)
    if x == "-1"
        return nothing
    end
    return readline(io)
end

function handle_array(io, x)
    if x == "0"
        return []
    end
    return [recv(io) for _ in 1:parse(Int64, x)]
end

const RESPHandler = Dict{Char,Function}(
    '+' => handle_simple_string,
    '-' => handle_error,
    ':' => handle_integer,
    '$' => handle_bulk_string,
    '*' => handle_array
)

"""
    recv(io::Union{TCPSocket,Base.GenericIOBuffer})

Reads any bytes before next CRLF (\r\n) in a TCPScoket or IOBuffer, blocks if no bytes available.
"""
function recv(io::Union{TCPSocket,Base.GenericIOBuffer})
    line = readline(io)

    if isempty(line)
        return nothing
    end

    handler = RESPHandler[line[1]]
    return handler(io, line[2:end])
end

"""
    recv(io::MbedTLS.SSLContext)

Copies all available decrypted bytes from an MbedTLS.SSLContext into an IOBuffer, then reads line by line.
"""
function recv(io::MbedTLS.SSLContext)
    MbedTLS.wait_for_decrypted_data(io)
    return recv(IOBuffer(readavailable(io)))
end
