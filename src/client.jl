"""
    Client([; host="127.0.0.1", port=6379, database=0, password="", username="", ssl_config=nothing]) -> Client

Creates a Client instance connecting and authenticating to a Redis host, provide an `MbedTLS.SSLConfig` 
(see `get_ssl_config`) for a secured Redis connection (SSL/TLS).

# Attributes
- `host::AbstractString`: Redis host.
- `port::Integer`: Redis port.
- `database::Integer`: Redis database index.
- `password::AbstractString`: Redis password if any.
- `username::AbstractString`: Redis username if any.
- `socket::Union{TCPSocket,MbedTLS.SSLContext}`: Socket used for sending and reveiving from Redis host.
- `lock::Base.AbstractLock`: Lock for atomic reads and writes from client socket.
- `ssl_config::Union{MbedTLS.SSLConfig,Nothing}`: Optional ssl config for secured redis connection.
- `is_subscribed::Bool`: Whether this Client is actively subscribed to any channels or patterns.
- `subscriptions::AbstractSet{<:AbstractString}`: Set of channels currently subscribed on.
- `psubscriptions::AbstractSet{<:AbstractString}`: Set of patterns currently psubscribed on.

# Note
- Connection parameters `host`, `port`, `database`, `password`, `username` will not change after 
client istance is constructed, even with `SELECT` or `CONFIG SET` commands.

# Examples
Basic connection:
```julia-repl
julia> client = Client();

julia> set("key", "value"; client=client)
"OK"

julia> get("key"; client=client)
"value"

julia> execute(["DEL", "key"], client)
1
```

SSL/TLS connection:
```julia-repl
julia> ssl_config = get_ssl_config(ssl_certfile="redis.crt", ssl_keyfile="redis.key", ssl_ca_certs="ca.crt");

julia> client = Client(ssl_config=ssl_config);
```
"""
mutable struct Client
    host::AbstractString
    port::Integer
    database::Integer
    password::AbstractString
    username::AbstractString
    socket::Union{TCPSocket,MbedTLS.SSLContext}
    lock::Base.AbstractLock
    ssl_config::Union{MbedTLS.SSLConfig,Nothing}
    is_subscribed::Bool
    subscriptions::AbstractSet{<:AbstractString}
    psubscriptions::AbstractSet{<:AbstractString}
end

function Client(; host="127.0.0.1", port=6379, database=0, password="", username="", ssl_config=nothing)
    if isnothing(ssl_config)
        socket = connect(host, port)
    else
        socket = ssl_connect(host, port, ssl_config)
    end
    
    client = Client(
        host,
        port,
        database,
        password,
        username,
        socket,
        ReentrantLock(),
        ssl_config,
        false,
        Set{String}(),
        Set{String}()
    )

    !isempty(password * username) && auth(password, username; client=client)
    database != 0 && select(database; client=client)

    return client
end

"""
    get_ssl_config([; ssl_certfile=nothing, ssl_keyfile=nothing, ssl_ca_certs=nothing]) -> MbedTLS.SSLConfig

Loads ssl cert, key and ca cert files from provided directories into MbedTLS.SSLConfig object.

# Examples
```julia-repl
julia> ssl_config = get_ssl_config(ssl_certfile="redis.crt", ssl_keyfile="redis.key", ssl_ca_certs="ca.crt");
```
"""
function get_ssl_config(; ssl_certfile=nothing, ssl_keyfile=nothing, ssl_ca_certs=nothing)
    ssl_config = MbedTLS.SSLConfig(false)

    if !isnothing(ssl_certfile) && !isnothing(ssl_keyfile)
        cert = MbedTLS.crt_parse_file(ssl_certfile)
        key = MbedTLS.parse_keyfile(ssl_keyfile)
        MbedTLS.own_cert!(ssl_config, cert, key)
    end

    if !isnothing(ssl_ca_certs)
        ca_certs = MbedTLS.crt_parse_file(ssl_ca_certs)
        MbedTLS.ca_chain!(ssl_config, ca_certs)
    end
    
    return ssl_config
end

"""
    ssl_connect(host::AbstractString, port::Integer, ssl_config::MbedTLS.SSLConfig) -> MbedTLS.SSLContext

Connects to the redis host and port, returns a socket connection with ssl context.
"""
function ssl_connect(host::AbstractString, port::Integer, ssl_config::MbedTLS.SSLConfig)
    tcp = connect(host, port)
    io = MbedTLS.SSLContext()
    MbedTLS.setup!(io, ssl_config)
    MbedTLS.associate!(io, tcp)
    MbedTLS.hostname!(io, host)
    MbedTLS.handshake!(io)
    return io
end

"""
    GLOBAL_CLIENT = Ref{Client}()

Reference to a global Client object.
"""
const GLOBAL_CLIENT = Ref{Client}()

"""
    set_global_client(client::Client)
    set_global_client([; host="127.0.0.1", port=6379, database=0, password="", username="", ssl_config=nothing])

Sets a Client object as the `GLOBAL_CLIENT[]` instance.
"""
function set_global_client(client::Client)
    GLOBAL_CLIENT[] = client
end

function set_global_client(; host="127.0.0.1", port=6379, database=0, password="", username="", ssl_config=nothing)
    client = Client(; host=host, port=port, database=database, password=password, username=username,  ssl_config=ssl_config)
    set_global_client(client)
end

"""
    get_global_client() -> Client

Retrieves the `GLOBAL_CLIENT[]` instance, if unassigned then initialises it with default values 
`host="127.0.0.1"`, `port=6379`, `database=0`, `password=""`, `username=""`.
"""
function get_global_client()
    if isassigned(GLOBAL_CLIENT)
        return GLOBAL_CLIENT[]
    else
        return set_global_client()
    end
end

"""
    copy(client::Client) -> Client

Creates a new Client instance, copying the connection parameters of the input.
"""
function Base.copy(client::Client)
    return Client(;
        host=client.host,
        port=client.port,
        database=client.database,
        password=client.password,
        username=client.username,
        ssl_config=client.ssl_config
    )
end

"""
    disconnect!(client::Client)

Closes the client socket connection, it will be rendered unusable.
"""
function disconnect!(client::Client)
    close(client.socket)
end

"""
    reconnect!(client::Client) -> Client

Reconnects the input client socket connection.
"""
function reconnect!(client::Client)
    disconnect!(client)

    if isnothing(client.ssl_config)
        new_socket = connect(client.host, client.port)
    else
        new_socket = ssl_connect(connect(client.host, client.port), client.host, client.ssl_config)
    end

    client.socket = new_socket
    !isempty(client.password * client.username) && auth(client.password, client.username; client=client)
    client.database != 0 && select(client.database; client=client)

    return client
end

"""
    flush!(client::Client)

Reads and discards any bytes that remain unread in the client socket.
"""
function flush!(client::Client)
    while bytesavailable(client.socket) > 0
        recv(client.socket)
    end
end

"""
    set_subscribed!(client::Client)

Marks the Client instance as subscribed, should not be used publicly.
"""
function set_subscribed!(client::Client)
    client.is_subscribed = true
end

"""
    set_unsubscribed!(client::Client)

Marks the Client instance as unsubscribed, should not be used publicly.
"""
function set_unsubscribed!(client::Client)
    client.is_subscribed = false
end

"""
    wait_until_subscribed(client::Client)

Blocks until client changes to a subscribed state.
"""
function wait_until_subscribed(client::Client)
    if !client.is_subscribed
        while !client.is_subscribed
            sleep(0.001)
        end
    end
end

"""
    wait_until_unsubscribed(client::Client)

Blocks until client changes to a unsubscribed state.
"""
function wait_until_unsubscribed(client::Client)
    if client.is_subscribed
        while client.is_subscribed
            sleep(0.001)
        end
    end
end

"""
    wait_until_channel_unsubscribed(client::Client[, channels...])

Blocks until client is unsubscribed from channel(s), leave empty to wait until unsubscribed from all channels.
"""
function wait_until_channel_unsubscribed(client::Client, channels...)
    if isempty(channels)
        while !isempty(client.subscriptions)
            sleep(0.001)
        end
    else
        while !isempty(intersect(client.subscriptions, Set{String}(channels)))
            sleep(0.001)
        end
    end
end

"""
    wait_until_pattern_unsubscribed(client::Client[, patterns...])

Blocks until client is unsubscribed from pattern(s), leave empty to wait until unsubscribed from all patterns.
"""
function wait_until_pattern_unsubscribed(client::Client, patterns...)
    if isempty(patterns)
        while !isempty(client.psubscriptions)
            sleep(0.001)
        end
    else
        while !isempty(intersect(client.psubscriptions, Set{String}(patterns)))
            sleep(0.001)
        end
    end
end