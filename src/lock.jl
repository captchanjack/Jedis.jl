"""
    acquire_lock(lock_key[, lock_value=string(uuid4()); client::Client=get_global_client(), timeout=nothing, seconds_between_checks=0.1])

Creates a redis lock key, blocks if the lock already exists, returns the `lock_value`.

It is preferred that `redis_lock` is used instead as it will handle the acquiring and releasing of 
locks within a do-block context.

# Arguments
- `lock_key`: Name of the redis lock key.
- `lock_value=string(uuid4())`: Token value of the redis lock, ensures that only owners of a lock can release it, defaults to UUID.
- `client::Client=get_global_client()`: Redis client instance, defualts to global instance.
- `timeout=nothing`: Timeout of the lock in seconds, if `nothing` then lock will not timeout.
- `seconds_between_checks=0.1`: Sleep time (seconds) between each lock exists check.

# Examples
```julia-repl
julia> acquire_lock("example_lock", "lock_token")
"lock_token"

julia> release_lock("example_lock", "wrong_token")
false  # Returns false if the lock value does not match

julia> release_lock("example_lock", "lock_token")
true  # Returns true if the lock value matches and lock was successfully released
```
"""
function acquire_lock(lock_key, lock_value=string(uuid4()); client::Client=get_global_client(), timeout=nothing, seconds_between_checks=0.1)
    while true
        px = isnothing(timeout) ? [] : ["PX", timeout * 1000]
        was_set = !isnothing(execute(["SET", lock_key, lock_value, "NX", px...], client))
        
        if was_set
            return lock_value
        end

        sleep(seconds_between_checks)
    end
end

"""
    release_lock(lock_key, lock_value[; client::Client=get_global_client()])::Bool

Returns `true` if the lock value matches and lock was successfully released, `false` otherwise.

It is preferred that `redis_lock` is used instead as it will handle the acquiring and releasing of 
locks within a do-block context.

# Examples
```julia-repl
julia> acquire_lock("example_lock", "lock_token")
"lock_token"

julia> release_lock("example_lock", "wrong_token")
false  # Returns false if the lock value does not match

julia> release_lock("example_lock", "lock_token")
true  # Returns true if the lock value matches and lock was successfully released
```
"""
function release_lock(lock_key, lock_value; client::Client=get_global_client())::Bool
    if get(lock_key; client=client) == lock_value
        del(lock_key; client=client)
        return true
    else
        return false
    end
end

"""
    redis_lock(fn::Function, lock_key[, lock_value=string(uuid4()); client::Client=get_global_client(), timeout=nothing, seconds_between_checks=0.1])

Enters a redis lock context, blocks if the lock already exists.

# Arguments
- `lock_key`: Name of the redis lock key.
- `lock_value=string(uuid4())`: Token value of the redis lock, ensures that only owners of a lock can release it, defaults to UUID.
- `client::Client=get_global_client()`: Redis client instance, defualts to global instance.
- `timeout=nothing`: Timeout of the lock in seconds, if `nothing` then lock will not timeout.
- `seconds_between_checks=0.1`: Sleep time (seconds) between each lock exists check.

# Examples
```julia-repl
julia> @async redis_lock("example_lock") do
           sleep(3)  # Lock will exist for 3 seconds
       end

julia> redis_lock("example_lock") do
           println("This message will be delayed by 3 seconds!")  # Blocked by first lock
       end
```
"""
function redis_lock(fn::Function, lock_key, lock_value=string(uuid4()); client::Client=get_global_client(), timeout=nothing, seconds_between_checks=0.1)
    acquire_lock(lock_key, lock_value; client=client, timeout=timeout, seconds_between_checks=seconds_between_checks)
    
    try
        fn()
    finally
        release_lock(lock_key, lock_value; client=client)
    end
end

"""
    isredislocked(lock_key[; client::Client=get_global_client()])

Returns `true` if `lock_key` exists, otherwise `false`.
"""
isredislocked(lock_key; client::Client=get_global_client()) = exists(lock_key; client=client) == 1