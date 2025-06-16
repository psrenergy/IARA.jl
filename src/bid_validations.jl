function initialize_bid_validation_outputs(
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
)
    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    labels = bidding_group_label(inputs)[bidding_groups]

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        run_time_options,
        output_name = "bid_justification_status",
        dimensions = ["period", "scenario"],
        unit = "-",
        labels = labels,
    )
    if has_any_simple_bids(inputs)
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            run_time_options,
            output_name = "independent_bid_limit_violation_status",
            dimensions = ["period", "scenario"],
            unit = "-",
            labels = labels,
        )
    end
    if has_any_profile_bids(inputs)
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            run_time_options,
            output_name = "profile_bid_limit_violation_status",
            dimensions = ["period", "scenario"],
            unit = "-",
            labels = labels,
        )
    end

    return nothing
end

function validate_bids_for_period_scenario(
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions;
    period::Int,
    scenario::Int,
)
    if bids_justifications_exist(inputs)
        all_bid_justifications = open(bidding_group_bid_justifications_file(inputs), "r") do file
            return JSON.parse(file)
        end
        bid_justifications = findfirst(x -> x["period"] == period, all_bid_justifications)["justifications"]
    end
    bid_justification_status = zeros(Int, length(inputs.collections.bidding_group))
    if has_any_simple_bids(inputs)
        independent_bid_limit_violation_status = zeros(Int, length(inputs.collections.bidding_group))
        independent_bids_price = time_series_price_offer(inputs, period, scenario)
    end
    if has_any_profile_bids(inputs)
        profile_bid_limit_violation_status = zeros(Int, length(inputs.collections.bidding_group))
        profile_bids_price = time_series_price_offer_profile(inputs, period, scenario)
    end

    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])

    for (idx, bg) in enumerate(bidding_groups)
        bg_label = bidding_group_label(inputs, bg)
        if bids_justifications_exist(inputs) && !isnothing(bid_justifications)
            bid_justification_status[idx] = haskey(bid_justifications, bg_label) ? 1 : 0
        end
        if has_any_simple_bids(inputs)
            highest_bid = maximum(independent_bids_price[bg, :, :, :])
            if highest_bid > time_series_bid_price_limit_justified_independent(inputs)[bg]
                independent_bid_limit_violation_status[idx] = 2
            elseif highest_bid > time_series_bid_price_limit_not_justified_independent(inputs)[bg] &&
                   bid_justification_status[idx] == 0
                independent_bid_limit_violation_status[idx] = 1
            end
        end

        if has_any_profile_bids(inputs)
            highest_bid = maximum(profile_bids_price[bg, :, :, :])
            if highest_bid > time_series_bid_price_limit_justified_profile(inputs)[bg]
                profile_bid_limit_violation_status[idx] = 2
            elseif highest_bid > time_series_bid_price_limit_not_justified_profile(inputs)[bg] &&
                   bid_justification_status[idx] == 0
                profile_bid_limit_violation_status[idx] = 1
            end
        end
    end

    placeholder_subscenario = 1
    write_output_without_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "bid_justification_status",
        bid_justification_status;
        period,
        scenario,
        subscenario = placeholder_subscenario,
    )

    if has_any_simple_bids(inputs)
        write_output_without_subperiod!(
            outputs,
            inputs,
            run_time_options,
            "independent_bid_limit_violation_status",
            independent_bid_limit_violation_status;
            period,
            scenario,
            subscenario = placeholder_subscenario,
        )
    end

    if has_any_profile_bids(inputs)
        write_output_without_subperiod!(
            outputs,
            inputs,
            run_time_options,
            "profile_bid_limit_violation_status",
            profile_bid_limit_violation_status;
            period,
            scenario,
            subscenario = placeholder_subscenario,
        )
    end

    return nothing
end

function initialize_bid_price_limit_outputs(
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
)
    profile_bids_price_limit_outputs = [
        "bid_price_limit_justified_profile",
        "bid_price_limit_not_justified_profile",
    ]
    independent_bids_price_limit_outputs = [
        "bid_price_limit_justified_independent",
        "bid_price_limit_not_justified_independent",
    ]

    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    labels = bidding_group_label(inputs)[bidding_groups]

    if has_any_simple_bids(inputs)
        for output_name in independent_bids_price_limit_outputs
            initialize!(
                QuiverOutput,
                outputs;
                inputs,
                run_time_options,
                output_name = output_name,
                dimensions = ["period"],
                unit = "\$/MWh",
                labels = labels,
            )
        end
    end

    if has_any_profile_bids(inputs)
        for output_name in profile_bids_price_limit_outputs
            initialize!(
                QuiverOutput,
                outputs;
                inputs,
                run_time_options,
                output_name = output_name,
                dimensions = ["period"],
                unit = "\$/MWh",
                labels = labels,
            )
        end
    end

    return nothing
end

function bidding_group_bid_price_limits_for_period(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    period::Int;
    outputs::Union{Outputs, Nothing} = nothing,
)
    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    number_of_bidding_groups = length(bidding_groups)

    if !has_any_simple_bids(inputs) && !has_any_profile_bids(inputs)
        return nothing
    end

    if has_any_simple_bids(inputs)
        bidding_group_bid_price_limit_not_justified_independent = zeros(
            number_of_bidding_groups,
        )
        bidding_group_bid_price_limit_justified_independent = zeros(
            number_of_bidding_groups,
        )
    end

    if has_any_profile_bids(inputs)
        bidding_group_bid_price_limit_not_justified_profile = zeros(
            number_of_bidding_groups,
        )
        bidding_group_bid_price_limit_justified_profile = zeros(
            number_of_bidding_groups,
        )
    end

    bidding_group_number_of_risk_factors,
    bidding_group_hydro_units,
    bidding_group_thermal_units,
    bidding_group_renewable_units,
    bidding_group_demand_units = bidding_group_markup_units(inputs)

    for (idx, bg) in enumerate(bidding_groups)
        if !isempty(bidding_group_thermal_units[bg])
            max_thermal_cost = maximum(
                [thermal_unit_om_cost(inputs, t) for t in bidding_group_thermal_units[bg]],
            )
            reference_price = max(max_thermal_cost, bid_price_limit_low_reference(inputs))
        elseif !isempty(bidding_group_renewable_units[bg])
            reference_price = bid_price_limit_low_reference(inputs)
        else
            reference_price = bid_price_limit_high_reference(inputs)
        end

        if has_any_simple_bids(inputs)
            if use_bid_price_limits_from_file(inputs, bg)
                bidding_group_bid_price_limit_not_justified_independent[idx] =
                    time_series_bid_price_limit_non_justified_independent(inputs)[bg]
                bidding_group_bid_price_limit_justified_independent[idx] =
                    time_series_bid_price_limit_justified_independent(inputs)[bg]
            else
                bidding_group_bid_price_limit_not_justified_independent[idx] =
                    reference_price * (1.0 + bid_price_limit_markup_non_justified_independent(inputs))
                bidding_group_bid_price_limit_justified_independent[idx] =
                    reference_price * (1.0 + bid_price_limit_markup_justified_independent(inputs))
            end
        end

        if has_any_profile_bids(inputs)
            if use_bid_price_limits_from_file(inputs, bg)
                bidding_group_bid_price_limit_not_justified_profile[idx] =
                    time_series_bid_price_limit_non_justified_profile(inputs)[bg]
                bidding_group_bid_price_limit_justified_profile[idx] =
                    time_series_bid_price_limit_justified_profile(inputs)[bg]
            else
                bidding_group_bid_price_limit_not_justified_profile[idx] =
                    reference_price * (1.0 + bid_price_limit_markup_non_justified_profile(inputs))
                bidding_group_bid_price_limit_justified_profile[idx] =
                    reference_price * (1.0 + bid_price_limit_markup_justified_profile(inputs))
            end
        end
    end

    if has_any_simple_bids(inputs)
        write_output_without_scenario!(
            outputs,
            inputs,
            run_time_options,
            "bid_price_limit_not_justified_independent",
            bidding_group_bid_price_limit_not_justified_independent;
            period,
        )
        write_output_without_scenario!(
            outputs,
            inputs,
            run_time_options,
            "bid_price_limit_justified_independent",
            bidding_group_bid_price_limit_justified_independent;
            period,
        )
    end

    if has_any_profile_bids(inputs)
        write_output_without_scenario!(
            outputs,
            inputs,
            run_time_options,
            "bid_price_limit_not_justified_profile",
            bidding_group_bid_price_limit_not_justified_profile;
            period,
        )
        write_output_without_scenario!(
            outputs,
            inputs,
            run_time_options,
            "bid_price_limit_justified_profile",
            bidding_group_bid_price_limit_justified_profile;
            period,
        )
    end

    if is_market_clearing(inputs)
        serialize_bid_price_limits(
            inputs,
            bidding_group_bid_price_limit_not_justified_independent,
            bidding_group_bid_price_limit_justified_independent,
            bidding_group_bid_price_limit_not_justified_profile,
            bidding_group_bid_price_limit_justified_profile;
            period,
        )
    end

    return nothing
end
