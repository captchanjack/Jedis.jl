"""
    publish(channel, message)

Post a message to a channel.
"""
publish(channel, message; client=get_global_client()) = execute(["PUBLISH", channel, message], client)

"""
    subscribe(fn::Function,
              channel,
              channels...;
              stop_fn::Function=(msg) -> false,
              err_cb::Function=(err) -> log_error(err))

Listen for messages published to the given channels in a do block. Optionally provide a stop 
function `stop_fn(msg)` which gets run as a callback everytime a subscription message is received, 
the subscription loop breaks if the `stop_fn` returns `true`. Optionally provide `err_cb(err)` 
function which gets run on encountering an exception in the main subscription loop.

# Examples
```julia-repl
julia> channels = ["first", "second"];

julia> publisher = Client();

julia> subscriber = Client();

julia> stop_fn(msg) = msg[end] == "close subscription";  # stop the subscription loop if the message matches

julia> messages = [];

julia> @async subscribe(channels...; stop_fn=stop_fn, client=subscriber) do msg
           push!(messages, msg)
       end;  # Without @async this function will block, alternatively use Thread.@spawn

julia> wait_until_subscribed(subscriber);

julia> subscriber.is_subscribed
true

julia> subscriber.subscriptions
Set{String} with 2 elements:
  "second"
  "first"

julia> publish("first", "hello"; client=publisher);

julia> publish("second", "world"; client=publisher);

julia> println(messages)
Any[["message", "first", "hello"], ["message", "second", "world"]]  # message has the format [<message type>, <channel>, <actual message>]

julia> unsubscribe("first"; client=subscriber);

julia> wait_until_channel_unsubscribed(subscriber, "first");

julia> subscriber.subscriptions
Set{String} with 1 element:
  "second"

julia> unsubscribe(; client=subscriber);  # unsubscribe from all channels

julia> wait_until_unsubscribed(subscriber);

julia> subscriber.is_subscribed
false

julia> subscriber.subscriptions
Set{String}()
```
"""
function subscribe(fn::Function, channel, channels...; stop_fn::Function=(msg) -> false, err_cb::Function=(err) -> log_error(err), client::Client=get_global_client())
    if client.is_subscribed
        throw(RedisError("SUBERROR", "Cannot open multiple subscriptions in the same Client instance"))
    end
    
    @lock client.lock client.subscriptions = Set([channel, channels...])
    execute(["SUBSCRIBE", client.subscriptions...], client)
    @lock client.lock set_subscribed!(client)
    yield()
    try
        while true
            type, chnl = msg = recv(client.socket)
            
            if type == "message" && chnl in client.subscriptions
                fn(msg)
                stop_fn(msg) && break
                
            elseif type == "unsubscribe"
                if isnothing(chnl)
                    @lock client.lock client.subscriptions = Set{String}()
                elseif chnl in client.subscriptions
                    @lock client.lock delete!(client.subscriptions, chnl)
                end
                
                isempty(client.subscriptions) && break
            end
        end
    catch err
        err_cb(err)
    finally
        if !isempty(client.subscriptions)
            unsubscribe(client.subscriptions...; client=client)
            @lock client.lock client.subscriptions = Set{String}()
            @lock client.lock flush!(client)
        end
        @lock client.lock set_unsubscribed!(client)
    end
end

"""
    unsubscribe([channels...]) -> nothing

Unsubscribes the client from the given channels, or from all of them if none is given.
"""
unsubscribe(channels...; client=get_global_client()) = execute_without_recv(["UNSUBSCRIBE", channels...], client)

"""
    psubscribe(fn::Function,
               pattern,
               patterns...;
               stop_fn::Function=(msg) -> false,
               err_cb::Function=(err) -> log_error(err))

Listen for messages published to the given channels matching ghe given patterns in a do block.
Optionally provide a stop function `stop_fn(msg)` which gets run as a callback everytime a 
subscription message is received, the subscription loop breaks if the `stop_fn` returns `true`. 
Optionally provide `err_cb(err)` function which gets run on encountering an exception in the main 
subscription loop.

# Examples
```julia-repl
julia> patterns = ["first*", "second*"];

julia> publisher = Client();

julia> subscriber = Client();

julia> stop_fn(msg) = msg[end] == "close subscription";  # stop the subscription loop if the message matches

julia> messages = [];

julia> @async psubscribe(patterns...; stop_fn=stop_fn, client=subscriber) do msg
           push!(messages, msg)
       end;  # Without @async this function will block, alternatively use Thread.@spawn

julia> wait_until_subscribed(subscriber);

julia> subscriber.is_subscribed
true

julia> subscriber.psubscriptions
Set{String} with 2 elements:
  "first*"
  "second*"

julia> publish("first_pattern", "hello"; client=publisher);

julia> publish("second_pattern", "world"; client=publisher);

julia> println(messages)
Any[["pmessage", "first*", "first_pattern", "hello"], ["pmessage", "second*", "second_pattern", "world"]]  # message has the format [<message type>, <pattern>, <channel>, <actual message>]

julia> punsubscribe("first*"; client=subscriber);

julia> wait_until_pattern_unsubscribed(subscriber, "first*");

julia> subscriber.psubscriptions
Set{String} with 1 element:
  "second*"

julia> punsubscribe(; client=subscriber);  # unsubscribe from all patterns

julia> wait_until_unsubscribed(subscriber);

julia> subscriber.is_subscribed
false

julia> subscriber.psubscriptions
Set{String}()
```
"""
function psubscribe(fn::Function, pattern, patterns...; stop_fn::Function=(msg) -> false, err_cb::Function=(err) -> log_error(err), client::Client=get_global_client())
    if client.is_subscribed
        throw(RedisError("SUBERROR", "Cannot open multiple subscriptions in the same Client instance"))
    end

    @lock client.lock client.psubscriptions = Set([pattern, patterns...])
    execute(["PSUBSCRIBE", client.psubscriptions...], client)
    @lock client.lock set_subscribed!(client)

    try
        while true
            type, pttrn = msg = recv(client.socket)

            if type == "pmessage" && pttrn in client.psubscriptions
                fn(msg)
                stop_fn(msg) && break

            elseif type == "punsubscribe"
                if isnothing(pttrn)
                    @lock client.lock client.psubscriptions = Set{String}()
                elseif pttrn in client.psubscriptions
                    @lock client.lock delete!(client.psubscriptions, pttrn)
                end

                isempty(client.psubscriptions) && break
            end
        end
    catch err
        err_cb(err)
    finally
        if !isempty(client.psubscriptions)
            punsubscribe(client.psubscriptions...; client=client)
            @lock client.lock client.psubscriptions = Set{String}()
            @lock client.lock flush!(client)
        end
        @lock client.lock set_unsubscribed!(client)
    end
end

"""
    unsubscribe([channels...]) -> nothing

Unsubscribes the client from the given patterns, or from all of them if none is given.
"""
punsubscribe(patterns...; client=get_global_client()) = execute_without_recv(["PUNSUBSCRIBE", patterns...], client)