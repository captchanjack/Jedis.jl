struct RedisError <: Exception
    err_type::AbstractString
    err_msg::AbstractString
end

function Base.showerror(io::IO, ex::RedisError; backtrace=true)
    printstyled(io, "$(typeof(ex)): $(ex.err_type)\n\n" * ex.err_msg * "\n", color=Base.error_color())
end