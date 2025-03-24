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

function additional_energy_from_inflows(
    inputs::AbstractInputs,
    inflow_as_volume::Vector{Float64},
    volume::Vector{Float64},
)
    hydro_units = order_to_spill_excess_of_inflow(inputs)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    for h in hydro_units
        max_turbining =
            hydro_unit_max_turbining(inputs, h) * m3_per_second_to_hm3_per_hour() *
            sum(subperiod_duration_in_hours(inputs))
        inflow_excess = max(volume[h] + inflow_as_volume[h] - (hydro_unit_max_volume(inputs, h) + max_turbining), 0)
        inflow_as_volume[h] -= inflow_excess
        h_downstream = hydro_unit_spill_to(inputs, h)
        if !is_null(h_downstream)
            inflow_as_volume[h_downstream] += inflow_excess
        end
    end
    additional_energy = zeros(length(virtual_reservoirs))
    for vr in virtual_reservoirs
        additional_energy[vr] = sum(
            inflow_as_volume[h] * virtual_reservoir_water_to_energy_factors(inputs, vr, h) for
            h in virtual_reservoir_hydro_unit_indices(inputs, vr)
        )
    end
    return additional_energy
end

function fill_waveguide_points_by_uniform_volume_percentage!(inputs::AbstractInputs, vr::Int)
    hydro_units = virtual_reservoir_hydro_unit_indices(inputs, vr)
    waveguide_points = zeros(length(index_of_elements(inputs, HydroUnit)), 2)
    fill!(waveguide_points, NaN)

    for h in hydro_units
        waveguide_points[h, 1] = hydro_unit_min_volume(inputs, h)
        waveguide_points[h, 2] = hydro_unit_max_volume(inputs, h)
    end
    inputs.collections.virtual_reservoir.waveguide_points[vr] = waveguide_points
    @assert all((!isnan).(waveguide_points[hydro_units, :]))
    @assert all(isnan.(waveguide_points[setdiff(1:end, hydro_units), :]))
    return nothing
end

function fill_water_to_energy_factors!(inputs::AbstractInputs, vr::Int)
    hydro_units = virtual_reservoir_hydro_unit_indices(inputs, vr)
    inputs.collections.virtual_reservoir.water_to_energy_factors[vr] .= water_to_energy_factors(inputs, hydro_units)
    return nothing
end

function fill_initial_energy_stock!(inputs::AbstractInputs, vr::Int)
    hydro_units = virtual_reservoir_hydro_unit_indices(inputs, vr)
    total_energy_stock = sum(
        hydro_unit_initial_volume(inputs, h) * virtual_reservoir_water_to_energy_factors(inputs, vr, h) for
        h in hydro_units
    )
    inputs.collections.virtual_reservoir.initial_energy_stock[vr] =
        [NaN for ao in 1:length(index_of_elements(inputs, AssetOwner))]
    for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
        inputs.collections.virtual_reservoir.initial_energy_stock[vr][ao] =
            total_energy_stock * virtual_reservoir_asset_owners_inflow_allocation(inputs, vr, ao)
    end
    return nothing
end

function fill_maximum_number_of_virtual_reservoir_bidding_segments!(inputs::AbstractInputs)
    # Indexes
    virtual_reservoir_indices = index_of_elements(inputs, VirtualReservoir)
    asset_owner_indices = index_of_elements(inputs, AssetOwner)

    # Sizes
    number_of_virtual_reservoirs = length(virtual_reservoir_indices)
    number_of_asset_owners = length(asset_owner_indices)

    # AO
    asset_owner_number_of_risk_factors = zeros(Int, number_of_asset_owners)
    for ao in asset_owner_indices
        asset_owner_number_of_risk_factors[ao] = length(asset_owner_risk_factor(inputs, ao))
    end

    # VR
    virtual_reservoir_hydro_units = virtual_reservoir_hydro_unit_indices(inputs)
    number_of_hydro_units_per_virtual_reservoir = length.(virtual_reservoir_hydro_units)

    # Offer segments
    number_of_offer_segments_per_asset_owner_and_virtual_reservoir =
        zeros(Int, number_of_asset_owners, number_of_virtual_reservoirs)
    for vr in virtual_reservoir_indices
        for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
            number_of_offer_segments_per_asset_owner_and_virtual_reservoir[ao, vr] =
                asset_owner_number_of_risk_factors[ao] * number_of_hydro_units_per_virtual_reservoir[vr]
        end
    end
    maximum_number_of_offer_segments = maximum(number_of_offer_segments_per_asset_owner_and_virtual_reservoir)
    update_number_of_virtual_reservoir_bidding_segments!(inputs, maximum_number_of_offer_segments)

    return nothing
end

function update_number_of_virtual_reservoir_bidding_segments!(inputs::AbstractInputs, value::Int)
    values_array = fill(value, length(index_of_elements(inputs, VirtualReservoir)))
    update_number_of_virtual_reservoir_bidding_segments!(inputs, values_array)
    return nothing
end

function update_number_of_virtual_reservoir_bidding_segments!(inputs::AbstractInputs, values::Array{Int})
    if length(inputs.collections.virtual_reservoir._maximum_number_of_virtual_reservoir_bidding_segments) == 0
        inputs.collections.virtual_reservoir._maximum_number_of_virtual_reservoir_bidding_segments = zeros(
            Int,
            length(index_of_elements(inputs, VirtualReservoir)),
        )
    end
    inputs.collections.virtual_reservoir._maximum_number_of_virtual_reservoir_bidding_segments .= values
    return nothing
end

function post_process_virtual_reservoirs!(
    inputs::AbstractInputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    outputs::Outputs,
    period::Int,
    scenario::Int,
)
    hydro_units = index_of_elements(inputs, HydroUnit)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    hydro_volume = simulation_results.data[:hydro_volume]
    virtual_reservoir_generation = simulation_results.data[:virtual_reservoir_generation]

    volume_at_beginning_of_period = hydro_volume_from_previous_period(inputs, period, scenario)
    energy_stock_at_beginning_of_period =
        virtual_reservoir_energy_stock_from_previous_period(inputs, period, scenario)

    subscenario = 1 # Is this still correct?
    inflow_series = time_series_inflow(inputs, run_time_options; subscenario)
    inflow_as_volume = [
        sum(
            inflow_series[hydro_unit_gauging_station_index(inputs, h), b] * m3_per_second_to_hm3_per_hour() *
            subperiod_duration_in_hours(inputs, b) for b in subperiods(inputs)
        ) for h in hydro_units
    ]
    energy_arrival = additional_energy_from_inflows(inputs, inflow_as_volume, volume_at_beginning_of_period)

    virtual_reservoir_post_processed_energy_stock =
        [zeros(length(virtual_reservoir_asset_owner_indices(inputs, vr))) for vr in virtual_reservoirs]
    for vr in virtual_reservoirs
        pre_processed_energy_stock = zeros(length(virtual_reservoir_asset_owner_indices(inputs, vr)))

        for (i, ao) in enumerate(virtual_reservoir_asset_owner_indices(inputs, vr))
            pre_processed_energy_stock[i] =
                energy_stock_at_beginning_of_period[vr][i] +
                energy_arrival[vr] * virtual_reservoir_asset_owners_inflow_allocation(inputs, vr, ao) -
                sum(virtual_reservoir_generation[vr, ao, :]) # sum over bid_segment dimension
        end
        total_actual_energy_stock = sum(
            hydro_volume[end, h] * virtual_reservoir_water_to_energy_factors(inputs, vr, h) for
            h in virtual_reservoir_hydro_unit_indices(inputs, vr)
        )
        if sum(pre_processed_energy_stock) == 0
            if total_actual_energy_stock == 0
                virtual_reservoir_post_processed_energy_stock[vr] .= 0.0
            else
                @warn("The total actual energy stock is not zero, but the pre-processed energy stock is zero.")
                virtual_reservoir_post_processed_energy_stock[vr] .=
                    virtual_reservoir_asset_owners_inflow_allocation(inputs, vr) *
                    total_actual_energy_stock
            end
        else
            correction_factor = total_actual_energy_stock / sum(pre_processed_energy_stock)
            virtual_reservoir_post_processed_energy_stock[vr] .= pre_processed_energy_stock * correction_factor
        end
    end
    simulation_results.data[:virtual_reservoir_post_processed_energy_stock] =
        virtual_reservoir_post_processed_energy_stock
    add_symbol_to_serialize!(outputs, :virtual_reservoir_post_processed_energy_stock)

    return nothing
end

function virtual_reservoir_energy_stock_from_previous_period(inputs::AbstractInputs, period::Int, scenario::Int)
    if period == 1
        return inputs.collections.virtual_reservoir.initial_energy_stock
    else
        return read_serialized_clearing_variable(
            inputs,
            RunTime_ClearingSubproblem.EX_POST_PHYSICAL,
            :virtual_reservoir_post_processed_energy_stock;
            period = period - 1,
            scenario = scenario,
        )
    end
end

function fill_waveguide_points!(inputs::AbstractInputs, vr::Int)
    if vr_curveguide_data_source(inputs) == Configurations_VRCurveguideDataSource.READ_FROM_FILE
        fill_waveguide_points_provided_by_user!(inputs, vr)
    elseif vr_curveguide_data_source(inputs) ==
           Configurations_VRCurveguideDataSource.UNIFORM_ACROSS_RESERVOIRS
        fill_waveguide_points_by_uniform_volume_percentage!(inputs, vr)
    else
        error("Waveguide source $(vr_curveguide_data_source(inputs)) not implemented.")
    end
end

function fill_waveguide_points_provided_by_user!(inputs::AbstractInputs, vr::Int)
    hydro_units_idx = virtual_reservoir_hydro_unit_indices(inputs, vr)
    virtual_reservoir_waveguide_points = vcat(
        [hydro_unit_waveguide_volume(inputs, h)' for h in hydro_units_idx]...,
    )
    inputs.collections.virtual_reservoir.waveguide_points[vr] = virtual_reservoir_waveguide_points
    return nothing
end

virtual_reservoir_waveguide_filename(inputs::AbstractInputs, vr::Int) =
    "$(path_case(inputs))/waveguide_points_$(virtual_reservoir_label(inputs, vr)).csv"

virtual_reservoir_waveguide_filename(path_case::String, vr::String) = "$(path_case)/waveguide_points_$vr.csv"
