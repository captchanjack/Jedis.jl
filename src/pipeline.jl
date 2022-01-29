"""
    Pipeline([client::Client=get_global_client(); filter_multi_exec::Bool=false]) -> Pipeline

Creates a Pipeline client instance for executing commands in batch.

# Fields
- `client::Client`: Reference to the underlying Client connection.
- `resp::Vector{String}`: Batched commands converted to RESP compliant string.
- `filter_multi_exec::Bool`: Set `true` to filter out QUEUED responses in a MULTI/EXEC transaction.
- `multi_exec::Bool`: Used to track and filter MULTI/EXEC transactions.
- `multi_exec_bitmask::Vector{Bool}`: Used to track and filter MULTI/EXEC transactions.

# Examples
```julia-repl
julia> pipe = Pipeline();

julia> set("key", "value"; client=pipe);

julia> get("key"; client=pipe);

julia> execute(pipe)
2-element Array{String,1}:
 "OK"
 "value"
```
"""
mutable struct Pipeline
    client::Client
    resp::Vector{String}
    filter_multi_exec::Bool
    multi_exec::Bool
    multi_exec_bitmask::Vector{Bool}
end
Pipeline(client::Client=get_global_client(); filter_multi_exec::Bool=false) = Pipeline(client, [], filter_multi_exec, true, [])

"""
    add!(pipe::Pipeline, command)

Add a RESP compliant command to a pipeline client.
"""
function add!(pipe::Pipeline, command::AbstractArray)
    push!(pipe.resp, resp(command))

    if pipe.filter_multi_exec
        first = uppercase(command[1])

        if first == "MULTI"
            pipe.multi_exec = false
        elseif first == "EXEC"
            pipe.multi_exec = true
        end

        push!(pipe.multi_exec_bitmask, pipe.multi_exec)
    end
end
function add!(pipe::Pipeline, command::AbstractString)
    add!(pipe, split_on_whitespace(command))
end

"""
    add!(pipe::Pipeline, command)

Flushes the underlying client socket and resets the pipeline in to a clean slate.
"""
function flush!(pipe::Pipeline)
    flush!(pipe.client)
    pipe.resp = []
    pipe.multi_exec = false
    pipe.multi_exec_bitmask = []
end

"""
    pipeline(fn::Function[; clientt=get_global_client(), filter_multi_exec=false])

Execute commands batched in a pipeline client in a do block, optionally filter out MULTI transaction 
responses before the EXEC call, e.g. "QUEUED".

# Examples
```julia-repl
julia> pipeline() do pipe
           lpush("example", 1, 2, 3, 4; client=pipe)
           lpop("example"; client=pipe)
           rpop("example"; client=pipe)
           multi_exec(; client=pipe) do
               lpop("example"; client=pipe)
               rpop("example"; client=pipe)
           end
           lpop("example"; client=pipe)
       end
5-element Array{Any,1}:
 4  # Integer response from lpush
 "4"  # String response from lpop
 "1"  # String response from rpop
 ["3", "2"]  # Array of String response from multi_exec do block, with responeses before the exec call filtered out
 nothing  # Nil response from final lpop
```
"""
function Base.pipeline(fn::Function; client::Client=get_global_client(), filter_multi_exec=false)
    pipe = Pipeline(client; filter_multi_exec=filter_multi_exec)
    fn(pipe)
    return execute(pipe)
end