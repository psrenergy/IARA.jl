#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function _get_generation_unit(file_path::String)
    unit_name = match(r"^([a-z]+)_.*\.csv$", basename(file_path))
    if unit_name[1] == "thermal"
        return "ThermalUnit"
    elseif unit_name[1] == "hydro"
        return "HydroUnit"
    elseif unit_name[1] == "battery_unit"
        return "BatteryUnit"
    elseif unit_name[1] == "renewable"
        return "RenewableUnit"
    end
end

function _get_bidding_group_bus_index(bg_index::Int, bus_index::Int)
    return (bg_index - 1) * bus_index + bus_index
end

function _get_bidding_group_bus_labels(inputs::Inputs)
    bus_labels = PSRI.get_parms(inputs.db, "Bus", "label")
    bidding_group_labels = PSRI.get_parms(inputs.db, "BiddingGroup", "label")
    labels = Vector{String}()
    for bg_label in bidding_group_labels
        for bus_label in bus_labels
            push!(labels, bg_label * " - " * bus_label)
        end
    end
    return labels
end

function _write_ex_ante_file(inputs::Inputs, extension::String)
    outputs_dir = output_path(inputs)

    num_bidding_groups = PSRI.max_elements(inputs.db, "BiddingGroup")
    num_buses = PSRI.max_elements(inputs.db, "Bus")

    ex_ante_files = filter(x -> endswith(x, "_generation_ex_ante_$(extension).csv"), readdir(outputs_dir))
    if isempty(ex_ante_files)
        return
    end
    bidding_group_ex_ante = nothing
    initial_date_time = nothing
    unit = nothing
    for file in ex_ante_files
        generation_data, generation_metadata = read_timeseries_file(joinpath(outputs_dir, file))

        num_periods = size(generation_data, 4)
        num_scenarios = size(generation_data, 3)
        num_subperiods = size(generation_data, 2)
        num_units = size(generation_data, 1)

        if isnothing(bidding_group_ex_ante)
            bidding_group_ex_ante = zeros(
                num_bidding_groups * num_buses,
                1, # bid segments
                num_subperiods,
                num_scenarios,
                num_periods,
            )
            initial_date_time = generation_metadata.initial_date
            unit = generation_metadata.unit
        end

        unit_collection = _get_generation_unit(file)
        if isnothing(unit_collection)
            continue
        end

        bg_relation_mapping = PSRI.get_map(inputs.db, unit_collection, "BiddingGroup", "id")
        bus_relation_mapping = PSRI.get_map(inputs.db, unit_collection, "Bus", "id")

        for period in 1:num_periods
            for scenario in 1:num_scenarios
                for subperiod in 1:num_subperiods
                    for unit in 1:num_units
                        bidding_group_index = bg_relation_mapping[unit]
                        bus_index = bus_relation_mapping[unit]
                        if is_null(bidding_group_index) || is_null(bus_index)
                            continue
                        end
                        bidding_group_bus_index = _get_bidding_group_bus_index(bidding_group_index, bus_index)
                        bidding_group_ex_ante[bidding_group_bus_index, 1, subperiod, scenario, period] +=
                            generation_data[unit, subperiod, scenario, period]
                    end
                end
            end
        end
    end
    write_timeseries_file(
        joinpath(outputs_dir, "bidding_group_generation_ex_ante_$(extension)_cost_based"),
        bidding_group_ex_ante;
        dimensions = ["period", "scenario", "subperiod", "bid_segment"],
        labels = _get_bidding_group_bus_labels(inputs),
        time_dimension = "period",
        dimension_size = [
            size(bidding_group_ex_ante, 5),
            size(bidding_group_ex_ante, 4),
            size(bidding_group_ex_ante, 3),
            1,
        ],
        initial_date = initial_date_time,
        unit = unit,
    )
    return
end

function _write_ex_post_file(inputs::Inputs, extension::String)
    outputs_dir = output_path(inputs)

    num_bidding_groups = PSRI.max_elements(inputs.db, "BiddingGroup")
    num_buses = PSRI.max_elements(inputs.db, "Bus")

    ex_post_files = filter(x -> endswith(x, "_generation_ex_post_$(extension).csv"), readdir(outputs_dir))
    if isempty(ex_post_files)
        return
    end
    bidding_group_ex_post = nothing
    initial_date_time = nothing
    unit = nothing
    for file in ex_post_files
        generation_data, generation_metadata = read_timeseries_file(joinpath(outputs_dir, file))

        num_periods = size(generation_data, 5)
        num_scenarios = size(generation_data, 4)
        num_subscenarios = size(generation_data, 3)
        num_subperiods = size(generation_data, 2)
        num_units = size(generation_data, 1)

        if isnothing(bidding_group_ex_post)
            bidding_group_ex_post = zeros(
                num_bidding_groups * num_buses,
                1, # bid segments
                num_subperiods,
                num_subscenarios,
                num_scenarios,
                num_periods,
            )
            initial_date_time = generation_metadata.initial_date
            unit = generation_metadata.unit
        end

        unit_collection = _get_generation_unit(file)

        bg_relation_mapping = PSRI.get_map(inputs.db, unit_collection, "BiddingGroup", "id")
        bus_relation_mapping = PSRI.get_map(inputs.db, unit_collection, "Bus", "id")

        for period in 1:num_periods
            for scenario in 1:num_scenarios
                for subscenario in 1:num_subscenarios
                    for subperiod in 1:num_subperiods
                        for unit in 1:num_units
                            bidding_group_index = bg_relation_mapping[unit]
                            bus_index = bus_relation_mapping[unit]
                            if is_null(bidding_group_index) || is_null(bus_index)
                                continue
                            end
                            bidding_group_bus_index = _get_bidding_group_bus_index(bidding_group_index, bus_index)
                            bidding_group_ex_post[
                                bidding_group_bus_index,
                                1,
                                subperiod,
                                subscenario,
                                scenario,
                                period,
                            ] +=
                                generation_data[unit, subperiod, subscenario, scenario, period]
                        end
                    end
                end
            end
        end
    end
    write_timeseries_file(
        joinpath(outputs_dir, "bidding_group_generation_ex_post_$(extension)_cost_based"),
        bidding_group_ex_post;
        dimensions = ["period", "scenario", "subscenario", "subperiod", "bid_segment"],
        labels = _get_bidding_group_bus_labels(inputs),
        time_dimension = "period",
        dimension_size = [
            size(bidding_group_ex_post, 6),
            size(bidding_group_ex_post, 5),
            size(bidding_group_ex_post, 4),
            size(bidding_group_ex_post, 3),
            1,
        ],
        initial_date = initial_date_time,
        unit = unit,
    )
    return
end

"""
    create_bidding_group_generation_files(inputs::Inputs)

Create the bidding group generation files for ex-ante and ex-post data (physical and commercial).
"""
function create_bidding_group_generation_files(inputs::Inputs)
    outputs_dir = output_path(inputs)

    num_bidding_groups = PSRI.max_elements(inputs.db, "BiddingGroup")

    if num_bidding_groups == 0
        return
    end

    bidding_group_generation_files = filter(x -> occursin(r"bidding_group_generation_.*\.csv", x), readdir(outputs_dir))

    if !isempty(bidding_group_generation_files)
        return
    end

    _write_ex_ante_file(inputs, "commercial")
    _write_ex_ante_file(inputs, "physical")
    _write_ex_post_file(inputs, "commercial")
    _write_ex_post_file(inputs, "physical")

    return
end
