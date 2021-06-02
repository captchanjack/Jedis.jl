set_global_client()

@testset "SUBSCRIBE" begin
    channels = ["first", "second", "third"]
    publisher = Client()
    subscriber = Client()
    messages = []
    @test subscriber.is_subscribed == false
    
    @async subscribe(channels...; client=subscriber) do msg
        push!(messages, msg)
    end
    
    wait_until_subscribed(subscriber)
    @test subscriber.is_subscribed == true
    @test subscriber.subscriptions == Set{String}(channels)
    
    @test publish("first", "hello"; client=publisher) == 1
    @test publish("second", "world"; client=publisher) == 1
    @test publish("something", "else"; client=publisher) == 0
    
    @test length(messages) == 2
    @test messages[1] == ["message", "first", "hello"]
    @test messages[2] == ["message", "second", "world"]
    
    @test_throws RedisError set("already", "subscribed"; client=subscriber)
    @test_throws RedisError subscribe("alreadsubscribed"; client=subscriber) do msg end
    
    unsubscribe("first"; client=subscriber)
    
    wait_until_channel_unsubscribed(subscriber, "first")
    @test subscriber.is_subscribed == true
    @test subscriber.subscriptions == Set{String}(["second", "third"])
    
    @test publish("first", "not subscribed anymore"; client=publisher) == 0
    
    @test length(messages) == 2
    
    unsubscribe(; client=subscriber) # unsubscribe from everything
    
    wait_until_unsubscribed(subscriber)
    @test subscriber.is_subscribed == false
    @test isempty(subscriber.subscriptions)
    
    stop_fn(msg) = msg[end] == "close subscription"
    
    @async subscribe(channels...; stop_fn=stop_fn, client=subscriber) do msg end
    
    wait_until_subscribed(subscriber)
    @test subscriber.is_subscribed == true
    @test subscriber.subscriptions == Set{String}(channels)
    
    @test publish("first", "close subscription"; client=publisher) == 1
    
    wait_until_unsubscribed(subscriber)
    @test subscriber.is_subscribed == false
    @test isempty(subscriber.subscriptions)
end

@testset "PSUBSCRIBE" begin
    patterns = ["first*", "second*", "third*"]
    publisher = Client()
    subscriber = Client()
    messages = []
    @test subscriber.is_subscribed == false
    
    @async psubscribe(patterns...; client=subscriber) do msg
        push!(messages, msg)
    end
    
    wait_until_subscribed(subscriber)
    @test subscriber.is_subscribed == true
    @test subscriber.psubscriptions == Set{String}(patterns)
    
    @test publish("first_pattern", "hello"; client=publisher) == 1
    @test publish("second_pattern", "world"; client=publisher) == 1
    @test publish("something", "else"; client=publisher) == 0
    
    @test length(messages) == 2
    @test messages[1] == ["pmessage", "first*", "first_pattern", "hello"]
    @test messages[2] == ["pmessage", "second*", "second_pattern", "world"]
    
    @test_throws RedisError set("already", "subscribed"; client=subscriber)
    @test_throws RedisError psubscribe("alreadsubscribed"; client=subscriber) do msg end
    
    punsubscribe("first*"; client=subscriber)
    
    wait_until_pattern_unsubscribed(subscriber, "first*")
    @test subscriber.is_subscribed == true
    @test subscriber.psubscriptions == Set{String}(["second*", "third*"])
    
    @test publish("first_pattern", "not subscribed anymore"; client=publisher) == 0
    
    @test length(messages) == 2
    
    punsubscribe(; client=subscriber) # unsubscribe from everything
    
    wait_until_unsubscribed(subscriber)
    @test subscriber.is_subscribed == false
    @test isempty(subscriber.psubscriptions)
    
    stop_fn(msg) = msg[end] == "close subscription"
    
    @async psubscribe(patterns...; stop_fn=stop_fn, client=subscriber) do msg end
    
    wait_until_subscribed(subscriber)
    @test subscriber.is_subscribed == true
    @test subscriber.psubscriptions == Set{String}(patterns)
    
    @test publish("first_pattern", "close subscription"; client=publisher) == 1
    
    wait_until_unsubscribed(subscriber)
    @test subscriber.is_subscribed == false
    @test isempty(subscriber.subscriptions)
end

flushall()