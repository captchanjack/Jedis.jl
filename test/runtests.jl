using Jedis
using Test
using Dates

@testset "Commands" begin include("test_commands.jl") end
@testset "Pub/Sub" begin include("test_pubsub.jl") end
@testset "Pipeline" begin include("test_pipeline.jl") end
# @testset "SSL/TLS" begin include("test_ssl.jl") end
@testset "Redis Locks" begin include("test_lock.jl") end