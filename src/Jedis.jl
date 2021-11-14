module Jedis

export Client, Pipeline, RedisError, get_global_client, set_global_client, get_ssl_config, 
       disconnect!, reconnect!, add!, copy, wait_until_subscribed, wait_until_unsubscribed, 
       wait_until_channel_unsubscribed, wait_until_pattern_unsubscribed, execute, auth, select, 
       ping, flushdb, flushall, quit, set, setnx, get, del, exists, hexists, hkeys, setex, 
       expire, ttl, multi, exec, multi_exec, pipeline, hset, hget, hgetall, hmget, hdel, rpush, 
       lpush, lpos, lrem, lpop, rpop, blpop, brpop, llen, lrange, publish, subscribe, unsubscribe, 
       psubscribe, punsubscribe, incr, incrby, incrbyfloat, hincrby, hincrbyfloat, zincrby, zadd, 
       zrange, zrangebyscore, zrem, acquire_lock, release_lock, redis_lock, isredislocked

using Sockets
using MbedTLS
using UUIDs: uuid4
import Base: copy, showerror, get, pipeline

include("exceptions.jl")
include("utilities.jl")
include("client.jl")
include("pipeline.jl")
include("protocol.jl")
include("execute.jl")
include("commands.jl")
include("pubsub.jl")
include("lock.jl")

end # module