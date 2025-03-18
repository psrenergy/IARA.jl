#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

const COMPILED = Ref{Bool}(false)

function is_compiled()::Bool
    return COMPILED[]
end

function main(args::Args)
    initialize(args)
    inputs = load_inputs(args)

    try
        run_algorithms(inputs)
        post_processing(inputs)
    finally
        clean_up(inputs)
    end
    return nothing
end

function main(args::Vector{String})
    args = Args(args)
    if args.run_mode == RunMode.INTERFACE_CALL
        return InterfaceCalls.main(args)
    else
        return main(args)
    end
end

function julia_main()::Cint
    COMPILED[] = true
    try
        main(ARGS)
    catch e
        error_log_file = "iara_error.log"
        println(
            "Error running model. Please consult the file: $error_log_file.",
        )
        open(error_log_file, "w") do io
            println(io, "IARA v$PKG_VERSION ($GIT_DATE)")
            return showerror(io, e, catch_backtrace())
        end
        return 1
    end
    return 0
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
    single_period_market_clearing(path::String; kwargs...)

Run the model with the single period market clearing strategy.
"""
function single_period_market_clearing(path::String; kwargs...)
    args = Args(path, RunMode.SINGLE_PERIOD_MARKET_CLEARING; kwargs...)
    return main(args)
end

"""
    single_period_heuristic_bid(path::String; kwargs...)

Generate heuristic bids for a single period.
"""
function single_period_heuristic_bid(path::String; kwargs...)
    args = Args(path, RunMode.SINGLE_PERIOD_HEURISTIC_BID; kwargs...)
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
    elseif run_mode(inputs) == RunMode.SINGLE_PERIOD_MARKET_CLEARING
        simulate_all_scenarios_of_single_period_market_clearing(inputs)
    elseif run_mode(inputs) == RunMode.SINGLE_PERIOD_HEURISTIC_BID
        single_period_heuristic_bid(inputs)
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
    # Build period-season map
    if cyclic_policy_graph(inputs) && !has_period_season_map_file(inputs)
        create_period_season_map!(inputs, model)
    end

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
    # Update the number of offer segments for the heuristic bids
    if generate_heuristic_bids_for_clearing(inputs)
        maximum_number_of_offer_segments = maximum_number_of_offer_segments_for_heuristic_bids(inputs)
        update_number_of_bid_segments!(inputs, maximum_number_of_offer_segments)

        @info("Heuristic bids")
        @info("   Number of segments: $maximum_number_of_offer_segments")
        @info("")
    end

    # Initialize the outputs
    heuristic_bids_outputs,
    ex_ante_physical_outputs,
    ex_ante_commercial_outputs,
    ex_post_physical_outputs,
    ex_post_commercial_outputs =
        build_clearing_outputs(inputs)

    # Build models
    run_time_options = RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_ANTE_PHYSICAL)
    ex_ante_physical_model = build_model(inputs, run_time_options)
    run_time_options =
        RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_ANTE_COMMERCIAL)
    ex_ante_commercial_model = build_model(inputs, run_time_options)
    run_time_options = RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_POST_PHYSICAL)
    ex_post_physical_model = build_model(inputs, run_time_options)
    run_time_options =
        RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_POST_COMMERCIAL)
    ex_post_commercial_model = build_model(inputs, run_time_options) 

    # Build period-season map
    if cyclic_policy_graph(inputs) && !has_period_season_map_file(inputs)
        create_period_season_map!(inputs, ex_ante_physical_model)
    end

    try
        for period in 1:number_of_periods(inputs)
            @info("Running clearing for period: $period")
            # Update the time series in the database to the current period
            update_time_series_from_db!(inputs, period)

            # Heuristic bids
            if generate_heuristic_bids_for_clearing(inputs)
                run_time_options = RunTimeOptions()
                for scenario in 1:number_of_scenarios(inputs)
                    # Update the time series in the external files to the current period and scenario
                    update_time_series_views_from_external_files!(inputs; period, scenario)
                    if any_elements(inputs, BiddingGroup)
                        if has_any_simple_bids(inputs)
                            markup_offers_for_period_scenario(
                                inputs,
                                heuristic_bids_outputs,
                                run_time_options,
                                period,
                                scenario,
                            )
                        end
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
            run_time_options = RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_ANTE_PHYSICAL)
            run_clearing_simulation(ex_ante_physical_model, inputs, ex_ante_physical_outputs, run_time_options, period)

            run_time_options =
                RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_ANTE_COMMERCIAL)
            run_clearing_simulation(ex_ante_commercial_model, inputs, ex_ante_commercial_outputs, run_time_options, period)

            run_time_options = RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_POST_PHYSICAL)
            run_clearing_simulation(ex_post_physical_model, inputs, ex_post_physical_outputs, run_time_options, period)

            run_time_options =
                RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_POST_COMMERCIAL)
            run_clearing_simulation(ex_post_commercial_model, inputs, ex_post_commercial_outputs, run_time_options, period)
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
    simulate_all_scenarios_of_single_period_market_clearing(inputs::Inputs)

Simulate all periods and scenarios of the market clearing.
"""
function simulate_all_scenarios_of_single_period_market_clearing(
    inputs::Inputs,
)
    # Update the number of offer segments for the heuristic bids
    if generate_heuristic_bids_for_clearing(inputs)
        maximum_number_of_offer_segments = maximum_number_of_offer_segments_for_heuristic_bids(inputs)
        update_number_of_bid_segments!(inputs, maximum_number_of_offer_segments)
    end

    # Initialize the outputs
    heuristic_bids_outputs,
    ex_ante_physical_outputs,
    ex_ante_commercial_outputs,
    ex_post_physical_outputs,
    ex_post_commercial_outputs =
        build_clearing_outputs(inputs)

    # Build models
    run_time_options = RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_ANTE_PHYSICAL)
    ex_ante_physical_model = build_model(inputs, run_time_options)
    run_time_options =
        RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_ANTE_COMMERCIAL)
    ex_ante_commercial_model = build_model(inputs, run_time_options)
    run_time_options = RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_POST_PHYSICAL)
    ex_post_physical_model = build_model(inputs, run_time_options)
    run_time_options =
        RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_POST_COMMERCIAL)
    ex_post_commercial_model = build_model(inputs, run_time_options) 

    # Build period-season map
    if cyclic_policy_graph(inputs) && !has_period_season_map_file(inputs)
        create_period_season_map!(inputs, ex_ante_physical_model)
    end

    try
        period = inputs.args.period
        @info("Running clearing for period: $period")
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
        run_time_options = RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_ANTE_PHYSICAL)
        run_clearing_simulation(ex_ante_physical_model, inputs, ex_ante_physical_outputs, run_time_options, period)

        run_time_options =
            RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_ANTE_COMMERCIAL)
        run_clearing_simulation(ex_ante_commercial_model, inputs, ex_ante_commercial_outputs, run_time_options, period)

        run_time_options = RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_POST_PHYSICAL)
        run_clearing_simulation(ex_post_physical_model, inputs, ex_post_physical_outputs, run_time_options, period)

        run_time_options =
            RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_POST_COMMERCIAL)
        run_clearing_simulation(ex_post_commercial_model, inputs, ex_post_commercial_outputs, run_time_options, period)
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
        model::ProblemModel,
        inputs::Inputs,
        outputs::Outputs,
        run_time_options::RunTimeOptions,
        period::Int,
    )

Run the clearing simulation.
"""
function run_clearing_simulation(
    model::ProblemModel,
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    period::Int,
)
    if skip_clearing_subproblem(inputs, run_time_options)
        return nothing
    end

    @info("   Running simulation $(run_time_options.clearing_model_subproblem)")

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
               run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_POST_PHYSICAL
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

"""
    single_period_heuristic_bid(inputs::Inputs)

Generate heuristic bids for a single period.
"""
function single_period_heuristic_bid(
    inputs::Inputs,
)
    run_time_options = RunTimeOptions()

    # Update the number of offer segments for the heuristic bids
    maximum_number_of_offer_segments = maximum_number_of_offer_segments_for_heuristic_bids(inputs)
    update_number_of_bid_segments!(inputs, maximum_number_of_offer_segments)

    # Initialize the outputs
    heuristic_bids_outputs = Outputs()
    if any_elements(inputs, BiddingGroup)
        initialize_heuristic_bids_outputs(inputs, heuristic_bids_outputs, run_time_options)
    end
    if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
        initialize_virtual_reservoir_bids_outputs(inputs, heuristic_bids_outputs, run_time_options)
    end

    try
        period = inputs.args.period
        @info("Building heuristic bids for period: $period")
        # Update the time series in the database to the current period
        update_time_series_from_db!(inputs, period)

        # Heuristic bids
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
    finally
        finalize_outputs!(heuristic_bids_outputs)
    end

    if any_elements(inputs, BiddingGroup)
        generate_individual_bids_files(inputs)
    end
    if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
        generate_individual_virtual_reservoir_bids_files(inputs)
    end

    return nothing
end

function validate_database(args::Vector{String})
    args = Args(args)
    inputs = load_inputs(args)
    close_study!(inputs.db)
    close_all_external_files_time_series_readers!(inputs)
    return nothing
end

function print_banner()
    @info("IARA - version: $PKG_VERSION")
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
