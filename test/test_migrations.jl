module TestMigrations

using Test
using IARA

const PSRDatabaseSQLite = IARA.PSRDatabaseSQLite

function test_iara_migrations()
    @test PSRDatabaseSQLite.test_migrations(IARA.migrations_directory())
    return nothing
end

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$name", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
end

TestMigrations.runtests()

end
