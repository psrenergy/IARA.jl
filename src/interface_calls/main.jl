#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function interface_call(path::String; kwargs...)
    args = IARA.Args(path, IARA.RunMode.MARKET_CLEARING; kwargs...)
    return main(args)
end

function main(args::IARA.Args)
    # Initialize dlls and other possible defaults
    IARA.initialize(args)
    inputs = IARA.load_inputs(args)

    try
        run_interface_tasks(inputs)
    finally
        IARA.clean_up(inputs)
        @info("done!")
    end
    return nothing
end

function julia_main()::Cint
    COMPILED[] = true
    try
        main(ARGS)
    catch
        return 1
    end
    return 0
end

function run_interface_tasks(inputs::IARA.AbstractInputs)
    write_elements_to_json(inputs)
    create_plots(inputs)
    return nothing
end
