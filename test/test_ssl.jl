@testset "SSL/TLS" begin
    ssl_config = get_ssl_config(
        ssl_certfile=joinpath(@__DIR__, "..", "docker/ssl/redis.crt"),
        ssl_keyfile=joinpath(@__DIR__, "..", "docker/ssl/redis.key"),
        ssl_ca_certs=joinpath(@__DIR__, "..", "docker/ssl/ca.crt")
    )

    # Port 6380 corresponds to port defined for redis-ssl container in docker/docker-compose.yml
    client = Client(port=6380, ssl_config=ssl_config)
    set_global_client(client)

    set("test", "ssl success")
    @test get("test") == "ssl success"

    flushall()
end