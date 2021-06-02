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

function handle_bulk_string(s, x)
    if x == "-1"
        return nothing
    end
    return readline(s)
end

function handle_array(s, x)
    if x == "0"
        return []
    end
    return [recv(s) for _ in 1:parse(Int64, x)]
end

const RESPHandler = Dict{Char,Function}(
    '+' => handle_simple_string,
    '-' => handle_error,
    ':' => handle_integer,
    '$' => handle_bulk_string,
    '*' => handle_array
)

"""
    recv(s::TCPSocket)

Reads any bytes before the next CRLF (\r\n) in a TCPScoket, blocks if no bytes available.
"""
function recv(s::TCPSocket)
    line = readline(s)
    handler = RESPHandler[line[1]]
    return handler(s, line[2:end])
end