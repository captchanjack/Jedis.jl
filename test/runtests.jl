using Jedis
using Test

@testset "Commands" begin include("test_commands.jl") end
@testset "Pub/Sub" begin include("test_pubsub.jl") end
@testset "Pipeline" begin include("test_pipeline.jl") end