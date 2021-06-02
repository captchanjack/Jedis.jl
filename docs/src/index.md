# Jedis.jl
A lightweight Redis client, implemented in Julia.

## Key Features
This client supports:
- Basic **[command execution](https://captchanjack.github.io/Jedis.jl/commands/)**
- Executing commands with a **[global client](https://captchanjack.github.io/Jedis.jl/client/)** instance
- Executing commands atomically per client instance, with the help of socket locks
- **[Pipelining](https://captchanjack.github.io/Jedis.jl/pipeline/)**
- **[Transactions](https://captchanjack.github.io/Jedis.jl/commands/#Jedis.multi)**
- **[Pub/Sub](https://captchanjack.github.io/Jedis.jl/pubsub/)**