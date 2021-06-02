set_global_client()

@testset "Pipeline - Basic" begin
    pipe = Pipeline()
    @test pipe.n_commands == 0
    for _ in 1:1000
        lrange("nothing", 0, -1; client=pipe)
    end
    @test pipe.n_commands == 1000
    result = execute(pipe)
    @test result == fill([], 1000)
    @test pipe.n_commands == 0
end

@testset "Pipeline - Do Block" begin
    result = pipeline() do pipe
        for _ in 1:1000
            lrange("nothing", 0, -1; client=pipe)
        end
    end
    @test result == fill([], 1000)
end

@testset "Pipeline - MULTI/EXEC" begin
    no_filter_result = pipeline(; filter_multi_exec=false) do pipe
        multi(; client=pipe)
        for _ in 1:1000
            lrange("nothing", 0, -1; client=pipe)
        end
        exec(; client=pipe)
    end
    @test length(no_filter_result) == 1002
    @test no_filter_result[1] == "OK"
    @test no_filter_result[2:length(no_filter_result)-1] == fill("QUEUED", 1000)
    @test no_filter_result[end] == fill([], 1000)

    filter_result = pipeline() do pipe
        multi_exec(; client=pipe) do
            for _ in 1:1000
                lrange("nothing", 0, -1; client=pipe)
            end
        end
    end
    @test length(filter_result) == 1
    @test filter_result[1] == fill([], 1000)
end

flushall()