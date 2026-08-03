#############################################################################
#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

module TestMigrations

using Test
using IARA

function test_iara_migrations()
    # Quiver's Julia bindings only expose a one-directional `Quiver.from_migrations`
    # (build a fresh database up to the latest version). There is no exposed way to
    # run migrations down, so the old PSRDatabaseSQLite.test_migrations round-trip
    # (apply every migration up, then down, and assert the database ends up empty)
    # can't be reproduced against Quiver as-is.
    @test_broken false
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
