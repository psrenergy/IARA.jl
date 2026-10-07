"""
    calculate_profits_settlement(inputs, run_time_options)

Calculate the profits of the bidding groups for the different settlement types.
"""
function calculate_profits_settlement(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    post_processing_dir = post_processing_path(inputs, run_time_options)

    if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_ANTE
        file_revenue = joinpath(
            post_processing_dir,
            "bidding_group_revenue_ex_ante" * run_time_file_suffixes(inputs, run_time_options),
        )
        settlement_string = "ex_ante"
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_POST
        file_revenue = joinpath(
            post_processing_dir,
            "bidding_group_revenue_ex_post" * run_time_file_suffixes(inputs, run_time_options),
        )
        settlement_string = "ex_post"
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
        file_revenue = joinpath(
            post_processing_dir,
            "bidding_group_total_revenue" * run_time_file_suffixes(inputs, run_time_options),
        )
        settlement_string = "total"
    else
        error("Settlement type not supported")
    end

    # The costs associated to the bgs are from the ex post settlement
    bidding_group_fixed_costs_files = get_fixed_costs_files(post_processing_dir; from_ex_post = true)
    bidding_group_variable_costs_files = get_variable_costs_files(post_processing_dir; from_ex_post = true)
    if length(bidding_group_fixed_costs_files) == 0 || length(bidding_group_variable_costs_files) == 0
        return nothing
    end
    bidding_group_fixed_costs_file = get_filename(bidding_group_fixed_costs_files[1])
    bidding_group_variable_costs_file = get_filename(bidding_group_variable_costs_files[1])

    tempdir = joinpath(output_path(inputs, run_time_options), "temp")
    file_total_costs = joinpath(
        tempdir,
        "bidding_group_total_costs_$(settlement_string)" * run_time_file_suffixes(inputs, run_time_options),
    )
    Quiver.apply_expression(
        file_total_costs,
        [bidding_group_fixed_costs_file, bidding_group_variable_costs_file],
        +,
        Quiver.csv;
        digits = 6,
    )

    file_profit = joinpath(
        post_processing_dir,
        "bidding_group_profit_$(settlement_string)" * run_time_file_suffixes(inputs, run_time_options),
    )

    # The elastic demand revenue is written for the same clearing procedure as the variable costs, if there is elastic
    # demand in the bidding groups
    bidding_group_elastic_demand_revenue_file = joinpath(
        post_processing_dir,
        replace(
            basename(bidding_group_variable_costs_file),
            "bidding_group_variable_costs" => "bidding_group_elastic_demand_revenue",
        ),
    )

    if isfile(bidding_group_elastic_demand_revenue_file * ".csv")
        Quiver.apply_expression(
            file_profit,
            [file_revenue, file_total_costs, bidding_group_elastic_demand_revenue_file],
            (revenue, costs, elastic_demand_revenue) -> revenue - costs + elastic_demand_revenue,
            Quiver.csv;
            digits = 6,
        )
    else
        Quiver.apply_expression(
            file_profit,
            [file_revenue, file_total_costs],
            -,
            Quiver.csv;
            digits = 6,
        )
    end

    return nothing
end
