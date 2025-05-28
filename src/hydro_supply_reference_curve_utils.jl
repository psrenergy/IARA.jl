#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function initialize_reference_curve_outputs(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    outputs = Outputs()

    add_custom_recorder_to_query_from_subproblem_result!(
        outputs,
        :load_marginal_cost,
        constraint_dual_recorder(:load_balance),
    )

    add_symbol_to_query_from_subproblem_result!(
        outputs,
        :hydro_generation,
    )

    # Outputs
    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_reference_curve_quantity",
        dimensions = ["period", "reference_curve_segment", "scenario"],
        unit = "GWh",
        labels = labels_for_output_by_pair_of_agents(
            inputs,
            run_time_options,
            inputs.collections.virtual_reservoir,
            inputs.collections.asset_owner;
            index_getter = virtual_reservoir_asset_owner_indices,
        ),
        run_time_options,
    )
    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_reference_curve_price",
        dimensions = ["period", "reference_curve_segment", "scenario"],
        unit = "\$/MWh",
        labels = labels_for_output_by_pair_of_agents(
            inputs,
            run_time_options,
            inputs.collections.virtual_reservoir,
            inputs.collections.asset_owner;
            index_getter = virtual_reservoir_asset_owner_indices,
        ),
        run_time_options,
    )

    return outputs
end

function post_process_reference_curve_outputs(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::IARA.SimulationResultsFromPeriodScenario,
)
    # Sizes and indexes
    existing_hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir; run_time_options)
    asset_owners = index_of_elements(inputs, AssetOwner; run_time_options)
    number_of_hydro_units = length(existing_hydro_units)
    number_of_virtual_reservoirs = length(virtual_reservoirs)
    number_of_asset_owners = length(asset_owners)

    # Simulation results
    load_marginal_cost = simulation_results.data[:load_marginal_cost].data
    hydro_generation = simulation_results.data[:hydro_generation].data

    # Map load marginal cost to hydro units
    hydro_load_marginal_cost = zeros(number_of_subperiods(inputs), number_of_hydro_units)
    for h in existing_hydro_units, subperiod in 1:number_of_subperiods(inputs)
        hydro_load_marginal_cost[subperiod, h] =
            (load_marginal_cost[subperiod, hydro_unit_bus_index(inputs, h)] / money_to_thousand_money()) -
            hydro_unit_om_cost(inputs, h)
    end

    # Aggregate subperiods
    hydro_load_marginal_cost_agg = zeros(number_of_hydro_units)
    hydro_generation_agg = zeros(number_of_hydro_units)
    for h in existing_hydro_units
        hydro_generation_agg[h] = sum(hydro_generation[:, h])
        hydro_load_marginal_cost_agg[h] = mean(hydro_load_marginal_cost[:, h])
    end

    # Aggregate for virtual reservoirs
    virtual_reservoir_generation = zeros(number_of_virtual_reservoirs)
    virtual_reservoir_marginal_cost = zeros(number_of_virtual_reservoirs)
    for vr in virtual_reservoirs
        virtual_reservoir_generation[vr] =
            sum(hydro_generation_agg[virtual_reservoir_hydro_unit_indices(inputs, vr)])
        virtual_reservoir_marginal_cost[vr] =
            mean(hydro_load_marginal_cost_agg[virtual_reservoir_hydro_unit_indices(inputs, vr)])
    end

    # Disaggregate for asset owners
    vr_ao_generation = zeros(number_of_virtual_reservoirs, number_of_asset_owners)
    vr_ao_marginal_cost = zeros(number_of_virtual_reservoirs, number_of_asset_owners)
    for vr in virtual_reservoirs
        vr_asset_owners = virtual_reservoir_asset_owner_indices(inputs, vr)
        for (ao_idx, ao) in enumerate(vr_asset_owners)
            vr_ao_generation[vr, ao] =
                virtual_reservoir_generation[vr] *
                virtual_reservoir_asset_owners_inflow_allocation(inputs, vr)[ao_idx]
            vr_ao_marginal_cost[vr, ao] = virtual_reservoir_marginal_cost[vr]
        end
    end

    treated_vr_ao_generation = treat_output_for_writing_by_pairs_of_agents(
        inputs,
        run_time_options,
        vr_ao_generation,
        inputs.collections.virtual_reservoir,
        inputs.collections.asset_owner;
        index_getter = virtual_reservoir_asset_owner_indices,
    )
    treated_vr_ao_marginal_cost = treat_output_for_writing_by_pairs_of_agents(
        inputs,
        run_time_options,
        vr_ao_marginal_cost,
        inputs.collections.virtual_reservoir,
        inputs.collections.asset_owner;
        index_getter = virtual_reservoir_asset_owner_indices,
    )

    quantity = treated_vr_ao_generation
    price = treated_vr_ao_marginal_cost
    return quantity, price
end

function write_reference_curve_outputs(
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    simulation_results::IARA.SimulationResultsFromPeriodScenario;
    period::Int,
    reference_curve_segment::Int,
    scenario::Int,
)
    quantity, price = post_process_reference_curve_outputs(
        inputs,
        run_time_options,
        simulation_results,
    )

    write_reference_curve_output!(
        outputs,
        inputs,
        run_time_options,
        "hydro_reference_curve_quantity",
        quantity;
        period,
        reference_curve_segment,
        scenario,
        multiply_by = MW_to_GW(),
    )

    write_reference_curve_output!(
        outputs,
        inputs,
        run_time_options,
        "hydro_reference_curve_price",
        price;
        period,
        reference_curve_segment,
        scenario,
    )

    return nothing
end
