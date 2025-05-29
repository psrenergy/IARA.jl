function accepted_offer_revenue(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions;
    physical_variables_suffix::String,
    commercial_variables_suffix::String,
    output_suffix::String,
    is_double_settlement_ex_post::Bool,
    ex_ante_physical_suffix::String,
    output_has_subscenario::Bool,
)
    outputs_dir = output_path(inputs)
    output_name = "virtual_reservoir_accepted_offer_revenue" * output_suffix

    vr_generation_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(outputs_dir, "virtual_reservoir_generation" * physical_variables_suffix),
    )
    vr_marginal_cost_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(outputs_dir, "virtual_reservoir_marginal_cost" * commercial_variables_suffix),
    )

    if is_double_settlement_ex_post
        vr_generation_ex_ante_reader = open_time_series_output(
            inputs,
            model_outputs_time_serie,
            joinpath(outputs_dir, "virtual_reservoir_generation" * ex_ante_physical_suffix),
        )
    end

    dimensions = output_has_subscenario ? ["period", "scenario", "subscenario"] : ["period", "scenario"]
    initialize!(
        QuiverOutput,
        outputs_post_processing;
        inputs,
        output_name = output_name,
        dimensions = dimensions,
        unit = "\$",
        labels = labels_for_output_by_pair_of_agents(
            inputs,
            run_time_options,
            inputs.collections.virtual_reservoir,
            inputs.collections.asset_owner;
            index_getter = virtual_reservoir_asset_owner_indices,
        ),
        run_time_options,
        dir_path = post_processing_path(inputs),
    )

    writer = outputs_post_processing.outputs[output_name].writer

    num_periods = is_single_period(inputs) ? 1 : number_of_periods(inputs)
    for period in 1:num_periods
        for scenario in scenarios(inputs)
            for subscenario in subscenarios(inputs, run_time_options)
                if has_subscenario(vr_marginal_cost_reader)
                    Quiver.goto!(vr_marginal_cost_reader; period, scenario, subscenario = subscenario)
                else
                    Quiver.goto!(vr_marginal_cost_reader; period, scenario)
                end
                price = vr_marginal_cost_reader.data

                number_of_pairs = sum(length.(virtual_reservoir_asset_owner_indices(inputs)))
                vr_ao_generation = zeros(number_of_pairs)
                for bid_segment in 1:maximum_number_of_vr_bidding_segments(inputs)
                    if has_subscenario(vr_generation_reader)
                        Quiver.goto!(
                            vr_generation_reader;
                            period,
                            scenario,
                            subscenario = subscenario,
                            bid_segment = bid_segment,
                        )
                    else
                        Quiver.goto!(vr_generation_reader; period, scenario, bid_segment = bid_segment)
                    end
                    segment_generation = vr_generation_reader.data
                    if is_double_settlement_ex_post
                        Quiver.goto!(vr_generation_ex_ante_reader; period, scenario, bid_segment = bid_segment)
                        segment_generation = segment_generation - vr_generation_ex_ante_reader.data
                    end
                    vr_ao_generation = vr_ao_generation + segment_generation
                end

                revenue = zeros(number_of_pairs)
                idx = 0
                for vr in index_of_elements(inputs, VirtualReservoir)
                    for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
                        idx += 1
                        revenue[idx] = vr_ao_generation[idx] * price[vr] / MW_to_GW()
                    end
                end
                @assert idx == length(vr_ao_generation)

                if output_has_subscenario
                    Quiver.write!(writer, revenue; period, scenario, subscenario = subscenario)
                else
                    Quiver.write!(writer, revenue; period, scenario)
                end
            end
        end
    end

    Quiver.close!(writer)
    Quiver.close!(vr_generation_reader)
    Quiver.close!(vr_marginal_cost_reader)
    if is_double_settlement_ex_post
        Quiver.close!(vr_generation_ex_ante_reader)
    end

    return joinpath(post_processing_path(inputs), output_name)
end

function inflow_shareholder_residual_revenue(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions;
    physical_variables_suffix::String,
    commercial_variables_suffix::String,
    output_suffix::String,
    is_double_settlement_ex_post::Bool,
    ex_ante_physical_suffix::String,
    output_has_subscenario::Bool,
)
    outputs_dir = output_path(inputs)
    output_name = "virtual_reservoir_inflow_shareholder_residual_revenue" * output_suffix

    load_marginal_cost_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(outputs_dir, "load_marginal_cost" * commercial_variables_suffix),
    )
    hydro_generation_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(outputs_dir, "hydro_generation" * physical_variables_suffix),
    )
    turbinable_spillage_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(outputs_dir, "hydro_turbinable_spilled_energy" * physical_variables_suffix),
    )
    vr_accepted_offer_revenue_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(post_processing_path(inputs), "virtual_reservoir_accepted_offer_revenue" * output_suffix),
    )

    if is_double_settlement_ex_post
        hydro_generation_ex_ante_reader = open_time_series_output(
            inputs,
            model_outputs_time_serie,
            joinpath(outputs_dir, "hydro_generation" * ex_ante_physical_suffix),
        )
        turbinable_spillage_ex_ante_reader = open_time_series_output(
            inputs,
            model_outputs_time_serie,
            joinpath(outputs_dir, "hydro_turbinable_spilled_energy" * ex_ante_physical_suffix),
        )
    end

    dimensions = output_has_subscenario ? ["period", "scenario", "subscenario"] : ["period", "scenario"]
    initialize!(
        QuiverOutput,
        outputs_post_processing;
        inputs,
        output_name = output_name,
        dimensions = dimensions,
        unit = "\$",
        labels = labels_for_output_by_pair_of_agents(
            inputs,
            run_time_options,
            inputs.collections.virtual_reservoir,
            inputs.collections.asset_owner;
            index_getter = virtual_reservoir_asset_owner_indices,
        ),
        run_time_options,
        dir_path = post_processing_path(inputs),
    )

    writer = outputs_post_processing.outputs[output_name].writer

    num_periods = is_single_period(inputs) ? 1 : number_of_periods(inputs)
    for period in 1:num_periods
        for scenario in scenarios(inputs)
            for subscenario in subscenarios(inputs, run_time_options)
                if has_subscenario(vr_accepted_offer_revenue_reader)
                    Quiver.goto!(vr_accepted_offer_revenue_reader; period, scenario, subscenario = subscenario)
                else
                    Quiver.goto!(vr_accepted_offer_revenue_reader; period, scenario)
                end
                vr_accepted_offer_revenue = vr_accepted_offer_revenue_reader.data

                accepted_offer_revenue = zeros(number_of_elements(inputs, VirtualReservoir))
                idx = 0
                for vr in index_of_elements(inputs, VirtualReservoir)
                    for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
                        idx += 1
                        accepted_offer_revenue[vr] += vr_accepted_offer_revenue[idx]
                    end
                end

                physical_generation_revenue = zeros(number_of_elements(inputs, VirtualReservoir))
                om_cost = zeros(number_of_elements(inputs, VirtualReservoir))

                for subperiod in subperiods(inputs)
                    if has_subscenario(hydro_generation_reader)
                        Quiver.goto!(
                            hydro_generation_reader;
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                        )
                        Quiver.goto!(
                            turbinable_spillage_reader;
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                        )
                    else
                        Quiver.goto!(hydro_generation_reader; period, scenario, subperiod = subperiod)
                        Quiver.goto!(turbinable_spillage_reader; period, scenario, subperiod = subperiod)
                    end

                    if has_subscenario(load_marginal_cost_reader)
                        Quiver.goto!(
                            load_marginal_cost_reader;
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                        )
                    else
                        Quiver.goto!(load_marginal_cost_reader; period, scenario, subperiod = subperiod)
                    end

                    load_price = load_marginal_cost_reader.data
                    hydro_generation = hydro_generation_reader.data
                    spilled_energy = turbinable_spillage_reader.data

                    if is_double_settlement_ex_post
                        Quiver.goto!(hydro_generation_ex_ante_reader; period, scenario, subperiod = subperiod)
                        Quiver.goto!(turbinable_spillage_ex_ante_reader; period, scenario, subperiod = subperiod)

                        hydro_generation = hydro_generation_reader.data - hydro_generation_ex_ante_reader.data
                        spilled_energy = turbinable_spillage_reader.data - turbinable_spillage_ex_ante_reader.data
                    end

                    for vr in index_of_elements(inputs, VirtualReservoir)
                        for h in virtual_reservoir_asset_owner_indices(inputs, vr)
                            if network_representation(inputs, commercial_variables_suffix) ==
                               Configurations_NetworkRepresentation.ZONAL
                                load_price_index = hydro_unit_zone_index(inputs, h)
                            elseif network_representation(inputs, commercial_variables_suffix) ==
                                   Configurations_NetworkRepresentation.NODAL
                                load_price_index = hydro_unit_bus_index(inputs, h)
                            end
                            physical_generation_revenue[vr] +=
                                (hydro_generation[h] + spilled_energy[h]) / MW_to_GW() * load_price[load_price_index]
                            om_cost[vr] += hydro_generation[h] / MW_to_GW() * hydro_unit_om_cost(inputs, h)
                        end
                    end
                end

                vr_total_revenue = physical_generation_revenue .- accepted_offer_revenue .- om_cost
                number_of_pairs = sum(length.(virtual_reservoir_asset_owner_indices(inputs)))
                vr_ao_revenue = zeros(number_of_pairs)
                idx = 0
                for vr in index_of_elements(inputs, VirtualReservoir)
                    sum_of_allocations = sum(virtual_reservoir_asset_owners_inflow_allocation(inputs, vr))
                    for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
                        idx += 1
                        vr_ao_revenue[idx] =
                            vr_total_revenue[vr] * virtual_reservoir_asset_owners_inflow_allocation(inputs, vr, ao) /
                            sum_of_allocations
                    end
                end

                if output_has_subscenario
                    Quiver.write!(writer, vr_ao_revenue; period, scenario, subscenario = subscenario)
                else
                    Quiver.write!(writer, vr_ao_revenue; period, scenario)
                end
            end
        end
    end

    Quiver.close!(writer)
    Quiver.close!(load_marginal_cost_reader)
    Quiver.close!(hydro_generation_reader)
    Quiver.close!(turbinable_spillage_reader)
    Quiver.close!(vr_accepted_offer_revenue_reader)
    if is_double_settlement_ex_post
        Quiver.close!(hydro_generation_ex_ante_reader)
        Quiver.close!(turbinable_spillage_ex_ante_reader)
    end

    return joinpath(post_processing_path(inputs), output_name)
end

function spilled_responsibility_revenue(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions;
    physical_variables_suffix::String,
    commercial_variables_suffix::String,
    output_suffix::String,
    is_double_settlement_ex_post::Bool,
    ex_ante_physical_suffix::String,
    output_has_subscenario::Bool,
)
    outputs_dir = output_path(inputs)
    output_name = "virtual_reservoir_spilled_responsibility_revenue" * output_suffix

    load_marginal_cost_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(outputs_dir, "load_marginal_cost" * commercial_variables_suffix),
    )
    spilled_energy_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(outputs_dir, "hydro_turbinable_spilled_energy" * physical_variables_suffix),
    )
    vr_energy_account_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(outputs_dir, "virtual_reservoir_final_energy_account" * physical_variables_suffix),
    )

    if is_double_settlement_ex_post
        spilled_energy_ex_ante_reader = open_time_series_output(
            inputs,
            model_outputs_time_serie,
            joinpath(outputs_dir, "hydro_turbinable_spilled_energy" * ex_ante_physical_suffix),
        )
        vr_energy_account_ex_ante_reader = open_time_series_output(
            inputs,
            model_outputs_time_serie,
            joinpath(outputs_dir, "virtual_reservoir_final_energy_account" * ex_ante_physical_suffix),
        )
    end

    dimensions = output_has_subscenario ? ["period", "scenario", "subscenario"] : ["period", "scenario"]
    initialize!(
        QuiverOutput,
        outputs_post_processing;
        inputs,
        output_name = output_name,
        dimensions = dimensions,
        unit = "\$",
        labels = labels_for_output_by_pair_of_agents(
            inputs,
            run_time_options,
            inputs.collections.virtual_reservoir,
            inputs.collections.asset_owner;
            index_getter = virtual_reservoir_asset_owner_indices,
        ),
        run_time_options,
        dir_path = post_processing_path(inputs),
    )

    writer = outputs_post_processing.outputs[output_name].writer

    num_periods = is_single_period(inputs) ? 1 : number_of_periods(inputs)
    for period in 1:num_periods
        for scenario in scenarios(inputs)
            for subscenario in subscenarios(inputs, run_time_options)
                if has_subscenario(vr_energy_account_reader)
                    Quiver.goto!(vr_energy_account_reader; period, scenario, subscenario = subscenario)
                else
                    Quiver.goto!(vr_energy_account_reader; period, scenario)
                end
                vr_energy_account = vr_energy_account_reader.data

                if is_double_settlement_ex_post
                    Quiver.goto!(vr_energy_account_ex_ante_reader; period, scenario)
                    vr_energy_account = vr_energy_account_reader.data - vr_energy_account_ex_ante_reader.data
                end
                vr_energy_account = vr_energy_account / MW_to_GW()

                vr_spilled_energy_cost = zeros(number_of_elements(inputs, VirtualReservoir))
                for subperiod in subperiods(inputs)
                    if has_subscenario(spilled_energy_reader)
                        Quiver.goto!(
                            spilled_energy_reader;
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                        )
                    else
                        Quiver.goto!(spilled_energy_reader; period, scenario, subperiod = subperiod)
                    end
                    spilled_energy = spilled_energy_reader.data
                    if is_double_settlement_ex_post
                        Quiver.goto!(spilled_energy_ex_ante_reader; period, scenario, subperiod = subperiod)
                        spilled_energy = spilled_energy_reader.data - spilled_energy_ex_ante_reader.data
                    end

                    if has_subscenario(load_marginal_cost_reader)
                        Quiver.goto!(
                            load_marginal_cost_reader;
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                        )
                    else
                        Quiver.goto!(load_marginal_cost_reader; period, scenario, subperiod = subperiod)
                    end
                    price = load_marginal_cost_reader.data

                    for vr in index_of_elements(inputs, VirtualReservoir)
                        for h in virtual_reservoir_asset_owner_indices(inputs, vr)
                            if network_representation(inputs, commercial_variables_suffix) ==
                               Configurations_NetworkRepresentation.ZONAL
                                load_price_index = hydro_unit_zone_index(inputs, h)
                            elseif network_representation(inputs, commercial_variables_suffix) ==
                                   Configurations_NetworkRepresentation.NODAL
                                load_price_index = hydro_unit_bus_index(inputs, h)
                            end
                            vr_spilled_energy_cost[vr] += spilled_energy[h] / MW_to_GW() * price[load_price_index]
                        end
                    end
                end

                number_of_pairs = sum(length.(virtual_reservoir_asset_owner_indices(inputs)))
                vr_ao_spilled_energy_cost = zeros(number_of_pairs)
                idx = 0
                for vr in index_of_elements(inputs, VirtualReservoir)
                    first_pair = idx + 1
                    last_pair = idx + length(virtual_reservoir_asset_owner_indices(inputs, vr))
                    total_energy_account = sum(vr_energy_account[first_pair:last_pair])
                    for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
                        idx += 1
                        if total_energy_account == 0.0
                            if vr_spilled_energy_cost[vr] > 0.0
                                @warn "Virtual reservoir $vr spilled energy cost is positive, but the total energy account is zero. The cost will be allocated according to inflow allocation instead."
                                vr_ao_spilled_energy_cost[idx] =
                                    -vr_spilled_energy_cost[vr] *
                                    virtual_reservoir_asset_owners_inflow_allocation(inputs, vr, ao)
                            else
                                vr_ao_spilled_energy_cost[idx] = 0.0
                            end
                        else
                            vr_ao_spilled_energy_cost[idx] =
                                -vr_spilled_energy_cost[vr] * vr_energy_account[idx] / total_energy_account
                        end
                    end
                end
                @assert idx == length(vr_ao_spilled_energy_cost)

                if output_has_subscenario
                    Quiver.write!(writer, vr_ao_spilled_energy_cost; period, scenario, subscenario = subscenario)
                else
                    Quiver.write!(writer, vr_ao_spilled_energy_cost; period, scenario)
                end
            end
        end
    end

    Quiver.close!(writer)
    Quiver.close!(spilled_energy_reader)
    Quiver.close!(load_marginal_cost_reader)
    Quiver.close!(vr_energy_account_reader)
    if is_double_settlement_ex_post
        Quiver.close!(spilled_energy_ex_ante_reader)
        Quiver.close!(vr_energy_account_ex_ante_reader)
    end

    return joinpath(post_processing_path(inputs), output_name)
end

function post_processing_virtual_reservoirs(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions;
    physical_variables_suffix::String,
    commercial_variables_suffix::String,
    output_suffix::String,
    is_double_settlement_ex_post::Bool = false,
    ex_ante_physical_suffix::String = "",
    output_has_subscenario::Bool = true,
)
    @assert !(is_double_settlement_ex_post && isempty(ex_ante_physical_suffix))
    accepted_offer_revenue_file = accepted_offer_revenue(
        inputs,
        outputs_post_processing,
        model_outputs_time_serie,
        run_time_options;
        physical_variables_suffix,
        commercial_variables_suffix,
        output_suffix,
        is_double_settlement_ex_post,
        ex_ante_physical_suffix,
        output_has_subscenario,
    )
    inflow_shareholder_residual_revenue_file = inflow_shareholder_residual_revenue(
        inputs,
        outputs_post_processing,
        model_outputs_time_serie,
        run_time_options;
        physical_variables_suffix,
        commercial_variables_suffix,
        output_suffix,
        is_double_settlement_ex_post,
        ex_ante_physical_suffix,
        output_has_subscenario,
    )
    spilled_responsibility_revenue_file = spilled_responsibility_revenue(
        inputs,
        outputs_post_processing,
        model_outputs_time_serie,
        run_time_options;
        physical_variables_suffix,
        commercial_variables_suffix,
        output_suffix,
        is_double_settlement_ex_post,
        ex_ante_physical_suffix,
        output_has_subscenario,
    )

    total_revenue_file = joinpath(post_processing_path(inputs), "virtual_reservoir_total_revenue" * output_suffix)
    Quiver.apply_expression(
        total_revenue_file,
        [accepted_offer_revenue_file, inflow_shareholder_residual_revenue_file, spilled_responsibility_revenue_file],
        +,
        Quiver.csv,
    )

    return total_revenue_file
end

function post_processing_virtual_reservoirs_double_settlement(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions;
    ex_post_physical_suffix::String,
    ex_ante_physical_suffix::String,
    ex_post_commercial_suffix::String,
    ex_ante_commercial_suffix::String,
)
    ex_ante_revenue_file = post_processing_virtual_reservoirs(
        inputs,
        outputs_post_processing,
        model_outputs_time_serie,
        run_time_options;
        physical_variables_suffix = ex_ante_physical_suffix,
        commercial_variables_suffix = ex_ante_commercial_suffix,
        output_suffix = "_ex_ante",
        output_has_subscenario = false,
    )

    ex_post_revenue_file = post_processing_virtual_reservoirs(
        inputs,
        outputs_post_processing,
        model_outputs_time_serie,
        run_time_options;
        physical_variables_suffix = ex_post_physical_suffix,
        commercial_variables_suffix = ex_post_commercial_suffix,
        output_suffix = "_ex_post",
        is_double_settlement_ex_post = true,
        ex_ante_physical_suffix = ex_ante_physical_suffix,
    )

    treated_ex_ante_revenue_file =
        create_temporary_file_with_subscenario_dimension(inputs, model_outputs_time_serie, ex_ante_revenue_file)

    revenue_file = joinpath(post_processing_path(inputs), "virtual_reservoir_total_revenue")

    Quiver.apply_expression(
        revenue_file,
        [treated_ex_ante_revenue_file, ex_post_revenue_file],
        +,
        Quiver.csv,
    )

    return nothing
end
