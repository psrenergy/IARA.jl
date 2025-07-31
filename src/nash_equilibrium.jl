function initialize_nash_equilibrium(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    args...,
)
    train_model_and_run_simulation(inputs, run_time_options)
    heuristic_bids_outputs = Outputs()
    initialize_heuristic_bids_outputs(inputs, heuristic_bids_outputs, run_time_options)
    for period in 1:number_of_periods(inputs)
        # Update the time series in the database to the current period
        update_time_series_from_db!(inputs, period)

        run_time_options = RunTimeOptions()
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

    return nothing
end
