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
    args = IARA.Args(path, IARA.RunMode.INTERFACE_CALL; kwargs...)
    return main(args)
end

function main(args::IARA.Args)
    IARA.initialize(args)
    validate_interface_run_modes(args)
    inputs = IARA.load_inputs(args)

    try
        run_interface_tasks(inputs)
    finally
        IARA.clean_up(inputs)
        @info("done!")
    end
    return nothing
end

function run_interface_tasks(inputs::IARA.AbstractInputs)
    write_elements_to_json(inputs)
    create_plots(inputs)
    return nothing
end

function validate_interface_run_modes(args::IARA.Args)
    args_list = [
        [
            args.path,
            "--run-mode=single-period-heuristic-bid",
            "--period=1",
            "--plot-ui-results",
            "--delete-output-folder-before-execution",
        ],
        [
            args.path,
            "--run-mode=single-period-market-clearing",
            "--period=1",
            "--plot-ui-results",
            "--delete-output-folder-before-execution",
        ],
    ]
    run_modes_list = [
        IARA.RunMode.SINGLE_PERIOD_HEURISTIC_BID,
        IARA.RunMode.SINGLE_PERIOD_MARKET_CLEARING,
    ]
    @info("Validating database for interface run modes")
    for (args_iter, run_mode_iter) in zip(args_list, run_modes_list)
        @info("    Validating database for $(run_mode_iter)")
        IARA.validate_database(args_iter)
    end
    @info("Database validated for interface run modes")
    return nothing
end
