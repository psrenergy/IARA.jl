#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function water_to_energy_factors(inputs::AbstractInputs, hydro_units_indices::Vector{Int})
    # Converts hm3 to MWh
    water_to_energy_factors = [NaN for h in 1:maximum(index_of_elements(inputs, HydroUnit))]
    ready_for_calculations_indices = [
        h for h in hydro_units_indices if
        is_null(hydro_unit_turbine_to(inputs, h)) || !(hydro_unit_turbine_to(inputs, h) in hydro_units_indices)
    ]
    while !isempty(ready_for_calculations_indices)
        h = popfirst!(ready_for_calculations_indices)
        h_downstream = hydro_unit_turbine_to(inputs, h)
        water_to_energy_factors[h] = if is_null(h_downstream) || !(h_downstream in hydro_units_indices)
            hydro_unit_production_factor(inputs, h) / m3_per_second_to_hm3_per_hour()
        else
            hydro_unit_production_factor(inputs, h) / m3_per_second_to_hm3_per_hour() +
            water_to_energy_factors[h_downstream]
        end
        hydro_units_now_ready =
            [h_upstream for h_upstream in hydro_units_indices if hydro_unit_turbine_to(inputs, h_upstream) == h]
        append!(ready_for_calculations_indices, hydro_units_now_ready)
    end
    @assert all((!isnan).(water_to_energy_factors[hydro_units_indices]))
    return water_to_energy_factors
end

function order_to_spill_excess_of_inflow(inputs::AbstractInputs)
    hydro_units = index_of_elements(inputs, HydroUnit)
    remaining_indices = copy(hydro_units)
    ordered_indices = []
    while !isempty(remaining_indices)
        ready_for_calculations_indices =
            [h for h in remaining_indices if !(h in hydro_unit_spill_to(inputs)[remaining_indices])]
        append!(ordered_indices, ready_for_calculations_indices)
        remaining_indices = setdiff(remaining_indices, ready_for_calculations_indices)
    end
    return ordered_indices
end

function energy_from_inflows(
    inputs::AbstractInputs,
    inflow_series::Matrix{Float64}, # m3/s
    volume::Vector{Float64}, # hm3
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    hydro_units_in_original_order = index_of_elements(inputs, HydroUnit)
    hydro_units_in_cascade_order = order_to_spill_excess_of_inflow(inputs)

    inflow_as_volume = zeros(length(hydro_units_in_original_order), number_of_subperiods(inputs))
    for b in subperiods(inputs)
        for h in hydro_units_in_original_order
            inflow_as_volume[h, b] =
                inflow_series[hydro_unit_gauging_station_index(inputs, h), b] * m3_per_second_to_hm3_per_hour() *
                subperiod_duration_in_hours(inputs, b) # hm3
        end
    end

    hydro_unit_additional_energy = zeros(length(hydro_units_in_cascade_order))
    total_inflow_as_volume = dropdims(sum(inflow_as_volume; dims = 2); dims = 2)

    for h in hydro_units_in_cascade_order
        max_turbining = [
            hydro_unit_max_available_turbining(inputs, h) * m3_per_second_to_hm3_per_hour() *
            subperiod_duration_in_hours(inputs, b) # hm3
            for b in subperiods(inputs)
        ]
        total_max_turbining = sum(max_turbining)

        total_spillage =
            max(volume[h] + total_inflow_as_volume[h] - (hydro_unit_max_volume(inputs, h) + total_max_turbining), 0) # hm3

        vr = hydro_unit_virtual_reservoir_index(inputs, h)
        if !is_null(vr)
            hydro_unit_additional_energy[h] =
                (total_inflow_as_volume[h] - total_spillage) * virtual_reservoir_water_to_energy_factors(inputs, vr, h)
        end

        h_downstream = hydro_unit_spill_to(inputs, h)
        if !is_null(h_downstream)
            total_inflow_as_volume[h_downstream] += total_spillage
        end
    end

    vr_additional_energy = zeros(length(virtual_reservoirs))
    for vr in virtual_reservoirs
        for h in virtual_reservoir_hydro_unit_indices(inputs, vr)
            vr_additional_energy[vr] += hydro_unit_additional_energy[h]
        end
    end

    return vr_additional_energy
end

function calculate_turbinable_spilled_energy(
    inputs::AbstractInputs,
    inflow_series::Matrix{Float64}, # m3/s
    turbining::AbstractArray{Float64, 2}, # hm3
    spillage::AbstractArray{Float64, 2}, # hm3
    volume::AbstractArray{Float64, 2}, # hm3
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    hydro_units_in_cascade_order = order_to_spill_excess_of_inflow(inputs)

    inflow_as_volume = zeros(length(hydro_units_in_cascade_order), number_of_subperiods(inputs))
    for b in subperiods(inputs)
        for h in hydro_units_in_cascade_order
            inflow_as_volume[h, b] =
                inflow_series[hydro_unit_gauging_station_index(inputs, h), b] * m3_per_second_to_hm3_per_hour() *
                subperiod_duration_in_hours(inputs, b) # hm3
        end
    end

    hydro_unit_turbinable_spilled_energy = zeros(number_of_subperiods(inputs), length(hydro_units_in_cascade_order))

    for b in subperiods(inputs)
        for h in hydro_units_in_cascade_order
            max_turbining =
                hydro_unit_max_available_turbining(inputs, h) * m3_per_second_to_hm3_per_hour() *
                subperiod_duration_in_hours(inputs, b) # hm3

            available_volume = hydro_unit_max_volume(inputs, h) - volume[b, h]

            vr = hydro_unit_virtual_reservoir_index(inputs, h)
            if !is_null(vr)
                hydro_unit_turbinable_spilled_energy[b, h] =
                    virtual_reservoir_water_to_energy_factors(inputs, vr, h) *
                    (spillage[b, h] - max(0, inflow_as_volume[h, b] - max_turbining - available_volume))
            end
        end
    end

    return hydro_unit_turbinable_spilled_energy
end

function fill_water_to_energy_factors!(inputs::AbstractInputs, vr::Int)
    hydro_units = virtual_reservoir_hydro_unit_indices(inputs, vr)
    inputs.collections.virtual_reservoir.water_to_energy_factors[vr] .= water_to_energy_factors(inputs, hydro_units)
    return nothing
end

function fill_initial_energy_account!(inputs::AbstractInputs, vr::Int)
    hydro_units = virtual_reservoir_hydro_unit_indices(inputs, vr)
    total_energy_account = sum(
        hydro_unit_initial_volume(inputs, h) * virtual_reservoir_water_to_energy_factors(inputs, vr, h) for
        h in hydro_units
    )
    inputs.collections.virtual_reservoir.initial_energy_account[vr] =
        [NaN for ao in 1:length(virtual_reservoir_asset_owner_indices(inputs, vr))]
    for (i, ao) in enumerate(virtual_reservoir_asset_owner_indices(inputs, vr))
        inputs.collections.virtual_reservoir.initial_energy_account[vr][i] =
            total_energy_account * virtual_reservoir_asset_owners_initial_energy_account_share(inputs, vr, ao)
    end
    return nothing
end

function post_process_virtual_reservoirs!(
    inputs::AbstractInputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    outputs::Outputs,
    period::Int,
    scenario::Int,
    subscenario::Int,
)
    energy_account, hydro_spilled_energy = calculate_energy_account_and_spilled_energy!(
        inputs,
        run_time_options,
        simulation_results,
        period,
        scenario,
        subscenario,
    )

    if run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_POST_PHYSICAL &&
       subscenario ==
       subscenario_that_propagates_state_variables_to_next_period(inputs, run_time_options; period, scenario)
        # The result that goes to the next period
        serialize_virtual_reservoir_energy_account(
            inputs,
            run_time_options,
            energy_account,
            period,
            scenario,
        )
    end

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "hydro_turbinable_spilled_energy",
        hydro_spilled_energy;
        period = period,
        scenario = scenario,
        subscenario = subscenario,
        multiply_by = MW_to_GW(),
    )

    treated_energy_account = treat_energy_account_for_writing_by_pairs_of_agents(
        inputs,
        run_time_options,
        energy_account,
    )

    write_output_without_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "virtual_reservoir_final_energy_account",
        treated_energy_account;
        period = period,
        scenario = scenario,
        subscenario = subscenario,
        multiply_by = MW_to_GW(),
    )
    return nothing
end

function calculate_energy_account_and_spilled_energy!(
    inputs::AbstractInputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
)
    hydro_units = index_of_elements(inputs, HydroUnit)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    hydro_volume = simulation_results.data[:hydro_volume] # hm3
    virtual_reservoir_generation = simulation_results.data[:virtual_reservoir_generation] # MWh
    hydro_spillage = simulation_results.data[:hydro_spillage] # hm3
    hydro_turbining = simulation_results.data[:hydro_turbining] # hm3
    volume_by_subperiod = simulation_results.data[:hydro_volume] # hm3

    volume_at_beginning_of_period = hydro_volume_from_previous_period(inputs, run_time_options, period, scenario) # hm3
    energy_account_at_beginning_of_period =
        virtual_reservoir_energy_account_from_previous_period(inputs, period, scenario)

    inflow_series = time_series_inflow(inputs, run_time_options; subscenario) # m3/s

    vr_energy_arrival =
        energy_from_inflows(inputs, inflow_series, volume_at_beginning_of_period)
    hydro_spilled_energy = calculate_turbinable_spilled_energy(
        inputs,
        inflow_series,
        hydro_turbining,
        hydro_spillage,
        volume_by_subperiod,
    ) # MWh

    virtual_reservoir_post_processed_energy_account =
        [zeros(length(virtual_reservoir_asset_owner_indices(inputs, vr))) for vr in virtual_reservoirs]
    for vr in virtual_reservoirs
        pre_processed_energy_account = zeros(length(virtual_reservoir_asset_owner_indices(inputs, vr)))

        for (i, ao) in enumerate(virtual_reservoir_asset_owner_indices(inputs, vr))
            pre_processed_energy_account[i] =
                energy_account_at_beginning_of_period[vr][i] +
                vr_energy_arrival[vr] * virtual_reservoir_asset_owners_inflow_allocation(inputs, vr, ao) -
                sum(virtual_reservoir_generation[vr, ao, :]) # sum over bid_segment dimension
        end
        total_actual_energy_account = sum(
            hydro_volume[end, h] * virtual_reservoir_water_to_energy_factors(inputs, vr, h) for
            h in virtual_reservoir_hydro_unit_indices(inputs, vr)
        )
        if sum(pre_processed_energy_account) == 0
            if total_actual_energy_account == 0
                virtual_reservoir_post_processed_energy_account[vr] .= 0.0
            else
                @warn("The total actual energy account is not zero, but the pre-processed energy account is zero.")
                virtual_reservoir_post_processed_energy_account[vr] .=
                    virtual_reservoir_asset_owners_inflow_allocation(inputs, vr) *
                    total_actual_energy_account
            end
        else
            correction_factor = total_actual_energy_account / sum(pre_processed_energy_account)
            virtual_reservoir_post_processed_energy_account[vr] .= pre_processed_energy_account * correction_factor
        end
    end

    return virtual_reservoir_post_processed_energy_account, hydro_spilled_energy
end

function virtual_reservoir_energy_account_from_previous_period(inputs::AbstractInputs, period::Int, scenario::Int)
    if period == 1
        return inputs.collections.virtual_reservoir.initial_energy_account
    else
        return read_serialized_virtual_reservoir_energy_account(inputs, period - 1, scenario)
    end
end

function virtual_reservoir_stored_energy(
    inputs::AbstractInputs,
    run_time_options::RunTimeOptions,
    period::Int,
    scenario::Int,
    subscenario::Int,
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    # Calculate total stored energy
    inflow_series = time_series_inflow(inputs, run_time_options; subscenario)
    virtual_reservoir_energy_account_at_beginning_of_period =
        virtual_reservoir_energy_account_from_previous_period(inputs, period, scenario)
    volume_at_beginning_of_period = hydro_volume_from_previous_period(inputs, run_time_options, period, scenario)

    vr_energy_arrival = energy_from_inflows(inputs, inflow_series, volume_at_beginning_of_period)
    energy_accounts = [
        sum(virtual_reservoir_energy_account_at_beginning_of_period[vr]) + vr_energy_arrival[vr]
        for vr in virtual_reservoirs
    ]

    return energy_accounts
end

"""
    initialize_virtual_reservoir_inflow_energy_arrival_output(
        outputs::Outputs,
        inputs::Inputs,
        run_time_options::RunTimeOptions,
    )

Initialize the output file for virtual reservoir inflow energy arrival in the next period.
This output is used in single_period_heuristic_bid mode.

When read_ex_post_inflow_file is true, the output will have an additional subscenario dimension.
"""
function initialize_virtual_reservoir_inflow_energy_arrival_output(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    labels = labels_for_output_by_pair_of_agents(
        inputs,
        run_time_options,
        inputs.collections.virtual_reservoir,
        inputs.collections.asset_owner;
        index_getter = virtual_reservoir_asset_owner_indices,
    )

    # If we have ex-post inflow files, we need to include subscenarios in the output
    if read_ex_post_inflow_file(inputs) &&
       run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_POST_PHYSICAL
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            run_time_options,
            output_name = "virtual_reservoir_next_period_inflow_energy_arrival",
            dimensions = ["period", "scenario"],
            unit = "GWh",
            labels,
        )
    end

    if read_ex_ante_inflow_file(inputs) &&
       run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_ANTE_PHYSICAL
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            run_time_options,
            output_name = "virtual_reservoir_next_period_inflow_energy_arrival",
            dimensions = ["period", "scenario"],
            unit = "GWh",
            labels,
        )
    end

    return nothing
end

"""
    treat_energy_arrival_by_pairs_of_agents(
        inputs::AbstractInputs,
        run_time_options::RunTimeOptions,
        vr_energy_arrival::Vector{Float64},
    )

Distribute the virtual reservoir energy arrival across asset owners based on their inflow allocation.
"""
function treat_energy_arrival_by_pairs_of_agents(
    inputs::AbstractInputs,
    run_time_options::RunTimeOptions,
    vr_energy_arrival::Vector{Float64},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    # Count total number of (vr, ao) pairs
    total_pairs = sum(
        length(virtual_reservoir_asset_owner_indices(inputs, vr)) for vr in virtual_reservoirs
    )

    treated_energy_arrival = zeros(total_pairs)
    pair_idx = 1

    for vr in virtual_reservoirs
        for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
            treated_energy_arrival[pair_idx] =
                vr_energy_arrival[vr] * virtual_reservoir_asset_owners_inflow_allocation(inputs, vr, ao)
            pair_idx += 1
        end
    end

    return treated_energy_arrival
end

"""
    write_virtual_reservoir_next_period_inflow_energy_arrival(
        outputs::Outputs,
        inputs::Inputs,
        run_time_options::RunTimeOptions,
        period::Int,
        scenario::Int,
        subscenario::Int,
    )

Write the virtual reservoir inflow energy arrival for the NEXT period.
This is used in single_period_market_clearing to show what energy will arrive in the next period.
The calculation uses the volume at the END of the current period (from the clearing results)
and the inflow series for the next period.

For period 1, we use the volumes directly from simulation_results (if provided).
For period > 1, we read from the serialized file using hydro_volume_from_previous_period.

Note: The inflow varies by scenario for ONLY_EX_ANTE, and by scenario and subscenario
for ONLY_EX_POST or EX_ANTE_AND_EX_POST.
"""
function write_virtual_reservoir_next_period_inflow_energy_arrival(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    period::Int,
    scenario::Int,
    subscenario::Int;
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    # Calculate next period (for the last period, we use the same period)
    next_period = min(period + 1, number_of_periods(inputs))

    # Get volume at end of current period (beginning of next period)
    volume_at_end_of_period = hydro_volume_from_previous_period(
        inputs,
        run_time_options,
        next_period,
        scenario;
        output_path = output_path(inputs, run_time_options),
    )

    # Update time series to next period to get the correct inflow
    update_time_series_from_db!(inputs, next_period)

    # Get inflow series for the next period with this scenario/subscenario
    inflow_series = time_series_inflow(inputs, run_time_options; subscenario)

    # Restore time series to current period
    update_time_series_from_db!(inputs, period)

    # Calculate energy arrival from inflows for the next period
    vr_energy_arrival = energy_from_inflows(inputs, inflow_series, volume_at_end_of_period)

    # Prepare output by asset owner
    treated_energy_arrival = treat_energy_arrival_by_pairs_of_agents(
        inputs,
        run_time_options,
        vr_energy_arrival,
    )

    # Quiver file dimensions are always 1:N, so we need to set the period to 1
    if is_single_period(inputs)
        period = 1
    end

    output = outputs.outputs["virtual_reservoir_next_period_inflow_energy_arrival"*run_time_file_suffixes(
        inputs,
        run_time_options,
    )]

    # Write with subscenario dimension if we have ex-post inflow files
    if read_ex_post_inflow_file(inputs)
        Quiver.write!(
            output.writer,
            round_output(treated_energy_arrival * MW_to_GW());
            period,
            scenario,
            subscenario,
        )
    else
        Quiver.write!(
            output.writer,
            round_output(treated_energy_arrival * MW_to_GW());
            period,
            scenario,
        )
    end

    return nothing
end
