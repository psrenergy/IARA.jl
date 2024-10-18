#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function initialize_heuristic_bids_outputs(
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
)
    labels = labels_for_output_by_pair_of_agents(
        inputs,
        run_time_options,
        inputs.collections.bidding_group,
        inputs.collections.bus;
        index_getter = all_buses,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        run_time_options,
        output_name = "bidding_group_energy_offer",
        dimensions = ["stage", "scenario", "block", "bid_segment"],
        unit = "MWh",
        labels,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        run_time_options,
        output_name = "bidding_group_price_offer",
        dimensions = ["stage", "scenario", "block", "bid_segment"],
        unit = "\$/MWh",
        labels,
    )

    return nothing
end

function markup_offers_for_stage_scenario(
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    stage::Int,
    scenario::Int,
)
    bidding_group_indexes = index_of_elements(inputs, BiddingGroup; filters = [markup_heuristic_bids])
    number_of_bidding_groups = length(bidding_group_indexes)
    number_of_buses = number_of_elements(inputs, Bus)

    available_energy_per_hydro_plant =
        if run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING &&
           clearing_hydro_representation(inputs) ==
           Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
            hydro_available_energy(inputs, stage, scenario)
        end

    bidding_group_number_of_risk_factors = zeros(Int, number_of_bidding_groups)
    bidding_group_hydro_plants = [Int[] for _ in 1:number_of_bidding_groups]
    bidding_group_thermal_plants = [Int[] for _ in 1:number_of_bidding_groups]
    bidding_group_renewable_plants = [Int[] for _ in 1:number_of_bidding_groups]

    for bg in bidding_group_indexes
        bidding_group_number_of_risk_factors[bg] = length(bidding_group_risk_factor(inputs, bg))
        if clearing_hydro_representation(inputs) !=
           Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
            bidding_group_hydro_plants[bg] = findall(isequal(bg), hydro_plant_bidding_group_index(inputs))
        end
        bidding_group_thermal_plants[bg] = findall(isequal(bg), thermal_plant_bidding_group_index(inputs))
        bidding_group_renewable_plants[bg] = findall(isequal(bg), renewable_plant_bidding_group_index(inputs))
    end

    number_of_hydro_plants_per_bidding_group_and_bus = zeros(Int, number_of_bidding_groups, number_of_buses)
    number_of_thermal_plants_per_bidding_group_and_bus = zeros(Int, number_of_bidding_groups, number_of_buses)
    number_of_renewable_plants_per_bidding_group_and_bus = zeros(Int, number_of_bidding_groups, number_of_buses)

    for bg in bidding_group_indexes
        for h in bidding_group_hydro_plants[bg]
            bus = hydro_plant_bus_index(inputs, h)
            number_of_hydro_plants_per_bidding_group_and_bus[bg, bus] += 1
        end
        for t in bidding_group_thermal_plants[bg]
            bus = thermal_plant_bus_index(inputs, t)
            number_of_thermal_plants_per_bidding_group_and_bus[bg, bus] += 1
        end
        for r in bidding_group_renewable_plants[bg]
            bus = renewable_plant_bus_index(inputs, r)
            number_of_renewable_plants_per_bidding_group_and_bus[bg, bus] += 1
        end
    end

    number_of_plants_per_bidding_group_and_bus =
        number_of_hydro_plants_per_bidding_group_and_bus .+
        number_of_thermal_plants_per_bidding_group_and_bus .+ number_of_renewable_plants_per_bidding_group_and_bus

    maximum_number_of_plants_per_bidding_group =
        dropdims(maximum(number_of_plants_per_bidding_group_and_bus; dims = 2); dims = 2)

    number_of_offer_segments = bidding_group_number_of_risk_factors .* maximum_number_of_plants_per_bidding_group
    maximum_number_of_offer_segments = maximum(number_of_offer_segments; init = 0)

    quantity_offers = zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_offer_segments,
        number_of_blocks(inputs),
    )
    price_offers = zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_offer_segments,
        number_of_blocks(inputs),
    )

    for bg in bidding_group_indexes
        thermal_quantity_offers, thermal_price_offers = build_thermal_offers(
            inputs,
            bg,
            bidding_group_thermal_plants[bg],
            bidding_group_number_of_risk_factors[bg],
        )

        renewable_quantity_offers, renewable_price_offers = build_renewable_offers(
            inputs,
            bg,
            bidding_group_renewable_plants[bg],
            bidding_group_number_of_risk_factors[bg],
        )

        hydro_quantity_offers, hydro_price_offers = build_hydro_offers(
            inputs,
            bg,
            bidding_group_hydro_plants[bg],
            bidding_group_number_of_risk_factors[bg],
            available_energy_per_hydro_plant,
        )

        bidding_group_quantity_offers = hcat(thermal_quantity_offers, renewable_quantity_offers, hydro_quantity_offers)
        bidding_group_price_offers = hcat(thermal_price_offers, renewable_price_offers, hydro_price_offers)

        number_of_quantity_segments = size(bidding_group_quantity_offers, 2)
        number_of_price_segments = size(bidding_group_price_offers, 2)

        @assert number_of_quantity_segments == number_of_price_segments
        @assert number_of_quantity_segments <= maximum_number_of_offer_segments

        quantity_offers[bg, :, 1:number_of_quantity_segments, :] = bidding_group_quantity_offers
        price_offers[bg, :, 1:number_of_price_segments, :] = bidding_group_price_offers
    end

    write_bid_output(
        outputs,
        inputs,
        run_time_options,
        "bidding_group_energy_offer",
        # We have to permutate the dimensions because the function expects the dimensions in the order
        # block, bidding_group, bid_segments, bus
        permutedims(quantity_offers, (4, 1, 3, 2));
        stage,
        scenario,
        subscenario = 1, # subscenario dimension is fixed to 1 for heuristic bids
    )

    write_bid_output(
        outputs,
        inputs,
        run_time_options,
        "bidding_group_price_offer",
        # We have to permutate the dimensions because the function expects the dimensions in the order
        # block, bidding_group, bid_segments, bus
        permutedims(price_offers, (4, 1, 3, 2));
        stage,
        scenario,
        subscenario = 1, # subscenario dimension is fixed to 1 for heuristic bids
    )

    if run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING
        serialize_heuristic_bids(
            inputs,
            quantity_offers,
            price_offers;
            stage,
            scenario,
        )
    end

    return nothing
end

function build_thermal_offers(
    inputs::Inputs,
    bg_index::Int,
    thermal_plant_indexes::Vector{Int},
    number_of_risk_factors::Int,
)
    buses = index_of_elements(inputs, Bus)
    number_of_buses = length(buses)
    thermal_plant_indexes_per_bus = [Int[] for _ in 1:number_of_buses]

    for thermal_plant in thermal_plant_indexes
        bus = thermal_plant_bus_index(inputs, thermal_plant)
        push!(thermal_plant_indexes_per_bus[bus], thermal_plant)
    end

    number_of_thermal_plants_per_bus = length.(thermal_plant_indexes_per_bus)
    number_of_segments_per_bus = number_of_risk_factors .* number_of_thermal_plants_per_bus
    maximum_number_of_offer_segments = maximum(number_of_segments_per_bus)

    quantity_offers = zeros(number_of_buses, maximum_number_of_offer_segments, number_of_blocks(inputs))
    price_offers = zeros(number_of_buses, maximum_number_of_offer_segments, number_of_blocks(inputs))

    for bus in buses
        for (plant_idx, thermal_plant) in enumerate(thermal_plant_indexes_per_bus[bus])
            for risk_idx in 1:number_of_risk_factors
                segment = (plant_idx - 1) * number_of_risk_factors + risk_idx
                # bg parameters
                segment_fraction = bidding_group_segment_fraction(inputs, bg_index)[risk_idx]
                risk_factor = bidding_group_risk_factor(inputs, bg_index)[risk_idx]
                for block in 1:number_of_blocks(inputs)
                    quantity_offers[bus, segment, block] =
                        thermal_plant_max_generation(inputs, thermal_plant) * block_duration_in_hours(inputs, block) *
                        segment_fraction
                    price_offers[bus, segment, block] = thermal_plant_om_cost(inputs, thermal_plant) * (1 + risk_factor)
                end
            end
        end
    end

    return quantity_offers, price_offers
end

function build_renewable_offers(
    inputs::Inputs,
    bg_index::Int,
    renewable_plant_indexes::Vector{Int},
    number_of_risk_factors::Int,
)
    buses = index_of_elements(inputs, Bus)
    number_of_buses = length(buses)
    renewable_plant_indexes_per_bus = [Int[] for _ in 1:number_of_buses]

    for renewable_plant in renewable_plant_indexes
        bus = renewable_plant_bus_index(inputs, renewable_plant)
        push!(renewable_plant_indexes_per_bus[bus], renewable_plant)
    end

    renewable_generation_series = time_series_renewable_generation(inputs)

    number_of_renewable_plants_per_bus = length.(renewable_plant_indexes_per_bus)
    number_of_segments_per_bus = number_of_risk_factors .* number_of_renewable_plants_per_bus
    maximum_number_of_offer_segments = maximum(number_of_segments_per_bus)

    quantity_offers = zeros(number_of_buses, maximum_number_of_offer_segments, number_of_blocks(inputs))
    price_offers = zeros(number_of_buses, maximum_number_of_offer_segments, number_of_blocks(inputs))

    for bus in buses
        for (plant_idx, renewable_plant) in enumerate(renewable_plant_indexes_per_bus[bus])
            for risk_idx in 1:number_of_risk_factors
                segment = (plant_idx - 1) * number_of_risk_factors + risk_idx
                # bg parameters
                segment_fraction = bidding_group_segment_fraction(inputs, bg_index)[risk_idx]
                risk_factor = bidding_group_risk_factor(inputs, bg_index)[risk_idx]
                for block in 1:number_of_blocks(inputs)
                    quantity_offers[bus, segment, block] =
                        renewable_plant_max_generation(inputs, renewable_plant) *
                        renewable_generation_series[renewable_plant, block]
                    block_duration_in_hours(inputs, block) * segment_fraction
                    price_offers[bus, segment, block] =
                        renewable_plant_om_cost(inputs, renewable_plant) * (1 + risk_factor)
                end
            end
        end
    end

    return quantity_offers, price_offers
end

function build_hydro_offers(
    inputs::Inputs,
    bg_index::Int,
    hydro_plant_indexes::Vector{Int},
    number_of_risk_factors::Int,
    available_energy::Union{Vector{Float64}, Nothing},
)
    buses = index_of_elements(inputs, Bus)
    number_of_buses = length(buses)
    hydro_plant_indexes_per_bus = [Int[] for _ in 1:number_of_buses]

    for hydro_plant in hydro_plant_indexes
        bus = hydro_plant_bus_index(inputs, hydro_plant)
        push!(hydro_plant_indexes_per_bus[bus], hydro_plant)
    end

    number_of_hydro_plants_per_bus = length.(hydro_plant_indexes_per_bus)
    number_of_segments_per_bus = number_of_risk_factors .* number_of_hydro_plants_per_bus
    maximum_number_of_offer_segments = maximum(number_of_segments_per_bus)

    quantity_offers = zeros(number_of_buses, maximum_number_of_offer_segments, number_of_blocks(inputs))
    price_offers = zeros(number_of_buses, maximum_number_of_offer_segments, number_of_blocks(inputs))

    for bus in buses
        for (plant_idx, hydro_plant) in enumerate(hydro_plant_indexes_per_bus[bus])
            for risk_idx in 1:number_of_risk_factors
                segment = (plant_idx - 1) * number_of_risk_factors + risk_idx
                # bg parameters
                segment_fraction = bidding_group_segment_fraction(inputs, bg_index)[risk_idx]
                risk_factor = bidding_group_risk_factor(inputs, bg_index)[risk_idx]
                for block in 1:number_of_blocks(inputs)
                    quantity_offers[bus, segment, block] =
                        time_series_hydro_generation(inputs)[hydro_plant, block] / MW_to_GW() * segment_fraction
                    price_offers[bus, segment, block] =
                        time_series_hydro_opportunity_cost(inputs)[hydro_plant, block] * (1 + risk_factor)
                end
                if isnothing(available_energy)
                    continue
                end
                available_energy_in_segment = available_energy[hydro_plant] * segment_fraction
                if available_energy_in_segment < sum(quantity_offers[bus, segment, :])
                    adjusting_factor = available_energy_in_segment / sum(quantity_offers[bus, segment, :])
                    quantity_offers[bus, segment, :] .*= adjusting_factor
                end
            end
        end
    end

    return quantity_offers, price_offers
end

function hydro_available_energy(
    inputs::Inputs,
    stage::Int,
    scenario::Int,
)
    hydro_plants = index_of_elements(inputs, HydroPlant; filters = [is_existing])
    inflow = time_series_inflow(inputs)

    available_water = zeros(length(hydro_plants))
    total_inflow_in_stage = [
        sum(
            inflow[h, blk] * m3_per_second_to_hm3_per_hour() * block_duration_in_hours(inputs, blk) for
            blk in 1:number_of_blocks(inputs)
        ) for h in hydro_plants
    ]
    available_water_ignoring_upstream_plants =
        hydro_volume_from_previous_stage(inputs, stage, scenario) .+ total_inflow_in_stage

    for h in hydro_plants
        current_hydro = h
        # Sum 'available_water_ignoring_upstream_plants' of plant 'h' to 'available_water' in all its downstream plants
        while !is_null(current_hydro)
            available_water[current_hydro] += available_water_ignoring_upstream_plants[h]
            current_hydro = hydro_plant_turbine_to(inputs, current_hydro)
        end
    end

    available_energy = available_water ./ m3_per_second_to_hm3_per_hour() .* hydro_plant_production_factor(inputs)

    return available_energy
end

function must_read_hydro_plant_data_for_markup_wizard(inputs::Inputs)
    # This function returns true when the following conditions are met:
    # 1. The run mode is not CENTRALIZED_OPERATION
    # 2. There is at least one bidding group with markup_heuristic_bids = true
    # 3. There is at least one hydro plant that is associated with a bidding group with markup_heuristic_bids = true
    if run_mode(inputs) == Configurations_RunMode.CENTRALIZED_OPERATION
        return false
    end
    if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
        return true
    elseif clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.PURE_BIDS
        bidding_group_indexes = index_of_elements(inputs, BiddingGroup; filters = [markup_heuristic_bids])
        if isempty(bidding_group_indexes)
            return false
        end
        for hydro_plant in index_of_elements(inputs, HydroPlant)
            if hydro_plant_bidding_group_index(inputs, hydro_plant) in bidding_group_indexes
                return true
            end
        end
    end
    return false
end

function initialize_virtual_reservoir_bids_outputs(
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
)
    labels = labels_for_output_by_pair_of_agents(
        inputs,
        run_time_options,
        inputs.collections.virtual_reservoir,
        inputs.collections.asset_owner;
        index_getter = virtual_reservoir_asset_owner_indices,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        run_time_options,
        output_name = "virtual_reservoir_energy_offer",
        dimensions = ["stage", "scenario", "bid_segment"],
        unit = "MWh",
        labels,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        run_time_options,
        output_name = "virtual_reservoir_price_offer",
        dimensions = ["stage", "scenario", "bid_segment"],
        unit = "\$/MWh",
        labels,
    )

    return nothing
end

function virtual_reservoir_markup_offers_for_stage_scenario(
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    stage::Int,
    scenario::Int,
)
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

    # Hydro 
    available_energy_per_hydro_plant = if run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING
        hydro_available_energy(inputs, stage, scenario)
    end

    # AO in VR
    energy_share_of_asset_owner_in_virtual_reservoir = zeros(number_of_virtual_reservoirs, number_of_asset_owners)

    energy_stock_at_beginning_of_stage = virtual_reservoir_energy_stock_from_previous_stage(inputs, stage, scenario)
    for vr in virtual_reservoir_indices
        total_virtual_reservoir_energy_stock = sum(energy_stock_at_beginning_of_stage[vr])
        for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
            energy_share_of_asset_owner_in_virtual_reservoir[vr, ao] =
                energy_stock_at_beginning_of_stage[vr][ao] / total_virtual_reservoir_energy_stock
        end
    end

    maximum_number_of_offer_segments = maximum_number_of_virtual_reservoir_bidding_segments(inputs)

    # Offers
    quantity_offers = zeros(
        number_of_virtual_reservoirs,
        number_of_asset_owners,
        maximum_number_of_offer_segments,
    )

    price_offers = zeros(
        number_of_virtual_reservoirs,
        number_of_asset_owners,
        maximum_number_of_offer_segments,
    )

    for vr in virtual_reservoir_indices
        for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
            # vr parameters
            energy_share = energy_share_of_asset_owner_in_virtual_reservoir[vr, ao]

            for (plant_idx, hydro_plant) in enumerate(virtual_reservoir_hydro_plants[vr])
                # hydro plant parameters
                total_generation = sum(time_series_hydro_generation(inputs)[hydro_plant, :] / MW_to_GW())
                if total_generation > available_energy_per_hydro_plant[hydro_plant]
                    total_generation = available_energy_per_hydro_plant[hydro_plant]
                end
                average_cost =
                    sum(time_series_hydro_opportunity_cost(inputs)[hydro_plant, :]) / number_of_blocks(inputs) # TODO: weighted average

                for risk_idx in 1:asset_owner_number_of_risk_factors[ao]
                    segment = (plant_idx - 1) * asset_owner_number_of_risk_factors[ao] + risk_idx
                    # ao parameters
                    segment_fraction = asset_owner_segment_fraction(inputs, ao)[risk_idx]
                    risk_factor = asset_owner_risk_factor(inputs, ao)[risk_idx]

                    # offers
                    quantity_offers[vr, ao, segment] = (total_generation * energy_share) * segment_fraction
                    price_offers[vr, ao, segment] = average_cost * (1 + risk_factor)
                end
            end
        end
    end

    write_virtual_reservoir_bid_output(
        outputs,
        inputs,
        run_time_options,
        "virtual_reservoir_energy_offer",
        quantity_offers,
        stage,
        scenario,
    )

    write_virtual_reservoir_bid_output(
        outputs,
        inputs,
        run_time_options,
        "virtual_reservoir_price_offer",
        price_offers,
        stage,
        scenario,
    )

    serialize_virtual_reservoir_heuristic_bids(
        inputs,
        quantity_offers,
        price_offers;
        stage,
        scenario,
    )

    return nothing
end
