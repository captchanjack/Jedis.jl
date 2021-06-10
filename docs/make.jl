using Documenter
using Jedis

makedocs(
    sitename="Jedis.jl Documentation",
    # format = Documenter.HTML(prettyurls = false),
    pages=[
        "Home" => "index.md",
        "Client" => "client.md",
        "Commands" => "commands.md",
        "Pipelining" => "pipeline.md",
        "Pub/Sub" => "pubsub.md"
    ],
    modules=[Jedis]
)

deploydocs(
    repo="github.com/captchanjack/Jedis.jl.git",
    devbranch="main",
    devurl="docs"
)