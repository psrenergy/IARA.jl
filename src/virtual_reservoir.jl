#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function water_to_energy_factors(inputs::AbstractInputs, hydro_plants_indices::Vector{Int})
    water_to_energy_factors = [NaN for h in 1:maximum(index_of_elements(inputs, HydroPlant))]
    ready_for_calculations_indices = [
        h for h in hydro_plants_indices if
        is_null(hydro_plant_turbine_to(inputs, h)) || !(hydro_plant_turbine_to(inputs, h) in hydro_plants_indices)
    ]
    while !isempty(ready_for_calculations_indices)
        h = popfirst!(ready_for_calculations_indices)
        h_downstream = hydro_plant_turbine_to(inputs, h)
        water_to_energy_factors[h] = if is_null(h_downstream) || !(h_downstream in hydro_plants_indices)
            hydro_plant_production_factor(inputs, h)
        else
            hydro_plant_production_factor(inputs, h) + water_to_energy_factors[h_downstream]
        end
        hydro_plants_now_ready =
            [h_upstream for h_upstream in hydro_plants_indices if hydro_plant_turbine_to(inputs, h_upstream) == h]
        append!(ready_for_calculations_indices, hydro_plants_now_ready)
    end
    @assert all((!isnan).(water_to_energy_factors[hydro_plants_indices]))
    return water_to_energy_factors
end

function order_to_spill_excess_of_inflow(inputs::AbstractInputs, hydro_plants_indices::Vector{Int})
    remaining_indices = copy(hydro_plants_indices)
    ordered_indices = []
    while !isempty(remaining_indices)
        ready_for_calculations_indices =
            [h for h in remaining_indices if !(h in hydro_plant_spill_to(inputs)[remaining_indices])]
        append!(ordered_indices, ready_for_calculations_indices)
        remaining_indices = setdiff(remaining_indices, ready_for_calculations_indices)
    end
    return ordered_indices
end

function additional_energy_from_inflows(
    inputs::AbstractInputs,
    vr::Int,
    inflow_as_volume::Vector{Float64},
    volume::Vector{Float64},
)
    hydro_plants = index_of_elements(inputs, HydroPlant)
    for h in virtual_reservoir_order_to_spill_excess_of_inflow(inputs, vr)
        inflow_excess =
            max(inflow_as_volume[h] - (volume[h] - hydro_plant_min_volume(inputs, h)), 0)
        inflow_as_volume[h] -= inflow_excess
        h_downstream = hydro_plant_spill_to(inputs, h)
        if !is_null(h_downstream) && (h_downstream in virtual_reservoir_order_to_spill_excess_of_inflow(inputs, vr))
            inflow_as_volume[h_downstream] += inflow_excess
        end
    end
    additional_energy =
        sum(inflow_as_volume[h] * virtual_reservoir_water_to_energy_factors(inputs, vr)[h] for h in hydro_plants)
    return additional_energy
end

# TODO: There should have an input parameter for waveguide, and this is the default value
function fill_waveguide_points!(inputs::AbstractInputs, vr::Int)
    hydro_plants = virtual_reservoir_hydro_plant_indices(inputs, vr)
    waveguide_points = zeros(length(index_of_elements(inputs, HydroPlant)), 2)
    fill!(waveguide_points, NaN)

    for h in hydro_plants
        waveguide_points[h, 1] = hydro_plant_min_volume(inputs, h)
        waveguide_points[h, 2] = hydro_plant_max_volume(inputs, h)
    end
    inputs.collections.virtual_reservoir.waveguide_points[vr] = waveguide_points
    @assert all((!isnan).(waveguide_points[hydro_plants, :]))
    @assert all(isnan.(waveguide_points[setdiff(1:end, hydro_plants), :]))
    return nothing
end

function fill_water_to_energy_factors!(inputs::AbstractInputs, vr::Int)
    hydro_plants = virtual_reservoir_hydro_plant_indices(inputs, vr)
    inputs.collections.virtual_reservoir.water_to_energy_factors[vr] .= water_to_energy_factors(inputs, hydro_plants)
    return nothing
end

function fill_initial_energy_stock!(inputs::AbstractInputs, vr::Int)
    hydro_plants = virtual_reservoir_hydro_plant_indices(inputs, vr)
    total_energy_stock = sum(
        hydro_plant_initial_volume(inputs, h) * virtual_reservoir_water_to_energy_factors(inputs, vr)[h] /
        m3_per_second_to_hm3_per_hour() for h in hydro_plants
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
    virtual_reservoir_hydro_plants = virtual_reservoir_hydro_plant_indices(inputs)
    number_of_hydro_plants_per_virtual_reservoir = length.(virtual_reservoir_hydro_plants)

    # Offer segments
    number_of_offer_segments_per_asset_owner_and_virtual_reservoir =
        zeros(Int, number_of_asset_owners, number_of_virtual_reservoirs)
    for vr in virtual_reservoir_indices
        for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
            number_of_offer_segments_per_asset_owner_and_virtual_reservoir[ao, vr] =
                asset_owner_number_of_risk_factors[ao] * number_of_hydro_plants_per_virtual_reservoir[vr]
        end
    end
    maximum_number_of_offer_segments = maximum(number_of_offer_segments_per_asset_owner_and_virtual_reservoir)
    inputs.collections.virtual_reservoir.maximum_number_of_virtual_reservoir_bidding_segments =
        maximum_number_of_offer_segments
    return nothing
end

function post_process_virtual_reservoirs!(
    inputs::AbstractInputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    outputs::Outputs,
    stage::Int,
    scenario::Int,
)
    hydro_plants = index_of_elements(inputs, HydroPlant)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    hydro_volume = simulation_results.data[:hydro_volume]
    virtual_reservoir_generation = simulation_results.data[:virtual_reservoir_generation]

    volume_at_beginning_of_stage = hydro_volume_from_previous_stage(inputs, stage, scenario)
    energy_stock_at_beginning_of_stage =
        virtual_reservoir_energy_stock_from_previous_stage(inputs, stage, scenario)

    inflow_series = time_series_inflow(inputs, run_time_options, 1)
    inflow_as_volume = [
        sum(
            inflow_series[hydro_plant_gauging_station_index(inputs, h), b] * m3_per_second_to_hm3_per_hour() *
            block_duration_in_hours(inputs, b) for b in blocks(inputs)
        ) for h in hydro_plants
    ]

    virtual_reservoir_post_processed_energy_stock =
        [zeros(length(virtual_reservoir_asset_owner_indices(inputs, vr))) for vr in virtual_reservoirs]
    for vr in virtual_reservoirs
        energy_arrival = additional_energy_from_inflows(inputs, vr, inflow_as_volume, volume_at_beginning_of_stage)
        pre_processed_energy_stock = zeros(length(virtual_reservoir_asset_owner_indices(inputs, vr)))

        for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
            pre_processed_energy_stock[ao] =
                energy_stock_at_beginning_of_stage[vr][ao] +
                energy_arrival * virtual_reservoir_asset_owners_inflow_allocation(inputs, vr, ao) -
                sum(virtual_reservoir_generation[vr, ao, :]) # sum over bid_segment dimension
        end
        total_actual_energy_stock = sum(
            hydro_volume[end, h] * virtual_reservoir_water_to_energy_factors(inputs, vr)[h] /
            m3_per_second_to_hm3_per_hour() for h in virtual_reservoir_hydro_plant_indices(inputs, vr)
        )
        if sum(pre_processed_energy_stock) == 0
            if total_actual_energy_stock == 0
                virtual_reservoir_post_processed_energy_stock[vr] .= 0.0
            else
                error("The total actual energy stock is not zero, but the pre-processed energy stock is zero.")
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

function fill_order_to_spill_excess_of_inflow!(inputs::AbstractInputs, vr::Int)
    hydro_plants = virtual_reservoir_hydro_plant_indices(inputs, vr)
    inputs.collections.virtual_reservoir.order_to_spill_excess_of_inflow[vr] .=
        order_to_spill_excess_of_inflow(inputs, hydro_plants)
    return nothing
end

function virtual_reservoir_energy_stock_from_previous_stage(inputs::AbstractInputs, stage::Int, scenario::Int)
    if stage == 1
        return inputs.collections.virtual_reservoir.initial_energy_stock
    else
        return read_serialized_clearing_variable(
            inputs,
            RunTime_ClearingModelType.EX_POST_PHYSICAL,
            :virtual_reservoir_post_processed_energy_stock;
            stage = stage - 1,
            scenario = scenario,
        )
    end
end
