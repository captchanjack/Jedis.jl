"""
    auth(password[, username])

Authenticate to the server.
"""
auth(password, username=""; client=get_global_client()) = execute(["AUTH", username, password], client)

"""
    select(database)

Change the selected database for the current connection.
"""
select(database; client=get_global_client()) = execute(["SELECT", database], client)

"""
    ping()

Ping the server.
"""
ping(; client=get_global_client()) = execute(["PING"], client)

"""
    flushdb([; async=false])

Remove all keys from the current database.
"""
flushdb(; async=false, client=get_global_client()) = execute(["FLUSHDB", async ? "ASYNC" : ""], client)

"""
    flushall([; async=false])

Remove all keys from all databases.
"""
flushall(; async=false, client=get_global_client()) = execute(["FLUSHALL", async ? "ASYNC" : ""], client)

"""
    quit()

Close the connection.
"""
quit(; client=get_global_client()) = execute(["QUIT"], client)

"""
    set(key, value)

Set the string value of a key.
"""
set(key, value; client=get_global_client()) = execute(["SET", key, value], client)

"""
    setnx(key, value)

Set the value of a key, only if the key does not exist.
"""
setnx(key, value; client=get_global_client()) = execute(["SETNX", key, value], client)

"""
    get(key)

Get the value of a key.
"""
Base.get(key; client=get_global_client()) = execute(["GET", key], client)

"""
    del(key[, keys...])

Delete a key.
"""
del(key, keys...; client=get_global_client()) = execute(["DEL", key, keys...], client)

"""
    exists(key[, keys...])

Determine if a key exists.
"""
exists(key, keys...; client=get_global_client()) = execute(["EXISTS", key, keys...], client)

"""
    hexists(key, field)

Determine if a hash field exists.
"""
hexists(key, field; client=get_global_client()) = execute(["HEXISTS", key, field], client)

"""
    keys(pattern)

Find all keys matching the pattern.
"""
Base.keys(pattern; client=get_global_client()) = execute(["KEYS", pattern], client)

"""
    hkeys(key)

Get all fields in a hash.
"""
hkeys(key; client=get_global_client()) = execute(["HKEYS", key], client)

"""
    setex(key, seconds, value)

Set the value and expiration of a key.
"""
setex(key, seconds, value; client=get_global_client()) = execute(["SETEX", key, seconds, value], client)

"""
    expire(key, seconds)

Set a key's tiem to live in seconds.
"""
expire(key, seconds; client=get_global_client()) = execute(["EXPIRE", key, seconds], client)

"""
    ttl(key)

Get the time to live for a key.
"""
ttl(key; client=get_global_client()) = execute(["TTL", key], client)

"""
    multi()

Mark the start of a transaction block.

# Examples
```julia-repl
julia> multi()
"OK"

julia> set("key", "value")
"QUEUED"

julia> get("key")
"QUEUED"

julia> exec()
2-element Array{String,1}:
 "OK"
 "value"
```
"""
multi(; client=get_global_client()) = execute(["MULTI"], client)

"""
    exec()

Execute all commands issued after MULTI.

# Examples
```julia-repl
julia> multi()
"OK"

julia> set("key", "value")
"QUEUED"

julia> get("key")
"QUEUED"

julia> exec()
2-element Array{String,1}:
 "OK"
 "value"
```
"""
exec(; client=get_global_client()) = execute(["EXEC"], client)

"""
    multi_exec(fn::Function)

Execute a MULTI/EXEC transction in a do block.

# Examples
```julia-repl
julia> multi_exec() do 
           set("key", "value")
           get("key")
           get("key")
       end
3-element Array{String,1}:
 "OK"
 "value"
 "value"
```
"""
multi_exec(fn::Function; client=get_global_client()) = (multi(; client=client); fn(); exec(; client=client))

"""
    hset(key, field, value)

Set the string value of a hash field.
"""
hset(key, field, value, fields_and_values...; client=get_global_client()) = execute(["HSET", key, field, value, fields_and_values...], client)

"""
    hget(key, field)

Get the value of a hash field.
"""
hget(key, field; client=get_global_client()) = execute(["HGET", key, field], client)

"""
    hgetall(key)

Get all the fields and values in a hash.
"""
hgetall(key; client=get_global_client()) = execute(["HGETALL", key], client)

"""
    hmget(key, field[, fields...])

Get the values of all the given hash fields.
"""
hmget(key, field, fields...; client=get_global_client()) = execute(["HMGET", key, field, fields...], client)

"""
    hdel(key, field[, fields...])

Delete one or more hash fields.
"""
hdel(key, field, fields...; client=get_global_client()) = execute(["HDEL", key, field, fields...], client)

"""
    lpush(key, element[, elements...])

Prepend one or multiple elements to a list.
"""
lpush(key, element, elements...; client=get_global_client()) = execute(["LPUSH", key, element, elements...], client)

"""
    rpush(key, element[, elements...])

Append one or multiple elements to a list.
"""
rpush(key, element, elements...; client=get_global_client()) = execute(["RPUSH", key, element, elements...], client)

"""
    lpos(key, element[, rank, num_matches, len])

Return the index of matching element on a list.
"""
lpos(key, element, rank="", num_matches="", len=""; client=get_global_client()) = execute(["LPOS", key, element, [isempty(rank) ? "" : "RANK", rank]..., [isempty(num_matches) ? "" : "COUNT", num_matches]..., [isempty(len) ? "" : "MAXLEN", len]...], client)

"""
    lrem(key, count, element)

Remove elements from a list.
"""
lrem(key, count, element; client=get_global_client()) = execute(["LREM", key, count, element], client)

"""
    lpop(key)

Remove and get the first element in a list.
"""
lpop(key; client=get_global_client()) = execute(["LPOP", key], client)

"""
    rpop(key)

Remove and get the last element in a list.
"""
rpop(key; client=get_global_client()) = execute(["RPOP", key], client)

"""
    blpop(key[, key...; timeout=0])

Remove and get the first element in a list, or block until one is available.
"""
blpop(key, keys...; timeout=0, client=get_global_client()) = execute(["BLPOP", key, keys..., timeout], client)

"""
    brpop(key[, key...; timeout=0])

Remove and get the last element in a list, or block until one is available.
"""
brpop(key, keys...; timeout=0, client=get_global_client()) = execute(["BRPOP", key, keys..., timeout], client)

"""
    llen(key)

Get the length of a list.
"""
llen(key; client=get_global_client()) = execute(["LLEN", key], client)

"""
    lrange(key, start, stop)

Get a range of elements from a list.
"""
lrange(key, start, stop; client=get_global_client()) = execute(["LRANGE", key, start, stop], client)

"""
    incr(key)

Increment the integer value of a key by one.
"""
incr(key; client=get_global_client()) = execute(["INCR", key], client)

"""
    incrby(key, increment)

Increment the integer value of a key by the given amount.
"""
incrby(key, increment; client=get_global_client()) = execute(["INCRBY", key, increment], client)

"""
    incrbyfloat(key, increment)

Increment the float value of a key by the given amount.
"""
incrbyfloat(key, increment; client=get_global_client()) = execute(["INCRBYFLOAT", key, increment], client)

"""
    hincrby(key, field, increment)

Increment the integer value of a hash field by the given number.
"""
hincrby(key, increment; client=get_global_client()) = execute(["HINCRBY", key, field, increment], client)

"""
    hincrbyfloat(key, field, increment)

Increment the float value of a hash field by the given number.
"""
hincrbyfloat(key, field, increment; client=get_global_client()) = execute(["HINCRBYFLOAT", key, field, increment], client)

"""
    zincrby(key, field, member)

Increment the score of a member in a sorted set.
"""
zincrby(key, field, increment; client=get_global_client()) = execute(["ZINCRBY", key, field, increment], client)