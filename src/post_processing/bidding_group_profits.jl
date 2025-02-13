function _subtract_revenue_from_costs_with_subscenarios(
    revenue_reader::Quiver.Reader{Quiver.csv},
    costs_reader::Quiver.Reader{Quiver.csv},
    writer::Quiver.Writer{Quiver.csv},
)
    num_periods, num_scenarios, num_subscenarios, num_subperiods = revenue_reader.metadata.dimension_size

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for subperiod in 1:num_subperiods
                    Quiver.goto!(revenue_reader; period, scenario, subscenario, subperiod = subperiod)
                    revenue = revenue_reader.data

                    Quiver.goto!(costs_reader; period, scenario, subscenario, subperiod = subperiod)
                    costs = costs_reader.data

                    Quiver.write!(writer, revenue .- costs; period, scenario, subscenario, subperiod = subperiod)
                end
            end
        end
    end
    Quiver.close!(writer)
    Quiver.close!(revenue_reader)
    Quiver.close!(costs_reader)
    return nothing
end

"""
    calculate_profits_settlement(inputs, outputs_post_processing, model_outputs_time_serie, run_time_options)

Calculate the profits of the bidding groups for the different settlement types.
"""
function calculate_profits_settlement(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions,
)
    outputs_dir = output_path(inputs)
    post_processing_dir = post_processing_path(inputs)
    tempdir = joinpath(path_case(inputs), "temp")

    if settlement_type(inputs) == IARA.Configurations_SettlementType.EX_ANTE
        file_revenue = joinpath(
            post_processing_dir,
            "bidding_group_revenue_ex_ante" * run_time_file_suffixes(inputs, run_time_options),
        )
        settlement_string = "ex_ante"
    elseif settlement_type(inputs) == IARA.Configurations_SettlementType.EX_POST
        file_revenue = joinpath(
            post_processing_dir,
            "bidding_group_revenue_ex_post" * run_time_file_suffixes(inputs, run_time_options),
        )
        settlement_string = "ex_post"
    elseif settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
        file_revenue = joinpath(
            post_processing_dir,
            "bidding_group_total_revenue" * run_time_file_suffixes(inputs, run_time_options),
        )
        settlement_string = "total"
    else
        error("Settlement type not supported")
    end

    bidding_group_revenue_reader =
        open_time_series_output(
            inputs,
            model_outputs_time_serie,
            file_revenue,
        )

    # The costs associated to the bgs are from the ex post settlement
    bidding_group_costs_files = get_costs_files(post_processing_dir; from_ex_post = true)
    bidding_group_costs_files = get_filename(bidding_group_costs_files[1])
    dimensions = ["period", "scenario", "subscenario", "subperiod"]

    bidding_group_costs_reader =
        open_time_series_output(
            inputs,
            model_outputs_time_serie,
            bidding_group_costs_files,
        )

    initialize!(
        QuiverOutput,
        outputs_post_processing;
        inputs,
        output_name = "bidding_group_profit_$(settlement_string)",
        dimensions = dimensions,
        unit = "\$",
        labels = bidding_group_revenue_reader.metadata.labels,
        run_time_options,
        dir_path = post_processing_dir,
    )

    writer = get_writer(outputs_post_processing, inputs, run_time_options, "bidding_group_profit_$(settlement_string)")

    _subtract_revenue_from_costs_with_subscenarios(
        bidding_group_revenue_reader,
        bidding_group_costs_reader,
        writer,
    )

    return nothing
end
