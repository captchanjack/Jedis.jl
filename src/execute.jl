"""
    execute(command[; client::Client=get_global_client()])

Sends a RESP compliant command to the Redis host and returns the result. The command is either an 
array of command keywords, or a single command string. Defaults to using the globally set Client.

# Examples
```julia-repl
julia> execute(["SET", "key", "value"])
"OK"
julia> execute("GET key")
"value"
```
"""
function execute(command::AbstractArray, client::Client=get_global_client())
    if client.is_subscribed
        throw(RedisError("SUBERROR", "Cannot execute commands while a subscription is open in the same Client instance"))
    end

    @lock client.lock begin
        flush!(client)
        retry!(client)
        write(client.socket, resp(command))
        msg = recv(client.socket)
        
        if msg isa Exception
            throw(msg)
        end
    
        return msg
    end
end
function execute(command::AbstractString, client::Client=get_global_client())
    execute(split_on_whitespace(command), client)
end

"""
    execute_without_recv(command[; client::Client=get_global_client()])

Sends a RESP compliant command to the Redis host without reading the returned result.
"""
function execute_without_recv(command::AbstractArray, client::Client=get_global_client())
    @lock client.lock begin
        flush!(client)
        retry!(client)
        write(client.socket, resp(command))
        return
    end
end
function execute_without_recv(command::AbstractString, client::Client=get_global_client())
    execute_without_recv(split_on_whitespace(command), client)
end

"""
    execute(command, pipe::Pipeline)

Add a RESP compliant command to a pipeline client, optionally filter out MULTI transaction responses
before the EXEC call, e.g. "QUEUED".

# Examples
```julia-repl
julia> pipe = Pipeline();

julia> execute(["SET", "key", "value"]; client=pipe);

julia> execute(["GET", "key"]; client=pipe);

julia> execute(pipe)
2-element Array{String,1}:
 "OK"
 "value"
```
"""
function execute(command::AbstractArray, pipe::Pipeline)
    add!(pipe, command)
    return
end
function execute(command::AbstractString, pipe::Pipeline)
    execute(split_on_whitespace(command), pipe)
end

"""
    execute(pipe::Pipeline[; filter_multi_exec=true])

Execute commands batched in a pipeline client, optionally filter out MULTI transaction responses
before the EXEC call, e.g. "QUEUED".

# Examples
```julia-repl
julia> pipe = Pipeline();

julia> set("key", "value"; client=pipe);

julia> get("key"; client=pipe);

julia> multi(; client=pipe);

julia> get("key"; client=pipe);

julia> get("key"; client=pipe);

julia> exec(; client=pipe);

julia> execute(pipe)
2-element Array{String,1}:
 "OK"
 "value"
 ["value", "value"]  # Only the response from final exec() call is returned
```
"""
function execute(pipe::Pipeline)
    if pipe.client.is_subscribed
        throw(RedisError("SUBERROR", "Cannot execute Pipeline while a subscription is open in the same Client instance"))
    end

    @lock pipe.client.lock begin
        try
            flush!(pipe.client)
            write(pipe.client.socket, join(pipe.resp))
            messages = [recv(pipe.client.socket) for _ in 1:length(pipe.resp)]
            
            if pipe.filter_multi_exec
                return messages[pipe.multi_exec_bitmask]
            end
            
            return messages
        finally
            flush!(pipe)
        end
    end
end            