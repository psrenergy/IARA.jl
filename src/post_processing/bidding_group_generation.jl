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

function _get_bidding_group_bus_index(bg_index::Int, bus_index::Int, number_of_buses::Int)
    return (bg_index - 1) * number_of_buses + bus_index
end

function _get_bidding_group_bus_labels(inputs::Inputs)
    bus_labels = bus_label(inputs)
    bidding_group_labels = bidding_group_label(inputs)
    labels = Vector{String}()
    for bg_label in bidding_group_labels
        for bus_label in bus_labels
            push!(labels, bg_label * " - " * bus_label)
        end
    end
    return labels
end

function _write_generation_bg_file(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::TimeSeriesOutputs,
    run_time_options::RunTimeOptions,
    extension::String;
    is_ex_post = false,
    write_generation = false,
)
    outputs_dir = output_path(inputs)

    num_bidding_groups = length(inputs.collections.bidding_group)
    num_buses = length(inputs.collections.bus)
    num_bidding_groups * num_buses

    settlement_string = is_ex_post ? "ex_post" : "ex_ante"
    generation_files =
        filter(x -> endswith(x, "_generation_$(settlement_string)_$(extension).csv"), readdir(outputs_dir))
    if isempty(generation_files)
        return
    end
    bidding_group_ex_ante = nothing
    initial_date_time = nothing
    unit = nothing

    number_of_bid_segments = maximum_number_of_bidding_segments(inputs)
    # Set number of bidding segments to 1 to add the cost based generation only in the first segment
    update_number_of_bid_segments!(inputs, 1)

    if is_ex_post
        dimensions = ["period", "scenario", "subscenario", "subperiod", "bid_segment"]
    else
        dimensions = ["period", "scenario", "subperiod", "bid_segment"]
    end

    if write_generation
        initialize!(
            QuiverOutput,
            outputs_post_processing;
            inputs,
            output_name = "bidding_group_generation_$(settlement_string)_$(extension)",
            dimensions = dimensions,
            unit = "GWh",
            labels = _get_bidding_group_bus_labels(inputs),
            run_time_options,
            is_post_processing = true,
        )
    end

    update_number_of_bid_segments!(inputs, number_of_bid_segments)

    bidding_group_generation_writer =
        get_writer(outputs_post_processing, "bidding_group_generation_$(settlement_string)_$(extension)")
    generation_readers = Dict{String, Quiver.Reader{Quiver.csv}}()
    bg_relations_mapping = Dict{String, Vector{Int}}()
    bus_relations_mapping = Dict{String, Vector{Int}}()
    for file in generation_files
        if isfile(joinpath(outputs_dir, file))
            generation_readers[file] = open_time_series_output(inputs, model_outputs_time_serie, get_filename(file))
            bg_relations_mapping[file] = PSRI.get_map(inputs.db, _get_generation_unit(file), "BiddingGroup", "id")
            bus_relations_mapping[file] = PSRI.get_map(inputs.db, _get_generation_unit(file), "Bus", "id")
        end
    end

    for period in periods(inputs)
        for scenario in scenarios(inputs)
            if is_ex_post
                for subscenario in subscenarios(inputs, run_time_options)
                    for subperiod in subperiods(inputs)
                        bidding_group_generation = zeros(num_bidding_groups * num_buses)
                        for (filename, reader) in generation_readers
                            Quiver.goto!(reader; period, scenario, subscenario = subscenario, subperiod = subperiod)
                            labels = reader.metadata.labels
                            num_units = length(labels)

                            bg_relation_mapping = bg_relations_mapping[filename]
                            bus_relation_mapping = bus_relations_mapping[filename]

                            for unit in 1:num_units
                                bidding_group_index = bg_relation_mapping[unit]
                                bus_index = bus_relation_mapping[unit]
                                if is_null(bidding_group_index) || is_null(bus_index)
                                    continue
                                end
                                bidding_group_bus_index =
                                    _get_bidding_group_bus_index(bidding_group_index, bus_index, num_buses)
                                bidding_group_generation[bidding_group_bus_index] += reader.data[unit]
                            end
                        end
                        if write_generation
                            Quiver.write!(
                                bidding_group_generation_writer,
                                bidding_group_generation;
                                period,
                                scenario,
                                subscenario,
                                subperiod = subperiod,
                                bid_segment = 1,
                            )
                        end
                    end
                end
            else
                for subperiod in subperiods(inputs)
                    bidding_group_generation = zeros(num_bidding_groups * num_buses)
                    for (filename, reader) in generation_readers
                        Quiver.goto!(reader; period, scenario, subperiod = subperiod)
                        labels = reader.metadata.labels
                        num_units = length(labels)

                        bg_relation_mapping = bg_relations_mapping[filename]
                        bus_relation_mapping = bus_relations_mapping[filename]

                        for unit in 1:num_units
                            bidding_group_index = bg_relation_mapping[unit]
                            bus_index = bus_relation_mapping[unit]
                            if is_null(bidding_group_index) || is_null(bus_index)
                                continue
                            end
                            bidding_group_bus_index =
                                _get_bidding_group_bus_index(bidding_group_index, bus_index, num_buses)
                            bidding_group_generation[bidding_group_bus_index] +=
                                reader.data[unit]
                        end
                    end
                    if write_generation
                        Quiver.write!(
                            bidding_group_generation_writer,
                            bidding_group_generation;
                            period,
                            scenario,
                            subperiod = subperiod,
                            bid_segment = 1,
                        )
                    end
                end
            end
        end
    end

    return
end

"""
    create_bidding_group_generation_files(inputs::Inputs, outputs_post_processing::Outputs, model_outputs_time_serie::TimeSeriesOutputs, run_time_options::RunTimeOptions)

Create the bidding group generation files for ex-ante and ex-post data (physical and commercial).
"""
function create_bidding_group_generation_files(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::TimeSeriesOutputs,
    run_time_options::RunTimeOptions,
)
    outputs_dir = output_path(inputs)

    num_bidding_groups = length(inputs.collections.bidding_group)

    if num_bidding_groups == 0
        return
    end

    bidding_group_generation_files = filter(x -> occursin(r"bidding_group_generation_.*\.csv", x), readdir(outputs_dir))

    if !isempty(bidding_group_generation_files)
        return
    end

    write_generation_ex_physical =
        construction_type_ex_ante_physical(inputs) == Configurations_ConstructionType.COST_BASED
    write_generation_ex_commercial =
        construction_type_ex_ante_commercial(inputs) == Configurations_ConstructionType.COST_BASED
    write_generation_ex_post_physical =
        construction_type_ex_post_physical(inputs) == Configurations_ConstructionType.COST_BASED
    write_generation_ex_post_commercial =
        construction_type_ex_post_commercial(inputs) == Configurations_ConstructionType.COST_BASED

    _write_generation_bg_file(
        inputs,
        outputs_post_processing,
        model_outputs_time_serie,
        run_time_options,
        "physical";
        is_ex_post = false,
        write_generation = write_generation_ex_physical,
    )
    _write_generation_bg_file(
        inputs,
        outputs_post_processing,
        model_outputs_time_serie,
        run_time_options,
        "commercial";
        is_ex_post = false,
        write_generation = write_generation_ex_commercial,
    )
    _write_generation_bg_file(
        inputs,
        outputs_post_processing,
        model_outputs_time_serie,
        run_time_options,
        "physical";
        is_ex_post = true,
        write_generation = write_generation_ex_post_physical,
    )
    _write_generation_bg_file(
        inputs,
        outputs_post_processing,
        model_outputs_time_serie,
        run_time_options,
        "commercial";
        is_ex_post = true,
        write_generation = write_generation_ex_post_commercial,
    )

    return
end
