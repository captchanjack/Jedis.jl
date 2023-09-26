# Jedis.jl
A lightweight Redis client, implemented in Julia.

## Key Features
Links to detailed interfaces and documentation:
- Basic **[command execution](https://captchanjack.github.io/Jedis.jl/commands/)**
- Executing commands with a **[global client](https://captchanjack.github.io/Jedis.jl/client/)** instance
- **[Pipelining](https://captchanjack.github.io/Jedis.jl/pipeline/)**
- **[Transactions](https://captchanjack.github.io/Jedis.jl/commands/#Jedis.multi)**
- **[Pub/Sub](https://captchanjack.github.io/Jedis.jl/pubsub/)**
- **[Redis locks](https://captchanjack.github.io/Jedis.jl/lock/)**
- Support for secured Redis connection (**[SSL/TLS](https://captchanjack.github.io/Jedis.jl/client/#Jedis.get_ssl_config/)**)

## Usage
Establishing a basic **[client](https://captchanjack.github.io/Jedis.jl/client/)** connection:
```jl
client = Client(host="localhost", port=6379)
```

Establishing a **[secured client](https://captchanjack.github.io/Jedis.jl/client/#Jedis.get_ssl_config/)** (SSL/TLS) connection:
```jl
ssl_config = get_ssl_config(ssl_certfile="redis.crt", ssl_keyfile="redis.key", ssl_ca_certs="ca.crt")
client = Client(ssl_config=ssl_config)
```

Setting and getting the global client:
```jl
set_global_client(client)
get_global_client()
```

Executing **[commands](https://captchanjack.github.io/Jedis.jl/commands/)**:
```jl
set("key", "value"; client=client)
get("key")  # uses global client by default
execute(["DEL", "key"], client)  # custom commands
```

Using **[pipelining](https://captchanjack.github.io/Jedis.jl/pipeline/)** to speed up queries:
```jl
# Normal
pipe = Pipeline()
set("key", "value"; client=pipe)
get("key"; client=pipe)
results = execute(pipe)

# Do-block
results = pipeline() do pipe
    lpush("example", 1, 2, 3, 4; client=pipe)
    lpop("example"; client=pipe)
    rpop("example"; client=pipe)
    lpop("example"; client=pipe)
end
```

Executing a group of commands atomically with **[MULTI/EXEC transactions](https://captchanjack.github.io/Jedis.jl/commands/#Jedis.multi)**:
```jl
# Normal
multi()
set("key", "value")
get("key")
results = exec()

# Do-block
results = multi_exec() do 
    set("key", "value")
    get("key")
    get("key")
end
```

Executing a MULTI/EXEC transaction within a pipeline:
```jl
results = pipeline() do pipe
    lpush("example", 1, 2, 3, 4; client=pipe)
    lpop("example"; client=pipe)
    rpop("example"; client=pipe)

    multi_exec(; client=pipe) do
        lpop("example"; client=pipe)
        rpop("example"; client=pipe)
    end

    lpop("example"; client=pipe)
end
```

Using Redis **[Pub/Sub](https://captchanjack.github.io/Jedis.jl/pubsub/)** (interfaces for `subscribe` and `psubscribe` are the same):
```jl
# Set up channels, publisher and subscriber clients
channels = ["first", "second"]
publisher = Client()
subscriber = Client()

# Begin the subscription
stop_fn(msg) = msg[end] == "close subscription";  # stop the subscription loop if the message matches
messages = []

@async subscribe(channels...; stop_fn=stop_fn, client=subscriber) do msg
    push!(messages, msg)
end  # Without @async this function will block, alternatively use Thread.@spawn

wait_until_subscribed(subscriber)
subscriber.is_subscribed  # outputs true
subscriber.subscriptions  # set of actively subscribed channels

# Publish to channels
publish("first", "hello"; client=publisher)
publish("second", "world"; client=publisher)

# Unsubscribing
unsubscribe("first"; client=subscriber)
wait_until_channel_unsubscribed(subscriber, "first")
subscriber.subscriptions
unsubscribe(; client=subscriber)  # unsubscribe from all channels
wait_until_unsubscribed(subscriber)
subscriber.is_subscribed  # outputs false
subscriber.subscriptions  # set of actively subscribed channels should be empty
```

Using **[redis locks](https://captchanjack.github.io/Jedis.jl/lock/)** for performing atomic operations:
```jl
@async redis_lock("example_lock") do
    sleep(3)  # Lock will exist for 3 seconds
end

while !isredislocked("example_lock")
    sleep(0.1)  # Ensure async lock is active before proceeding
end

redis_lock("example_lock") do
    println("This message will be delayed by 3 seconds!")  # Blocked by first lock
end
```
