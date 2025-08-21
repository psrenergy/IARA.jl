
function train_nash_equilibrium_model(inputs::Inputs)
    run_time_options = RunTimeOptions(; nash_equilibrium_initialization = true)
    initialization_dir = output_path(inputs, run_time_options)
    if !isdir(initialization_dir)
        mkdir(initialization_dir)
    end
    if nash_equilibrium_initialization(inputs) ==
       Configurations_NashEquilibriumInitialization.MIN_COST_HEURISTIC
       @info("Initializing Nash Equilibrium: MIN COST HEURISTIC")
        initialize_nash_equilibrium(
            inputs,
            run_time_options,
        )
    else
       @info("Initializing Nash Equilibrium: READ BIDS FROM FILE")
        exts = [".csv", ".toml"]
        files = []
        if has_any_bid_simple_input_files(inputs)
            push!(files, bidding_group_quantity_bid_file(inputs))
            push!(files, bidding_group_price_bid_file(inputs))
        end
        # TODO: Add validation
        if has_price_taker(inputs, run_time_options)
            push!(files, "load_marginal_cost")
        end
        for ext in exts
            for file in files
                cp(
                    joinpath(path_case(inputs), file * "$ext"),
                    joinpath(initialization_dir, file * "$ext"),
                )
            end
        end
    end
    reinitialize_generation_time_series_for_nash_initialization!(inputs, run_time_options)
    if has_any_bid_simple_input_files(inputs)
        reinitialize_bids_time_series_for_nash_iteration!(inputs, run_time_options)
    end
    reinitialize_spot_time_series_for_nash_iteration!(inputs, run_time_options)
    update_number_of_segments_for_heuristic_bids!(inputs)

    for nash_equilibrium_iteration in 1:max_iteration_nash_equilibrium(inputs)
        # Train the model for the current iteration
        price_taker_asset_owners = index_of_elements(inputs, AssetOwner; filters = [is_price_taker])
        for asset_owner_index in price_taker_asset_owners
            run_time_options = RunTimeOptions(; asset_owner_index, nash_equilibrium_iteration)
            train_model_and_run_simulation(inputs, run_time_options)
        end
        price_maker_asset_owners = index_of_elements(inputs, AssetOwner; filters = [is_price_maker])
        for asset_owner_index in price_maker_asset_owners
            run_time_options = RunTimeOptions(; asset_owner_index, nash_equilibrium_iteration)
            train_model_and_run_simulation(inputs, run_time_options)
        end
        run_time_options = RunTimeOptions(; force_all_subscenarios = true, nash_equilibrium_iteration)
        gather_outputs_separated_by_asset_owners(inputs; run_time_options)
        reinitialize_bids_time_series_for_nash_iteration!(inputs, run_time_options)
        

        # TODO: Dont run on last iteration?
        simulate_all_periods_and_scenarios_of_market_clearing(inputs; nash_equilibrium_iteration)
        reinitialize_spot_time_series_for_nash_iteration!(inputs, run_time_options)

        post_proc_path = post_processing_path(inputs, run_time_options)
        if !isdir(post_proc_path)
            mkdir(post_proc_path)
        end
        outputs_post_processing = Outputs()
        model_outputs_time_series = OutputReaders()
        try
            post_process_outputs(inputs, outputs_post_processing, model_outputs_time_series, run_time_options)
        finally
            finalize_outputs!(outputs_post_processing)
            finalize_outputs!(model_outputs_time_series)
        end

        # Copy bidding group bids to the output folder in the last iteration
        if nash_equilibrium_iteration == max_iteration_nash_equilibrium(inputs)
            copy_bidding_group_bids_to_output_folder(inputs, run_time_options)
        end
    end

    return nothing
end

function initialize_nash_equilibrium(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    args...,
)
    train_model_and_run_simulation(inputs, run_time_options)
    update_number_of_segments_for_heuristic_bids!(inputs)
    reinitialize_generation_time_series_for_nash_initialization!(inputs, run_time_options)
    heuristic_bids_outputs = Outputs()
    initialize_heuristic_bids_outputs(inputs, heuristic_bids_outputs, run_time_options)
    for period in 1:number_of_periods(inputs)
        # Update the time series in the database to the current period
        update_time_series_from_db!(inputs, period)
        for scenario in 1:number_of_scenarios(inputs)
            # Update the time series in the external files to the current period and scenario
            update_time_series_views_from_external_files!(inputs; period, scenario)
            markup_bids_for_period_scenario(
                inputs,
                run_time_options,
                period,
                scenario;
                outputs = heuristic_bids_outputs,
            )
        end
    end
    finalize_outputs!(heuristic_bids_outputs)

    return nothing
end

function copy_bidding_group_bids_to_output_folder(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    # Copy the bidding group bids file to the output folder
    exts = [".csv", ".toml"]
    files = []
    push!(files, "bidding_group_energy_bid")
    push!(files, "bidding_group_price_bid")
    for ext in exts
        for file in files
            cp(
                joinpath(output_path(inputs, run_time_options), file * "$ext"),
                joinpath(output_path(inputs), file * "$ext"),
            )
        end
    end
    return nothing
end