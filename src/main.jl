#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

"""
    main(args::Vector{String})

Main function to run the IARA application.
"""
function main(args::Vector{String})
    print_banner()

    # Parse commandline arguments
    args = Args(args)

    return main(args)
end

function main(args::Args)

    # Initialize dlls and other possible defaults
    initialize(args)

    inputs = load_inputs(args)

    try
        validate(inputs)
        run_algorithms(inputs)
        post_processing(inputs)
    finally
        clean_up(inputs)
    end
    return nothing
end

# entry points for the different run modes

const ARGS_KEYWORDS = """
keywords:

- `outputs_path::String`. Path to the outputs. default = joinpath(path, "outputs")
- `plot_outputs::Bool`. Plot all outputs after the run. default = true
- `write_lp::Bool`. Write the LP files. default = false
"""

"""
    train_min_cost(path::String; kwargs...)

Train the model to minimize the total cost of the system.

$ARGS_KEYWORDS
"""
function train_min_cost(path::String; kwargs...)
    args = Args(path, RunMode.TRAIN_MIN_COST; kwargs...)
    return main(args)
end

"""
    price_taker_bid(path::String; kwargs...)

Run the model with the price taker bid strategy.

$ARGS_KEYWORDS
"""
function price_taker_bid(path::String; kwargs...)
    args = Args(path, RunMode.PRICE_TAKER_BID; kwargs...)
    return main(args)
end

"""
    strategic_bid(path::String; kwargs...)

Run the model with the strategic bid strategy.

$ARGS_KEYWORDS
"""
function strategic_bid(path::String; kwargs...)
    args = Args(path, RunMode.STRATEGIC_BID; kwargs...)
    return main(args)
end

"""
    market_clearing(path::String; kwargs...)

Run the model with the market clearing strategy.

$ARGS_KEYWORDS
"""
function market_clearing(path::String; kwargs...)
    args = Args(path, RunMode.MARKET_CLEARING; kwargs...)
    return main(args)
end

"""
    min_cost(path::String; kwargs...)

Run the model with the minimum cost strategy.

$ARGS_KEYWORDS
"""
function min_cost(path::String; kwargs...)
    args = Args(path, RunMode.MIN_COST; kwargs...)
    return main(args)
end

"""
    run_algorithms(inputs)

Run the algorithms according to the run mode.
"""
function run_algorithms(inputs)
    log_inputs(inputs)
    if run_mode(inputs) == RunMode.TRAIN_MIN_COST
        run_time_options = RunTimeOptions()
        train_model_and_run_simulation(inputs, run_time_options)
    elseif run_mode(inputs) == RunMode.PRICE_TAKER_BID
        price_taker_asset_owners = index_of_elements(inputs, AssetOwner; filters = [is_price_taker])
        for asset_owner_index in price_taker_asset_owners
            run_time_options = RunTimeOptions(; asset_owner_index)
            train_model_and_run_simulation(inputs, run_time_options)
        end
    elseif run_mode(inputs) == RunMode.STRATEGIC_BID
        price_maker_asset_owners = index_of_elements(inputs, AssetOwner; filters = [is_price_maker])
        for asset_owner_index in price_maker_asset_owners
            run_time_options = RunTimeOptions(; asset_owner_index)
            train_model_and_run_simulation(inputs, run_time_options)
        end
    elseif run_mode(inputs) == RunMode.MARKET_CLEARING
        simulate_all_periods_and_scenarios_of_market_clearing(inputs)
    elseif run_mode(inputs) == RunMode.MIN_COST
        run_time_options = RunTimeOptions()
        load_cuts_and_run_simulation(inputs, run_time_options)
    else
        error("Run mode $(run_mode(inputs)) not implemented")
    end
    return nothing
end

"""
    train_model_and_run_simulation(inputs::Inputs, run_time_options::RunTimeOptions)

Train the model and run the simulation.
"""
function train_model_and_run_simulation(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    model = build_model(inputs, run_time_options)
    train_model!(model, inputs)
    outputs = initialize_outputs(inputs, run_time_options)
    try
        simulate_all_periods_and_scenarios_of_trained_model(model, inputs, outputs, run_time_options)
    finally
        finalize_outputs!(outputs)
    end
    return nothing
end

"""
    load_cuts_and_run_simulation(inputs::Inputs, run_time_options::RunTimeOptions)

Load the cuts and run the simulation.
"""
function load_cuts_and_run_simulation(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    model = build_model(inputs, run_time_options)
    read_cuts_to_model!(model, inputs)
    outputs = initialize_outputs(inputs, run_time_options)
    try
        simulate_all_periods_and_scenarios_of_trained_model(model, inputs, outputs, run_time_options)
    finally
        finalize_outputs!(outputs)
    end
    return nothing
end

"""
    simulate_all_periods_and_scenarios_of_trained_model(
        model::ProblemModel,
        inputs::Inputs,
        outputs::Outputs,
        run_time_options::RunTimeOptions,
    )

Simulate all periods and scenarios of a trained model.
"""
function simulate_all_periods_and_scenarios_of_trained_model(
    model::ProblemModel,
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
)
    # Simulate all periods and scenarios
    simulation_results = simulate(model, inputs, outputs, run_time_options)

    # Write outputs per period, scenario and asset owner
    for period in 1:number_of_periods(inputs)
        # Update the time series in the database to the current period
        update_time_series_from_db!(inputs, period)
        for scenario in 1:number_of_scenarios(inputs)
            # Update the time series in the external files to the current period and scenario
            update_time_series_views_from_external_files!(inputs; period, scenario)

            simulation_results_from_period_scenario = get_simulation_results_from_period_scenario(
                simulation_results,
                period,
                scenario,
            )

            # Write in the files the output of a specific period and scenario
            model_action(
                outputs,
                inputs,
                run_time_options,
                simulation_results_from_period_scenario,
                period,
                scenario,
                1, # subscenario is fixed to 1
                WriteOutput,
            )
        end
    end

    return nothing
end

"""
    simulate_all_periods_and_scenarios_of_market_clearing(inputs::Inputs)

Simulate all periods and scenarios of the market clearing.
"""
function simulate_all_periods_and_scenarios_of_market_clearing(
    inputs::Inputs,
)
    # Initialize the outputs
    heuristic_bids_outputs,
    ex_ante_physical_outputs,
    ex_ante_commercial_outputs,
    ex_post_physical_outputs,
    ex_post_commercial_outputs =
        build_clearing_outputs(inputs)

    try
        for period in 1:number_of_periods(inputs)
            Log.info("Running clearing for period: $period")
            # Update the time series in the database to the current period
            update_time_series_from_db!(inputs, period)

            # Heuristic bids
            if generate_heuristic_bids_for_clearing(inputs)
                run_time_options = RunTimeOptions()
                for scenario in 1:number_of_scenarios(inputs)
                    # Update the time series in the external files to the current period and scenario
                    update_time_series_views_from_external_files!(inputs; period, scenario)
                    if any_elements(inputs, BiddingGroup)
                        markup_offers_for_period_scenario(
                            inputs,
                            heuristic_bids_outputs,
                            run_time_options,
                            period,
                            scenario,
                        )
                    end
                    if clearing_hydro_representation(inputs) ==
                       Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
                        virtual_reservoir_markup_offers_for_period_scenario(
                            inputs,
                            heuristic_bids_outputs,
                            run_time_options,
                            period,
                            scenario,
                        )
                    end
                end
            end

            # Clearing problems
            run_time_options = RunTimeOptions(; clearing_model_procedure = RunTime_ClearingProcedure.EX_ANTE_PHYSICAL)
            run_clearing_simulation(inputs, ex_ante_physical_outputs, run_time_options, period)

            run_time_options =
                RunTimeOptions(; clearing_model_procedure = RunTime_ClearingProcedure.EX_ANTE_COMMERCIAL)
            run_clearing_simulation(inputs, ex_ante_commercial_outputs, run_time_options, period)

            run_time_options = RunTimeOptions(; clearing_model_procedure = RunTime_ClearingProcedure.EX_POST_PHYSICAL)
            run_clearing_simulation(inputs, ex_post_physical_outputs, run_time_options, period)

            run_time_options =
                RunTimeOptions(; clearing_model_procedure = RunTime_ClearingProcedure.EX_POST_COMMERCIAL)
            run_clearing_simulation(inputs, ex_post_commercial_outputs, run_time_options, period)
        end
    finally
        finalize_clearing_outputs!(
            heuristic_bids_outputs,
            ex_ante_physical_outputs,
            ex_ante_commercial_outputs,
            ex_post_physical_outputs,
            ex_post_commercial_outputs,
        )
    end

    return nothing
end

"""
    run_clearing_simulation(
        inputs::Inputs,
        outputs::Outputs,
        run_time_options::RunTimeOptions,
        period::Int,
    )

Run the clearing simulation.
"""
function run_clearing_simulation(
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    period::Int,
)
    if skip_clearing_procedure(inputs, run_time_options)
        return nothing
    end

    Log.info("   Running simulation $(run_time_options.clearing_model_procedure)")
    model = build_model(inputs, run_time_options; current_period = period)

    if use_fcf_in_clearing(inputs)
        read_cuts_to_model!(model, inputs; current_period = period)
    end

    simulation_results = simulate(model, inputs, outputs, run_time_options; current_period = period)

    for scenario in 1:number_of_scenarios(inputs)
        # Update the time series in the external files to the current period and scenario
        update_time_series_views_from_external_files!(inputs; period, scenario)

        for subscenario in 1:number_of_subscenarios(inputs, run_time_options)
            simulation_results_from_period_scenario_subscenario =
                get_simulation_results_from_period_scenario_subscenario(
                    simulation_results,
                    inputs,
                    run_time_options,
                    1, # since we simulate one period at a time, the simulation_results period dimension is always 1
                    scenario,
                    subscenario,
                )

            if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS &&
               run_time_options.clearing_model_procedure == RunTime_ClearingProcedure.EX_POST_PHYSICAL
                post_process_virtual_reservoirs!(
                    inputs,
                    run_time_options,
                    simulation_results_from_period_scenario_subscenario,
                    outputs,
                    period,
                    scenario,
                )
            end
            # Write in the files the output of a specific period and scenario
            model_action(
                outputs,
                inputs,
                run_time_options,
                simulation_results_from_period_scenario_subscenario,
                period,
                scenario,
                subscenario,
                WriteOutput,
            )

            if subscenario == 1
                # Serialize the variables to be used in other clearing problems
                serialize_clearing_variables(
                    outputs,
                    inputs,
                    run_time_options,
                    simulation_results_from_period_scenario_subscenario;
                    period,
                    scenario,
                )
            end
        end
    end

    return nothing
end

function print_banner()
    banner = raw"""
     _____          _____            
    |_   _|   /\   |  __ \     /\    
      | |    /  \  | |__) |   /  \   
      | |   / /\ \ |  _  /   / /\ \  
     _| |_ / ____ \| | \ \  / ____ \ 
    |_____/_/    \_\_|  \_\/_/    \_\
    """
    Log.info(banner)
    Log.info("IARA - version: $PKG_VERSION")
    return nothing
end

function clean_up(inputs)
    close_study!(inputs.db)
    close_all_external_files_time_series_readers!(inputs)
    PSRBridge.finalize!(inputs)
    delete_temp_files(inputs)
    finalize_logger()
    return nothing
end
