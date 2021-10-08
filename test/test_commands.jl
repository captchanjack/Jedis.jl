set_global_client()

@testset "AUTH SELECT PING" begin
    @test_throws RedisError auth("")
    @test select(0) == "OK"
    @test ping() == "PONG"
end

@testset "GET SET" begin
    @test set("key", "value") == "OK"
    @test setnx("key", "value") == 0
    @test get("key") == "value"
    @test Jedis.keys("k*") == ["key"]
    @test del("key") == 1
    @test setnx("key", "value") == 1
    @test flushdb() == "OK" && isnothing(get("key"))
end

@testset "EXPIRE" begin
    @test setex("key", 10, "value") == "OK"
    @test ttl("key") > 0
    @test del("key") == 1 && isnothing(get("key"))
    @test set("key", "value") == "OK"
    @test ttl("key") == -1
    @test expire("key", 10) == 1
    @test ttl("key") > 0
    @test flushdb() == "OK" && isnothing(get("key"))
end

@testset "MULTI EXEC" begin
    @test multi() == "OK"
    @test set("key", "value") == "QUEUED"
    @test get("key") == "QUEUED"
    @test get("key") == "QUEUED"
    @test exec() == ["OK", "value", "value"]
    @test ["OK", "value", "value"] == multi_exec() do 
        set("key", "value")
        get("key")
        get("key")
    end
    @test flushall() == "OK" && isnothing(get("key"))
end

@testset "HASH" begin
    @test hset("key", "f1", 1, "f2", 2, "f3", 3) == 3
    @test hget("key", "f2") == "2"
    @test hgetall("key") == ["f1", "1", "f2", "2", "f3", "3"]
    @test hmget("key", "f1", "f2", "doesnotexist") == ["1", "2", nothing]
    @test hdel("key", "f1") == 1
    @test isnothing(hget("key", "f1"))
    @test flushall() == "OK" && isnothing(get("key"))
end

@testset "LIST" begin
    @test lpush("mylist", 3, 2, 1) == 3
    @test rpush("mylist", 4, 5, 6) == 6
    @test llen("mylist") == 6
    @test lrange("mylist", 0, -1) == ["1", "2", "3", "4", "5", "6"]
    @test lpop("mylist") == "1"
    @test rpop("mylist") == "6"
    @test lrange("mylist", 0, -1) == ["2", "3", "4", "5"]
    flushall()
    @test begin
        task = @async blpop("mylist", "otherlist") == ["otherlist", "1"]
        other = Client()
        lpush("otherlist", 1; client=other)
        disconnect!(other)
        fetch(task)
    end
    @test begin
        task = @async brpop("mylist", "otherlist") == ["mylist", "6"]
        other = Client()
        lpush("mylist", 6; client=other)
        disconnect!(other)
        fetch(task)
    end
    flushall()
end

# @testset "QUIT" begin
#     @test quit() == "OK"
#     @test_throws Base.IOError ping()
# end