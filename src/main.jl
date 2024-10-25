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

It requires a vector containing the path for the case and it it may contain the flag `--write-lp` to write the subproblems to LP files.
"""
function main(args::Vector{String})
    print_banner()

    # Parse commandline arguments
    args = Args(args)

    # Initialize dlls and other possible defaults
    initialize()

    inputs = load_inputs(args)
    if inputs.caches.templates_for_time_series_files_have_been_generated
        @info("Templates for time series files have been generated. Please fill them and run the application again.")
    end
    if inputs.caches.templates_for_waveguide_files_have_been_generated
        @info("Templates for waveguide files have been generated. Please fill them and run the application again.")
    end
    if inputs.caches.templates_for_time_series_files_have_been_generated ||
       inputs.caches.templates_for_waveguide_files_have_been_generated
        return nothing
    end
    initialize_output_dir(inputs)

    try
        run_algorithms(inputs)
        post_processing(inputs)
        if args.plot_results
            build_plots(inputs)
        end
    finally
        clean_up(inputs)
    end
    return nothing
end

function run_algorithms(inputs)
    if run_mode(inputs) == Configurations_RunMode.CENTRALIZED_OPERATION
        run_time_options = RunTimeOptions()
        train_model_and_run_simulation(inputs, run_time_options)
    elseif run_mode(inputs) == Configurations_RunMode.PRICE_TAKER_BID
        price_taker_asset_owners = index_of_elements(inputs, AssetOwner; filters = [is_price_taker])
        for asset_owner_index in price_taker_asset_owners
            run_time_options = RunTimeOptions(; asset_owner_index)
            train_model_and_run_simulation(inputs, run_time_options)
        end
    elseif run_mode(inputs) == Configurations_RunMode.STRATEGIC_BID
        price_maker_asset_owners = index_of_elements(inputs, AssetOwner; filters = [is_price_maker])
        for asset_owner_index in price_maker_asset_owners
            run_time_options = RunTimeOptions(; asset_owner_index)
            train_model_and_run_simulation(inputs, run_time_options)
        end
    elseif run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING
        simulate_all_periods_and_scenarios_of_market_clearing(inputs)
    elseif run_mode(inputs) == Configurations_RunMode.CENTRALIZED_OPERATION_SIMULATION
        run_time_options = RunTimeOptions()
        load_cuts_and_run_simulation(inputs, run_time_options)
    else
        error("Run mode $(run_mode(inputs)) not implemented")
    end
    return nothing
end

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
            println("Running clearing for period: $period")
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

function run_clearing_simulation(
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    period::Int,
)
    println("   Running simulation $(run_time_options.clearing_model_procedure)")
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
    println(banner)
    @info("IARA - version: $PKG_VERSION")
    return nothing
end

function clean_up(inputs)
    close_study!(inputs.db)
    close_all_external_files_time_series_readers!(inputs)
    PSRBridge.finalize!(inputs)
    delete_temp_files(inputs)
    return nothing
end
