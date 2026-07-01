"""
    migrations_directory()

Return the path to the migration directory.
"""
function migrations_directory()
    path = if is_compiled()
        joinpath(Sys.BINDIR, "database", "migrations")
    else
        joinpath(dirname(@__DIR__), "database", "migrations")
    end
    @assert isdir(path)
    return path
end

