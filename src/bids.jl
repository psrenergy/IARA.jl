#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

"""
    initialize_heuristic_bids_outputs(inputs::Inputs, outputs::Outputs, run_time_options::RunTimeOptions)

Initialize the output files for bidding group energy and price offers.
"""
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
        filters_to_apply_in_first_collection = [has_generation_besides_virtual_reservoirs],
    )

    if has_any_simple_bids(inputs)
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            run_time_options,
            output_name = "bidding_group_energy_offer",
            dimensions = ["period", "scenario", "subperiod", "bid_segment"],
            unit = "MWh",
            labels,
        )

        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            run_time_options,
            output_name = "bidding_group_price_offer",
            dimensions = ["period", "scenario", "subperiod", "bid_segment"],
            unit = "\$/MWh",
            labels,
        )

        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            run_time_options,
            output_name = "bidding_group_no_markup_price_offer",
            dimensions = ["period", "scenario", "subperiod", "bid_segment"],
            unit = "\$/MWh",
            labels,
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

function markup_offers_for_period_scenario(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    period::Int,
    scenario::Int;
    outputs::Union{Outputs, Nothing} = nothing,
)
    if any_elements(inputs, BiddingGroup) && has_any_simple_bids(inputs)
        bidding_group_markup_offers_for_period_scenario(
            inputs,
            run_time_options,
            period,
            scenario;
            outputs,
        )
    end
    if clearing_hydro_representation(inputs) ==
       Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
        virtual_reservoir_markup_offers_for_period_scenario(
            inputs,
            run_time_options,
            period,
            scenario;
            outputs,
        )
    end

    return nothing
end

function bidding_group_markup_units(inputs::Inputs)
    bidding_group_indexes = index_of_elements(inputs, BiddingGroup)
    number_of_bidding_groups = length(bidding_group_indexes)
    number_of_buses = number_of_elements(inputs, Bus)

    bidding_group_number_of_risk_factors = zeros(Int, number_of_bidding_groups)
    bidding_group_hydro_units = [Int[] for _ in 1:number_of_bidding_groups]
    bidding_group_thermal_units = [Int[] for _ in 1:number_of_bidding_groups]
    bidding_group_renewable_units = [Int[] for _ in 1:number_of_bidding_groups]
    bidding_group_demand_units = [Int[] for _ in 1:number_of_bidding_groups]

    for bg in bidding_group_indexes
        bidding_group_number_of_risk_factors[bg] = length(bidding_group_risk_factor(inputs, bg))
        bidding_group_hydro_units[bg] = findall(isequal(bg), hydro_unit_bidding_group_index(inputs))
        if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
            filter!(
                x -> !is_associated_with_some_virtual_reservoir(inputs.collections.hydro_unit, x),
                bidding_group_hydro_units[bg],
            )
        end
        bidding_group_thermal_units[bg] = findall(isequal(bg), thermal_unit_bidding_group_index(inputs))
        bidding_group_renewable_units[bg] = findall(isequal(bg), renewable_unit_bidding_group_index(inputs))
        bidding_group_demand_units[bg] = findall(isequal(bg), demand_unit_bidding_group_index(inputs))
    end
    return bidding_group_number_of_risk_factors, bidding_group_hydro_units,
    bidding_group_thermal_units, bidding_group_renewable_units, bidding_group_demand_units
end

function number_of_virtual_reservoir_offer_segments_for_heuristic_bids(inputs::AbstractInputs)
    # Indexes
    virtual_reservoir_indices = index_of_elements(inputs, VirtualReservoir)
    asset_owner_indices = index_of_elements(inputs, AssetOwner)

    # Sizes
    number_of_virtual_reservoirs = length(virtual_reservoir_indices)
    number_of_asset_owners = length(asset_owner_indices)
    number_of_reference_curve_segments = length(reference_curve_demand_multipliers(inputs))

    # AO
    asset_owner_number_of_risk_factors = zeros(Int, number_of_asset_owners)
    for ao in asset_owner_indices
        asset_owner_number_of_risk_factors[ao] = length(asset_owner_risk_factor_for_virtual_reservoir_bids(inputs, ao))
    end

    # Offer segments
    number_of_offer_segments_per_asset_owner_and_virtual_reservoir =
        zeros(Int, number_of_asset_owners, number_of_virtual_reservoirs)
    for vr in virtual_reservoir_indices
        for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
            number_of_offer_segments_per_asset_owner_and_virtual_reservoir[ao, vr] =
                asset_owner_number_of_risk_factors[ao] + number_of_reference_curve_segments
        end
    end
    number_per_virtual_reservoir = [
        maximum(number_of_offer_segments_per_asset_owner_and_virtual_reservoir[:, vr]) for
        vr in virtual_reservoir_indices
    ]

    return number_per_virtual_reservoir
end

function number_of_bidding_group_offer_segments_for_heuristic_bids(inputs::Inputs)
    bidding_group_indexes = index_of_elements(inputs, BiddingGroup)
    number_of_bidding_groups = length(bidding_group_indexes)
    number_of_buses = number_of_elements(inputs, Bus)
    bidding_group_number_of_risk_factors, bidding_group_hydro_units,
    bidding_group_thermal_units, bidding_group_renewable_units, bidding_group_demand_units =
        bidding_group_markup_units(inputs)

    number_of_hydro_units_per_bidding_group_and_bus =
        get_number_of_units_per_bus_and_bg(inputs, bidding_group_hydro_units, hydro_unit_bus_index)
    number_of_thermal_units_per_bidding_group_and_bus =
        get_number_of_units_per_bus_and_bg(inputs, bidding_group_thermal_units, thermal_unit_bus_index)
    number_of_renewable_units_per_bidding_group_and_bus =
        get_number_of_units_per_bus_and_bg(inputs, bidding_group_renewable_units, renewable_unit_bus_index)
    number_of_demand_units_per_bidding_group_and_bus =
        get_number_of_units_per_bus_and_bg(inputs, bidding_group_demand_units, demand_unit_bus_index)

    number_of_units_per_bidding_group_and_bus =
        number_of_hydro_units_per_bidding_group_and_bus .+
        number_of_thermal_units_per_bidding_group_and_bus .+
        number_of_renewable_units_per_bidding_group_and_bus .+
        number_of_demand_units_per_bidding_group_and_bus

    maximum_number_of_units_per_bidding_group =
        dropdims(maximum(number_of_units_per_bidding_group_and_bus; dims = 2, init = 0); dims = 2)

    number_of_offer_segments = bidding_group_number_of_risk_factors .* maximum_number_of_units_per_bidding_group

    return number_of_offer_segments
end

"""
    bidding_group_markup_offers_for_period_scenario(
        inputs::Inputs, outputs::Outputs, 
        run_time_options::RunTimeOptions, 
        period::Int, 
        scenario::Int
    )

Generate heuristic bids for the bidding groups and write them to the output files.
"""
function bidding_group_markup_offers_for_period_scenario(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    period::Int,
    scenario::Int;
    outputs::Union{Outputs, Nothing} = nothing,
)
    bidding_group_indexes = index_of_elements(
        inputs,
        BiddingGroup;
        filters = [has_generation_besides_virtual_reservoirs],
    )
    number_of_bidding_groups = number_of_elements(inputs, BiddingGroup)
    number_of_buses = number_of_elements(inputs, Bus)

    available_energy_per_hydro_unit =
        if clearing_has_volume_variables(inputs, run_time_options)
            hydro_available_energy(inputs, run_time_options, period, scenario)
        end
    renewable_generation_series = time_series_renewable_generation(inputs, run_time_options)

    bidding_group_number_of_risk_factors, bidding_group_hydro_units,
    bidding_group_thermal_units, bidding_group_renewable_units, bidding_group_demand_units =
        bidding_group_markup_units(inputs)

    maximum_number_of_offer_segments = maximum_number_of_bg_bidding_segments(inputs)

    quantity_offers = zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_offer_segments,
        number_of_subperiods(inputs),
    )
    price_offers = zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_offer_segments,
        number_of_subperiods(inputs),
    )
    no_markup_price_offers = zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_offer_segments,
        number_of_subperiods(inputs),
    )

    number_of_segments_validation_flag = false

    for bg in bidding_group_indexes
        segment_offset_per_bus = zeros(Int, number_of_buses)

        thermal_unit_indexes_per_bus = get_unit_index_by_bus(
            inputs,
            bidding_group_thermal_units,
            bg,
            thermal_unit_bus_index,
        )

        hydro_unit_indexes_per_bus = get_unit_index_by_bus(
            inputs,
            bidding_group_hydro_units,
            bg,
            hydro_unit_bus_index,
        )

        renewable_unit_indexes_per_bus = get_unit_index_by_bus(
            inputs,
            bidding_group_renewable_units,
            bg,
            renewable_unit_bus_index,
        )

        demand_unit_indexes_per_bus = get_unit_index_by_bus(
            inputs,
            bidding_group_demand_units,
            bg,
            demand_unit_bus_index,
        )

        build_thermal_offers!(
            inputs,
            bg,
            quantity_offers,
            price_offers,
            no_markup_price_offers,
            thermal_unit_indexes_per_bus,
            bidding_group_number_of_risk_factors[bg],
            segment_offset_per_bus,
        )

        build_renewable_offers!(
            inputs,
            bg,
            quantity_offers,
            price_offers,
            no_markup_price_offers,
            renewable_unit_indexes_per_bus,
            bidding_group_number_of_risk_factors[bg],
            segment_offset_per_bus,
            renewable_generation_series,
        )

        build_hydro_offers!(
            inputs,
            bg,
            quantity_offers,
            price_offers,
            no_markup_price_offers,
            hydro_unit_indexes_per_bus,
            bidding_group_number_of_risk_factors[bg],
            segment_offset_per_bus,
            available_energy_per_hydro_unit,
        )

        build_demand_offers!(
            inputs,
            bg,
            quantity_offers,
            price_offers,
            no_markup_price_offers,
            demand_unit_indexes_per_bus,
            bidding_group_number_of_risk_factors[bg],
            segment_offset_per_bus,
            time_series_demand(inputs, run_time_options),
        )

        # Number of segments per per "bidding group - bus" pair must always be less than or equal to the maximum number of offer segments
        @assert maximum(segment_offset_per_bus) <= maximum_number_of_offer_segments
        # Number of segments per per "bidding group - bus" pair must be equal to the maximum number of offer segments at least once
        if maximum(segment_offset_per_bus) == maximum_number_of_offer_segments
            number_of_segments_validation_flag = true
        end
    end

    @assert number_of_segments_validation_flag

    write_bid_output(
        outputs,
        inputs,
        run_time_options,
        "bidding_group_energy_offer",
        # We have to permutate the dimensions because the function expects the dimensions in the order
        # subperiod, bidding_group, bid_segments, bus
        permutedims(quantity_offers[bidding_group_indexes, :, :, :], (4, 1, 3, 2));
        period,
        scenario,
        subscenario = 1, # subscenario dimension is fixed to 1 for heuristic bids
        filters = [has_generation_besides_virtual_reservoirs],
    )

    write_bid_output(
        outputs,
        inputs,
        run_time_options,
        "bidding_group_price_offer",
        # We have to permutate the dimensions because the function expects the dimensions in the order
        # subperiod, bidding_group, bid_segments, bus
        permutedims(price_offers[bidding_group_indexes, :, :, :], (4, 1, 3, 2));
        period,
        scenario,
        subscenario = 1, # subscenario dimension is fixed to 1 for heuristic bids
        filters = [has_generation_besides_virtual_reservoirs],
    )

    write_bid_output(
        outputs,
        inputs,
        run_time_options,
        "bidding_group_no_markup_price_offer",
        # We have to permutate the dimensions because the function expects the dimensions in the order
        # subperiod, bidding_group, bid_segments, bus
        permutedims(no_markup_price_offers[bidding_group_indexes, :, :, :], (4, 1, 3, 2));
        period,
        scenario,
        subscenario = 1, # subscenario dimension is fixed to 1 for heuristic bids
        filters = [has_generation_besides_virtual_reservoirs],
    )

    if is_market_clearing(inputs)
        serialize_heuristic_bids(
            inputs,
            quantity_offers,
            price_offers;
            period,
            scenario,
        )
    end

    return nothing
end

function get_number_of_units_per_bus_and_bg(
    inputs::Inputs,
    unit_indexes::Vector{Vector{Int}},
    unit_bus_index::Function,
)
    buses = index_of_elements(inputs, Bus)
    number_of_buses = length(buses)
    bidding_groups = index_of_elements(inputs, BiddingGroup)
    number_of_bgs = length(bidding_groups)

    number_of_units_per_bus_and_bg = zeros(Int, number_of_bgs, number_of_buses)

    for bg in bidding_groups
        for h in unit_indexes[bg]
            bus = unit_bus_index(inputs, h)
            number_of_units_per_bus_and_bg[bg, bus] += 1
        end
    end

    return number_of_units_per_bus_and_bg
end

function get_unit_index_by_bus(
    inputs::Inputs,
    unit_indexes::Vector{Vector{Int}},
    bg::Int,
    unit_bus_index::Function,
)
    buses = index_of_elements(inputs, Bus)
    number_of_buses = length(buses)
    unit_indexes_per_bus = [Int[] for _ in 1:number_of_buses]

    for unit in unit_indexes[bg]
        bus = unit_bus_index(inputs, unit)
        push!(unit_indexes_per_bus[bus], unit)
    end

    return unit_indexes_per_bus
end

"""
    build_thermal_offers(
        inputs::Inputs, 
        bg_index::Int, 
        thermal_unit_indexes::Vector{Int}, 
        number_of_risk_factors::Int
    )

Build the quantity and price offers for thermal units associated with a bidding group.
"""
function build_thermal_offers!(
    inputs::Inputs,
    bg_index::Int,
    quantity_offers::Array{Float64, 4},
    price_offers::Array{Float64, 4},
    no_markup_price_offers::Array{Float64, 4},
    thermal_unit_indexes_per_bus::Vector{Vector{Int}},
    number_of_risk_factors::Int,
    segment_offset_per_bus::Vector{Int},
)
    buses = index_of_elements(inputs, Bus)

    for bus in buses
        for (unit_idx, thermal_unit) in enumerate(thermal_unit_indexes_per_bus[bus])
            for risk_idx in 1:number_of_risk_factors
                segment = (unit_idx - 1) * number_of_risk_factors + risk_idx + segment_offset_per_bus[bus]
                # bg parameters
                segment_fraction = bidding_group_segment_fraction(inputs, bg_index)[risk_idx]
                risk_factor = bidding_group_risk_factor(inputs, bg_index)[risk_idx]
                for subperiod in 1:number_of_subperiods(inputs)
                    quantity_offers[bg_index, bus, segment, subperiod] =
                        thermal_unit_max_generation(inputs, thermal_unit) *
                        subperiod_duration_in_hours(inputs, subperiod) *
                        segment_fraction
                    price_offers[bg_index, bus, segment, subperiod] =
                        thermal_unit_om_cost(inputs, thermal_unit) * (1 + risk_factor)
                    no_markup_price_offers[bg_index, bus, segment, subperiod] =
                        thermal_unit_om_cost(inputs, thermal_unit)
                end
            end
        end
    end

    segment_offset_per_bus .+= length.(thermal_unit_indexes_per_bus) .* number_of_risk_factors

    return nothing
end

"""
    build_demand_offers!(
        inputs::Inputs, 
        bg_index::Int, 
        quantity_offers::Array{Float64, 4},
        price_offers::Array{Float64, 4},
        no_markup_price_offers::Array{Float64, 4},
        demand_unit_indexes_per_bus::Vector{Vector{Int}},
        number_of_risk_factors::Int,
        segment_offset_per_bus::Vector{Int},
    )

Build the quantity and price offers for demand units associated with a bidding group.
"""
function build_demand_offers!(
    inputs::Inputs,
    bg_index::Int,
    quantity_offers::Array{Float64, 4},
    price_offers::Array{Float64, 4},
    no_markup_price_offers::Array{Float64, 4},
    demand_unit_indexes_per_bus::Vector{Vector{Int}},
    number_of_risk_factors::Int,
    segment_offset_per_bus::Vector{Int},
    demand_series::Array{Float64, 2},
)
    buses = index_of_elements(inputs, Bus)

    for bus in buses
        for (unit_idx, demand_unit) in enumerate(demand_unit_indexes_per_bus[bus])
            # We use both demand_unit index to acess the demand series and elastic_demand_index to access the price series
            elastic_demand_index = index_among_elastic_demands(inputs, demand_unit)
            for risk_idx in 1:number_of_risk_factors
                segment = (unit_idx - 1) * number_of_risk_factors + risk_idx + segment_offset_per_bus[bus]
                # bg parameters
                segment_fraction = bidding_group_segment_fraction(inputs, bg_index)[risk_idx]
                risk_factor = bidding_group_risk_factor(inputs, bg_index)[risk_idx]
                for subperiod in 1:number_of_subperiods(inputs)
                    # demand is negative because it is a consumption
                    quantity_offers[bg_index, bus, segment, subperiod] =
                        demand_unit_max_demand(inputs, demand_unit) *
                        demand_series[demand_unit, subperiod] *
                        subperiod_duration_in_hours(inputs, subperiod) *
                        segment_fraction *
                        (-1)
                    price_offers[bg_index, bus, segment, subperiod] =
                        time_series_elastic_demand_price(inputs)[elastic_demand_index, subperiod] * (1 + risk_factor)
                    no_markup_price_offers[bg_index, bus, segment, subperiod] =
                        time_series_elastic_demand_price(inputs)[elastic_demand_index, subperiod]
                end
            end
        end
    end

    segment_offset_per_bus .+= length.(demand_unit_indexes_per_bus) .* number_of_risk_factors

    return nothing
end

"""
    build_renewable_offers(
        inputs::Inputs, 
        bg_index::Int, 
        renewable_unit_indexes::Vector{Int}, 
        number_of_risk_factors::Int
    )

Build the quantity and price offers for renewable units associated with a bidding group.
"""
function build_renewable_offers!(
    inputs::Inputs,
    bg_index::Int,
    quantity_offers::Array{Float64, 4},
    price_offers::Array{Float64, 4},
    no_markup_price_offers::Array{Float64, 4},
    renewable_unit_indexes_per_bus::Vector{Vector{Int}},
    number_of_risk_factors::Int,
    segment_offset_per_bus::Vector{Int},
    renewable_generation_series::Array{Float64, 2},
)
    buses = index_of_elements(inputs, Bus)

    for bus in buses
        for (unit_idx, renewable_unit) in enumerate(renewable_unit_indexes_per_bus[bus])
            for risk_idx in 1:number_of_risk_factors
                segment = (unit_idx - 1) * number_of_risk_factors + risk_idx + segment_offset_per_bus[bus]
                # bg parameters
                segment_fraction = bidding_group_segment_fraction(inputs, bg_index)[risk_idx]
                risk_factor = bidding_group_risk_factor(inputs, bg_index)[risk_idx]
                for subperiod in 1:number_of_subperiods(inputs)
                    quantity_offers[bg_index, bus, segment, subperiod] =
                        renewable_unit_max_generation(inputs, renewable_unit) *
                        renewable_generation_series[renewable_unit, subperiod] *
                        subperiod_duration_in_hours(inputs, subperiod) * segment_fraction
                    price_offers[bg_index, bus, segment, subperiod] =
                        renewable_unit_om_cost(inputs, renewable_unit) * (1 + risk_factor)
                    no_markup_price_offers[bg_index, bus, segment, subperiod] =
                        renewable_unit_om_cost(inputs, renewable_unit)
                end
            end
        end
    end

    segment_offset_per_bus .+= length.(renewable_unit_indexes_per_bus) .* number_of_risk_factors

    return quantity_offers, price_offers
end

"""
    build_hydro_offers!(
        inputs::Inputs, 
        bg_index::Int, 
        hydro_unit_indexes::Vector{Int}, 
        number_of_risk_factors::Int, 
        available_energy::Union{Vector{Float64}, Nothing}
    )

Build the quantity and price offers for hydro units associated with a bidding group.
"""
function build_hydro_offers!(
    inputs::Inputs,
    bg_index::Int,
    quantity_offers::Array{Float64, 4},
    price_offers::Array{Float64, 4},
    no_markup_price_offers::Array{Float64, 4},
    hydro_unit_indexes_per_bus::Vector{Vector{Int}},
    number_of_risk_factors::Int,
    segment_offset_per_bus::Vector{Int},
    available_energy::Union{Vector{Float64}, Nothing},
)
    buses = index_of_elements(inputs, Bus)

    for bus in buses
        for (unit_idx, hydro_unit) in enumerate(hydro_unit_indexes_per_bus[bus])
            for risk_idx in 1:number_of_risk_factors
                segment = (unit_idx - 1) * number_of_risk_factors + risk_idx + segment_offset_per_bus[bus]
                # bg parameters
                segment_fraction = bidding_group_segment_fraction(inputs, bg_index)[risk_idx]
                risk_factor = bidding_group_risk_factor(inputs, bg_index)[risk_idx]
                for subperiod in 1:number_of_subperiods(inputs)
                    quantity_offers[bg_index, bus, segment, subperiod] =
                        time_series_hydro_generation(inputs)[hydro_unit, subperiod] / MW_to_GW() * segment_fraction
                    price_offers[bg_index, bus, segment, subperiod] =
                        time_series_hydro_opportunity_cost(inputs)[hydro_unit, subperiod] * (1 + risk_factor)
                    no_markup_price_offers[bg_index, bus, segment, subperiod] =
                        time_series_hydro_opportunity_cost(inputs)[hydro_unit, subperiod]
                end
                # Adjust quantity offers based on available energy
                if isnothing(available_energy)
                    continue
                end
                available_energy_in_segment = available_energy[hydro_unit] * segment_fraction
                if available_energy_in_segment < sum(quantity_offers[bg_index, bus, segment, :])
                    adjusting_factor = available_energy_in_segment / sum(quantity_offers[bg_index, bus, segment, :])
                    quantity_offers[bg_index, bus, segment, :] .*= adjusting_factor
                end
            end
        end
    end

    segment_offset_per_bus .+= length.(hydro_unit_indexes_per_bus) .* number_of_risk_factors

    return nothing
end

"""
    hydro_available_energy(
        inputs::Inputs,
        run_time_options::RunTimeOptions,
        period::Int,
        scenario::Int
    )

Calculate the available energy for each hydro unit in a given period and scenario.
"""
function hydro_available_energy(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    period::Int,
    scenario::Int,
)
    hydro_units = index_of_elements(inputs, HydroUnit)
    existing_hydro_units = index_of_elements(inputs, HydroUnit; filters = [is_existing])
    inflow = time_series_inflow(inputs, run_time_options)

    available_water = zeros(length(hydro_units))
    total_inflow_in_period = zeros(length(hydro_units))
    for h in existing_hydro_units, blk in 1:number_of_subperiods(inputs)
        total_inflow_in_period[h] +=
            inflow[hydro_unit_gauging_station_index(inputs, h), blk] * m3_per_second_to_hm3_per_hour() *
            subperiod_duration_in_hours(inputs, blk)
    end
    available_water_ignoring_upstream_plants =
        hydro_volume_from_previous_period(inputs, period, scenario) .+ total_inflow_in_period

    for h in existing_hydro_units
        current_hydro = h
        # Sum 'available_water_ignoring_upstream_plants' of plant 'h' to 'available_water' in all its downstream plants
        while !is_null(current_hydro)
            available_water[current_hydro] += available_water_ignoring_upstream_plants[h]
            current_hydro = hydro_unit_turbine_to(inputs, current_hydro)
        end
    end

    available_energy = available_water ./ m3_per_second_to_hm3_per_hour() .* hydro_unit_production_factor(inputs)

    return available_energy
end

"""
    must_read_hydro_unit_data_for_markup_wizard(inputs::Inputs)

This function returns true when the following conditions are met:
1. The run mode is not TRAIN_MIN_COST
2. There is at least one hydro unit that is associated with a bidding group
"""
function must_read_hydro_unit_data_for_markup_wizard(inputs::Inputs)
    # Run mode
    if run_mode(inputs) == RunMode.TRAIN_MIN_COST || run_mode(inputs) == RunMode.MIN_COST
        return false
    end
    # Model type
    if run_mode(inputs) != RunMode.SINGLE_PERIOD_HEURISTIC_BID
        no_file_model_types = [
            Configurations_ConstructionType.SKIP,
            Configurations_ConstructionType.COST_BASED,
        ]
        if construction_type_ex_ante_physical(inputs) in no_file_model_types &&
           construction_type_ex_ante_commercial(inputs) in no_file_model_types &&
           construction_type_ex_post_physical(inputs) in no_file_model_types &&
           construction_type_ex_post_commercial(inputs) in no_file_model_types
            return false
        end
    end
    # Hydro representation
    if generate_heuristic_bids_for_clearing(inputs)
        if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
            return false
        elseif clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.PURE_BIDS
            bidding_group_indexes = index_of_elements(inputs, BiddingGroup)
            if isempty(bidding_group_indexes)
                return false
            end
            for hydro_unit in index_of_elements(inputs, HydroUnit)
                if hydro_unit_bidding_group_index(inputs, hydro_unit) in bidding_group_indexes
                    return true
                end
            end
        end
    else
        return false
    end

    return false
end

"""
    initialize_virtual_reservoir_bids_outputs(inputs::Inputs, outputs::Outputs, run_time_options::RunTimeOptions)

Initialize the output files for virtual reservoir energy and price offers.
"""
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
        dimensions = ["period", "scenario", "bid_segment"],
        unit = "MWh",
        labels,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        run_time_options,
        output_name = "virtual_reservoir_price_offer",
        dimensions = ["period", "scenario", "bid_segment"],
        unit = "\$/MWh",
        labels,
    )

    return nothing
end

"""
    virtual_reservoir_markup_offers_for_period_scenario(
        inputs::Inputs, 
        outputs::Outputs, 
        run_time_options::RunTimeOptions, 
        period::Int, 
        scenario::Int
    )

Generate heuristic bids for the virtual reservoirs and write them to the output files.
"""
function virtual_reservoir_markup_offers_for_period_scenario(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    period::Int,
    scenario::Int;
    outputs::Union{Outputs, Nothing} = nothing,
)
    accounts = virtual_reservoir_energy_account_from_previous_period(inputs, period, scenario)
    quantity_offer_reference_curve, price_offer_reference_curve =
        read_serialized_reference_curve(inputs, period, scenario)

    quantity_offers = zeros(
        number_of_elements(inputs, VirtualReservoir),
        number_of_elements(inputs, AssetOwner),
        maximum_number_of_vr_bidding_segments(inputs),
    )

    price_offers = zeros(
        number_of_elements(inputs, VirtualReservoir),
        number_of_elements(inputs, AssetOwner),
        maximum_number_of_vr_bidding_segments(inputs),
    )

    for vr in index_of_elements(inputs, VirtualReservoir)
        vr_total_account = sum(accounts[vr])
        vr_quantity_offer =
            [quantity_offer_reference_curve[seg][vr] for seg in eachindex(quantity_offer_reference_curve)]
        first_warning = false
        if vr_total_account - sum(vr_quantity_offer) > 1e-6
            @warn "Virtual reservoir $(vr) has a total account of $(vr_total_account) MWh, but the sum of the reference curve offers is $(sum(vr_quantity_offer)) MWh."
            first_warning = true
        end
        vr_price_offer = [price_offer_reference_curve[seg][vr] for seg in eachindex(price_offer_reference_curve)]
        @assert issorted(vr_price_offer)
        for (i, ao) in enumerate(virtual_reservoir_asset_owner_indices(inputs, vr))
            # The reference curve for the asset owner is proportional to the original reference curve, but scaled by the
            # share of the asset owner's account in the total account of the virtual reservoir.
            ao_reference_quantity_offer = vr_quantity_offer * accounts[vr][i] / vr_total_account

            seg = 0
            ao_quantity_offer = Float64[]
            ao_price_offer = Float64[]

            account_upper_bounds = asset_owner_virtual_reservoir_energy_account_upper_bound(inputs, ao)
            markups = asset_owner_risk_factor_for_virtual_reservoir_bids(inputs, ao)

            #---------------
            # Energy to sell
            #---------------
            current_account = accounts[vr][i]
            # There will be defined selling bids for the current asset owner until the resulting account is zero.
            current_reference_segment = 1
            sum_of_ao_selling_offers = 0.0
            # Assuming that this asset owner is the only one selling, the segment of the reference curve only changes when
            # the sum of offers for the current asset owner is greater than the sum of quantity offers until this segment.
            while current_account > 1e-6
                # In this iteration we define the quantity offer for the current markup, which is based on the account share of the
                # asset owner in the total account of the virtual reservoir. The calculation assumes that the total account of the
                # virtual reservoir is static, does not change according to the asset owner bids
                current_account_share = current_account / vr_total_account
                markup_index =
                    findfirst(i -> account_upper_bounds[i] >= current_account_share, 1:length(account_upper_bounds))
                account_share_lower_bound_for_markup = markup_index == 1 ? 0.0 : account_upper_bounds[markup_index-1]

                maximum_offer_considering_markup =
                    current_account - account_share_lower_bound_for_markup * vr_total_account

                # We have defined the quantity offer for the current markup. Now we split it considering the prices of the reference curve.
                sum_of_offers_for_current_markup = 0.0
                while sum_of_offers_for_current_markup < maximum_offer_considering_markup
                    maximum_offer_considering_reference =
                        sum(ao_reference_quantity_offer[1:current_reference_segment]) - sum_of_ao_selling_offers
                    if maximum_offer_considering_reference == 0
                        # This is possibly redundant with the end of this while loop
                        current_reference_segment += 1
                        continue
                    end

                    seg += 1
                    offer = min(
                        maximum_offer_considering_markup - sum_of_offers_for_current_markup,
                        maximum_offer_considering_reference,
                    )
                    quantity_offers[vr, ao, seg] = offer
                    price_offers[vr, ao, seg] = vr_price_offer[current_reference_segment] * (1 + markups[markup_index])

                    sum_of_offers_for_current_markup += offer
                    sum_of_ao_selling_offers += offer
                    current_account -= offer

                    if sum_of_ao_selling_offers >= sum(ao_reference_quantity_offer[1:current_reference_segment])
                        current_reference_segment += 1
                        if current_reference_segment > length(ao_reference_quantity_offer)
                            # We have reached the end of the reference curve, so we stop defining offers for this asset owner
                            if current_account > 1e-6
                                if !first_warning
                                    @warn "Reached the end of the reference curve for virtual reservoir $(vr) and asset owner $(ao) still has $(current_account) MWh to sell. This is likely due to numerical error."
                                end
                                current_account = 0 # break the external while loop
                            end
                            break
                        end
                    end
                end
            end

            #--------------
            # Energy to buy
            #--------------
            if consider_purchase_bids_for_virtual_reservoir_heuristic_bid(inputs)
                current_account = accounts[vr][i]
                # There will be defined buying bids for the current asset owner until the resulting account share is 1.
                while current_account < vr_total_account
                    current_account_share = current_account / vr_total_account
                    markup_index =
                        findfirst(i -> account_upper_bounds[i] > current_account_share, 1:length(account_upper_bounds))
                    account_share_upper_bound_for_markup = account_upper_bounds[markup_index]

                    seg += 1
                    offer = current_account - account_share_upper_bound_for_markup * vr_total_account
                    # Note that the offer is negative, because it is a bid to buy energy.
                    quantity_offers[vr, ao, seg] = offer
                    # The purchase price is based on the price of the first segment of the reference curve.
                    price_offers[vr, ao, seg] =
                        vr_price_offer[1] * (1 + markups[markup_index] - asset_owner_purchase_discount_rate(inputs, ao))

                    current_account -= offer
                end
            end
        end
    end

    serialize_virtual_reservoir_heuristic_bids(
        inputs,
        quantity_offers,
        price_offers;
        period,
        scenario,
    )

    if !isnothing(outputs)
        write_virtual_reservoir_bid_output(
            outputs,
            inputs,
            run_time_options,
            "virtual_reservoir_energy_offer",
            quantity_offers,
            period,
            scenario,
        )

        write_virtual_reservoir_bid_output(
            outputs,
            inputs,
            run_time_options,
            "virtual_reservoir_price_offer",
            price_offers,
            period,
            scenario,
        )
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
            bidding_group_bid_price_limit_not_justified_independent[idx] =
                reference_price * (1.0 + bid_price_limit_markup_non_justified_independent(inputs))
            bidding_group_bid_price_limit_justified_independent[idx] =
                reference_price * (1.0 + bid_price_limit_markup_justified_independent(inputs))
        end

        if has_any_profile_bids(inputs)
            bidding_group_bid_price_limit_not_justified_profile[idx] =
                reference_price * (1.0 + bid_price_limit_markup_non_justified_profile(inputs))
            bidding_group_bid_price_limit_justified_profile[idx] =
                reference_price * (1.0 + bid_price_limit_markup_justified_profile(inputs))
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

    return nothing
end

function calculate_maximum_valid_segments_or_profiles_per_timeseries(
    inputs::AbstractInputs,
    bids_view::Union{IARA.BidsView{Float64}, IARA.VirtualReservoirBidsView{Float64}};
    has_profile_bids::Bool = false,
    is_virtual_reservoir = false,
)
    dimension_dict = get_dimension_dict_from_reader(bids_view.reader)
    if is_virtual_reservoir
        virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
        number_elements = length(virtual_reservoirs)
    else
        bidding_groups = index_of_elements(inputs, BiddingGroup)
        number_elements = length(bidding_groups)
    end

    valid_segments_per_timeseries = zeros(Int, number_elements)

    if run_mode(inputs) == RunMode.STRATEGIC_BID ||
       run_mode(inputs) == RunMode.PRICE_TAKER_BID
        return ones(Int, number_elements)
    end

    # Check if the dimension of subperiod is 0
    if size(bids_view.data, 4) == 0
        return valid_segments_per_timeseries
    end

    if has_profile_bids
        segments = 1:dimension_dict[:profile]
    else
        segments = 1:dimension_dict[:bid_segment]
    end

    tol = 1e-6

    if is_virtual_reservoir
        for vr in 1:number_elements
            for segment in reverse(segments)
                if any(.!isapprox.(bids_view.data[vr, :, segment], 0.0; atol = tol))
                    valid_segments_per_timeseries[vr] = segment
                    break
                end
            end
        end
    else
        for bg in 1:number_elements
            for segment in reverse(segments)
                if any(.!isapprox.(bids_view.data[bg, :, segment, :], 0.0; atol = tol))
                    valid_segments_per_timeseries[bg] = segment
                    break
                end
            end
        end
    end

    return valid_segments_per_timeseries
end

function generate_individual_bids_files(inputs::AbstractInputs)
    period_suffix = "_period_$(inputs.args.period)"

    quantity_file = joinpath(
        output_path(inputs),
        "bidding_group_energy_offer" * period_suffix,
    )
    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    initialize_bids_view_from_external_file!(
        inputs.time_series.quantity_offer,
        inputs,
        quantity_file;
        expected_unit = "MWh",
        possible_expected_dimensions = [
            [:period, :scenario, :subperiod, :bid_segment],
        ],
        bidding_groups_to_read = bidding_group_label(inputs)[bidding_groups],
        buses_to_read = bus_label(inputs),
    )

    price_file = joinpath(
        output_path(inputs),
        "bidding_group_price_offer" * period_suffix,
    )
    initialize_bids_view_from_external_file!(
        inputs.time_series.price_offer,
        inputs,
        price_file;
        expected_unit = raw"$/MWh",
        possible_expected_dimensions = [
            [:period, :scenario, :subperiod, :bid_segment],
        ],
        bidding_groups_to_read = bidding_group_label(inputs)[bidding_groups],
        buses_to_read = bus_label(inputs),
    )

    no_markup_price_file = joinpath(
        output_path(inputs),
        "bidding_group_no_markup_price_offer" * period_suffix,
    )
    initialize_bids_view_from_external_file!(
        inputs.time_series.no_markup_price_offer,
        inputs,
        no_markup_price_file;
        expected_unit = raw"$/MWh",
        possible_expected_dimensions = [
            [:period, :scenario, :subperiod, :bid_segment],
        ],
        bidding_groups_to_read = bidding_group_label(inputs)[bidding_groups],
        buses_to_read = bus_label(inputs),
    )

    for asset_owner_index in index_of_elements(inputs, AssetOwner)
        write_individual_bids_files(inputs, asset_owner_index; use_no_markup_price = false)
        write_individual_bids_files(inputs, asset_owner_index; use_no_markup_price = true)
    end
end

function write_individual_bids_files(
    inputs::AbstractInputs,
    asset_owner_index::Int;
    use_no_markup_price::Bool = false,
)
    bidding_groups = index_of_elements(inputs, BiddingGroup)
    buses = index_of_elements(inputs, Bus)

    price_data = if use_no_markup_price
        inputs.time_series.no_markup_price_offer
    else
        inputs.time_series.price_offer
    end

    bidding_group_indexes_to_read = findall(isequal(asset_owner_index), bidding_group_asset_owner_index(inputs))

    filename = if use_no_markup_price
        "$(asset_owner_label(inputs, asset_owner_index))_no_markup_bids_period_$(inputs.args.period).csv"
    else
        "$(asset_owner_label(inputs, asset_owner_index))_bids_period_$(inputs.args.period).csv"
    end

    df_length =
        length(bidding_group_indexes_to_read) * length(buses) * number_of_subperiods(inputs) *
        number_of_scenarios(inputs) * maximum_number_of_bg_bidding_segments(inputs)

    period_column = ones(Int, df_length) * inputs.args.period
    scenario_column = zeros(Int, df_length)
    subperiod_column = zeros(Int, df_length)
    bid_segment_column = zeros(Int, df_length)
    bus_column = Vector{String}(undef, df_length)
    bidding_group_column = Vector{String}(undef, df_length)
    price_column = zeros(df_length)
    quantity_column = zeros(df_length)

    line_index = 0
    for scenario in 1:number_of_scenarios(inputs)
        # Update the time series in the external files to the current period and scenario
        read_bids_view_from_external_file!(
            inputs,
            inputs.time_series.quantity_offer;
            period = 1,
            scenario,
            has_profile_bids = false,
        )
        read_bids_view_from_external_file!(
            inputs,
            price_data;
            period = 1,
            scenario,
            has_profile_bids = false,
        )

        for subperiod in 1:number_of_subperiods(inputs), segment in 1:maximum_number_of_bg_bidding_segments(inputs)
            for bg in bidding_groups, bus in buses
                if bg in bidding_group_indexes_to_read
                    line_index += 1
                    scenario_column[line_index] = scenario
                    subperiod_column[line_index] = subperiod
                    bid_segment_column[line_index] = segment
                    bus_column[line_index] = bus_label(inputs, bus)
                    bidding_group_column[line_index] = bidding_group_label(inputs, bg)
                    price_column[line_index] = price_data[bg, bus, segment, subperiod]
                    quantity_column[line_index] = inputs.time_series.quantity_offer[bg, bus, segment, subperiod]
                end
            end
        end
    end

    df = DataFrame(;
        period = period_column,
        scenario = scenario_column,
        subperiod = subperiod_column,
        bid_segment = bid_segment_column,
        bus = bus_column,
        bidding_group = bidding_group_column,
        price = price_column,
        quantity = quantity_column,
    )

    CSV.write(joinpath(output_path(inputs), filename), df)

    return nothing
end

function generate_individual_virtual_reservoir_bids_files(inputs::AbstractInputs)
    period_suffix = "_period_$(inputs.args.period)"

    # Virtual reservoir files
    virtual_reservoir_quantity_file = joinpath(
        output_path(inputs),
        "virtual_reservoir_energy_offer" * period_suffix,
    )
    initialize_virtual_reservoir_bids_view_from_external_file!(
        inputs.time_series.virtual_reservoir_quantity_offer,
        inputs,
        virtual_reservoir_quantity_file;
        expected_unit = "MWh",
        possible_expected_dimensions = [
            [:period, :scenario, :bid_segment],
        ],
        virtual_reservoirs_to_read = virtual_reservoir_label(inputs),
        asset_owners_to_read = asset_owner_label(inputs),
    )
    virtual_reservoir_price_file = joinpath(
        output_path(inputs),
        "virtual_reservoir_price_offer" * period_suffix,
    )
    initialize_virtual_reservoir_bids_view_from_external_file!(
        inputs.time_series.virtual_reservoir_price_offer,
        inputs,
        virtual_reservoir_price_file;
        expected_unit = raw"$/MWh",
        possible_expected_dimensions = [
            [:period, :scenario, :bid_segment],
        ],
        virtual_reservoirs_to_read = virtual_reservoir_label(inputs),
        asset_owners_to_read = asset_owner_label(inputs),
    )

    for asset_owner_index in index_of_elements(inputs, AssetOwner)
        write_individual_virtual_reservoir_bids_files(inputs, asset_owner_index)
    end
end

function write_individual_virtual_reservoir_bids_files(
    inputs::AbstractInputs,
    asset_owner_index::Int,
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    filename = "$(asset_owner_label(inputs, asset_owner_index))_virtual_reservoir_bids_period_$(inputs.args.period).csv"

    df_length = length(virtual_reservoirs) * number_of_scenarios(inputs) * maximum_number_of_vr_bidding_segments(inputs)

    period_column = ones(Int, df_length) * inputs.args.period
    scenario_column = zeros(Int, df_length)
    bid_segment_column = zeros(Int, df_length)
    virtual_reservoir_column = Vector{String}(undef, df_length)
    price_column = zeros(df_length)
    quantity_column = zeros(df_length)

    line_index = 0
    for scenario in 1:number_of_scenarios(inputs)
        # Update the time series in the external files to the current period and scenario
        read_virtual_reservoir_bids_view_from_external_file!(
            inputs,
            inputs.time_series.virtual_reservoir_quantity_offer;
            period = 1,
            scenario,
        )
        read_virtual_reservoir_bids_view_from_external_file!(
            inputs,
            inputs.time_series.virtual_reservoir_price_offer;
            period = 1,
            scenario,
        )

        for segment in 1:maximum_number_of_vr_bidding_segments(inputs)
            for vr in virtual_reservoirs
                line_index += 1
                scenario_column[line_index] = scenario
                bid_segment_column[line_index] = segment
                virtual_reservoir_column[line_index] = virtual_reservoir_label(inputs, vr)
                price_column[line_index] =
                    inputs.time_series.virtual_reservoir_price_offer[vr, asset_owner_index, segment]
                quantity_column[line_index] =
                    inputs.time_series.virtual_reservoir_quantity_offer[vr, asset_owner_index, segment]
            end
        end
    end

    df = DataFrame(;
        period = period_column,
        scenario = scenario_column,
        bid_segment = bid_segment_column,
        virtual_reservoir = virtual_reservoir_column,
        price = price_column,
        quantity = quantity_column,
    )

    CSV.write(joinpath(output_path(inputs), filename), df)

    return nothing
end

function adjust_quantity_offer_for_ex_post!(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    quantity_offer_series::IARA.BidsView{Float64},
    subscenario::Int,
)
    if !is_market_clearing(inputs) || is_ex_ante_problem(run_time_options) || !read_ex_post_renewable_file(inputs) ||
       maximum_number_of_bg_bidding_segments(inputs) == 0
        return nothing
    end

    bidding_group_indexes = index_of_elements(inputs, BiddingGroup)

    for bg in bidding_group_indexes
        for bus in 1:number_of_elements(inputs, Bus)
            for bds in 1:number_of_bg_valid_bidding_segments(inputs, bg)
                for blk in subperiods(inputs)
                    # Set the clearing model subproblem to ex_ante or ex_post to calculate the energy upper bound
                    run_time_options =
                        RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_ANTE_PHYSICAL)
                    total_energy_ex_ante = sum_units_energy_ub_per_bg(
                        inputs,
                        run_time_options,
                        bg,
                        bus,
                        blk,
                        subscenario,
                    )
                    total_demand_ex_ante = sum_demand_per_bg(
                        inputs,
                        run_time_options,
                        bg,
                        bus,
                        blk,
                        subscenario,
                    )
                    run_time_options =
                        RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_POST_PHYSICAL)
                    total_energy_ex_post = sum_units_energy_ub_per_bg(
                        inputs,
                        run_time_options,
                        bg,
                        bus,
                        blk,
                        subscenario,
                    )
                    total_demand_ex_post = sum_demand_per_bg(
                        inputs,
                        run_time_options,
                        bg,
                        bus,
                        blk,
                        subscenario,
                    )
                    if quantity_offer_series.data[bg, bus, bds, blk] > 0.0
                        if total_energy_ex_ante == 0.0
                            quantity_offer_series.data[bg, bus, bds, blk] = 0.0
                        else
                            quantity_offer_series.data[bg, bus, bds, blk] *=
                                total_energy_ex_post / total_energy_ex_ante
                        end
                    elseif quantity_offer_series.data[bg, bus, bds, blk] < 0.0
                        if total_demand_ex_ante == 0.0
                            quantity_offer_series.data[bg, bus, bds, blk] = 0.0
                        else
                            quantity_offer_series.data[bg, bus, bds, blk] *=
                                total_demand_ex_post / total_demand_ex_ante
                        end
                    end
                end
            end
        end
    end

    return nothing
end

function sum_units_energy_ub_per_bg(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    bg::Int,
    bus::Int,
    subperiod::Int,
    subscenario::Int;
)
    thermal_units = index_of_elements(inputs, ThermalUnit; run_time_options, filters = [is_existing])
    renewable_units = index_of_elements(inputs, RenewableUnit; run_time_options, filters = [is_existing])
    battery_units = index_of_elements(inputs, BatteryUnit; run_time_options, filters = [is_existing])
    hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])

    thermal_energy_ub = sum(
        thermal_unit_max_generation(inputs, t) *
        subperiod_duration_in_hours(inputs, subperiod) for t in thermal_units
        if thermal_unit_bus_index(inputs, t) == bus &&
        thermal_unit_bidding_group_index(inputs, t) == bg;
        init = 0.0,
    )

    renewable_energy_ub = sum(
        renewable_unit_max_generation(inputs, r) * subperiod_duration_in_hours(inputs, subperiod) *
        time_series_renewable_generation(inputs, run_time_options; subscenario)[r, subperiod]
        for r in renewable_units
        if renewable_unit_bus_index(inputs, r) == bus &&
        renewable_unit_bidding_group_index(inputs, r) == bg;
        init = 0.0,
    )

    battery_energy_ub = sum(
        battery_unit_max_capacity(inputs, b) *
        subperiod_duration_in_hours(inputs, subperiod) for b in battery_units
        if battery_unit_bus_index(inputs, b) == bus &&
        battery_unit_bidding_group_index(inputs, b) == bg;
        init = 0.0,
    )

    # TODO: Implement hydro energy upper bound
    hydro_energy_ub = 0.0

    return thermal_energy_ub + renewable_energy_ub + battery_energy_ub + hydro_energy_ub
end

function sum_demand_per_bg(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    bg::Int,
    bus::Int,
    subperiod::Int,
    subscenario::Int;
)
    demand_units = index_of_elements(inputs, DemandUnit; run_time_options, filters = [is_existing])

    total_demand =
        -sum(
            demand_unit_max_demand(inputs, d) * subperiod_duration_in_hours(inputs, subperiod) *
            time_series_demand(inputs, run_time_options; subscenario)[d, subperiod]
            for d in demand_units
            if demand_unit_bus_index(inputs, d) == bus &&
            demand_unit_bidding_group_index(inputs, d) == bg;
            init = 0.0,
        )

    return total_demand
end

function update_number_of_segments_for_heuristic_bids!(inputs::Inputs)
    if generate_heuristic_bids_for_clearing(inputs)
        number_of_bg_offer_segments = number_of_bidding_group_offer_segments_for_heuristic_bids(inputs)
        update_number_of_bg_valid_bidding_segments!(inputs, number_of_bg_offer_segments)
        maximum_number_of_bg_offer_segments = maximum(number_of_bg_offer_segments; init = 0)
        update_maximum_number_of_bg_bidding_segments!(inputs, maximum_number_of_bg_offer_segments)

        number_of_vr_offer_segments = number_of_virtual_reservoir_offer_segments_for_heuristic_bids(inputs)
        update_number_of_vr_valid_bidding_segments!(inputs, number_of_vr_offer_segments)
        maximum_number_of_vr_offer_segments = maximum(number_of_vr_offer_segments; init = 0)
        update_maximum_number_of_vr_bidding_segments!(inputs, maximum_number_of_vr_offer_segments)

        @info("Heuristic bids")
        @info("   Number of bidding group segments: $maximum_number_of_bg_offer_segments")
        @info("   Number of virtual reservoir segments: $maximum_number_of_vr_offer_segments")
        @info("")
    end
    return nothing
end
