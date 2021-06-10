# Redis Commands

Jedis commands all share a common interface, if the `client` kwarg is not provided then the [`Jedis.GLOBAL_CLIENT`](@ref) instance will be used:

```@example
command(args...; kwargs..., client=get_global_client())
```

### Full list of Jedis commands:

```@docs
auth
select
ping
flushdb
flushall
quit
set
Jedis.get
del
exists
hexists
keys
hkeys
setex
expire
ttl
multi
exec
multi_exec
hset
hget
hgetall
hmget
hdel
lpush
rpush
lpos
lrem
lpop
rpop
blpop
brpop
llen
lrange
incr
incrby
incrbyfloat
hincrby
hincrbyfloat
zincrby
```