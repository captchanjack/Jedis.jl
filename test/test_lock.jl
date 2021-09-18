set_global_client()

@testset "Redis Locks" begin
    start = datetime2unix(now())
    lock_time = 3  # Seconds
    lock_name = "example_lock"

    @async redis_lock(lock_name) do
        sleep(lock_time)  # Lock will exist for 3 seconds
    end

    while !isredislocked(lock_name)
        sleep(0.1)  # Ensure async lock is active before proceeding
    end

    redis_lock(lock_name) do
        println("This message will be delayed by $lock_time seconds!")  # Blocked by first lock
    end

    total_time = datetime2unix(now()) - start
    @test total_time >= lock_time
end

flushall()