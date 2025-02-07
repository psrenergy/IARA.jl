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

function _write_generation_costs_bg_file(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::TimeSeriesOutputs,
    run_time_options::RunTimeOptions,
    clearing_procedure::String;
    is_ex_post = false,
    write_generation = false,
)
    outputs_dir = output_path(inputs)
    post_processing_dir = post_processing_path(inputs)

    num_bidding_groups = length(inputs.collections.bidding_group)
    num_buses = length(inputs.collections.bus)
    num_bidding_groups * num_buses

    generation_technologies = ["thermal", "hydro", "renewable", "battery"]

    file_end = "_generation_$(clearing_procedure)"
    if is_single_period(inputs)
        file_end *= "_period_$(inputs.args.period)"
    end
    file_end *= ".csv"
    generation_files =
        filter(x -> endswith(x, file_end), readdir(outputs_dir))
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
            output_name = "bidding_group_generation_$(clearing_procedure)",
            dimensions = dimensions,
            unit = "GWh",
            labels = _get_bidding_group_bus_labels(inputs),
            run_time_options,
            dir_path = post_processing_dir,
        )
        bidding_group_generation_writer =
            get_writer(outputs_post_processing, "bidding_group_generation_$(clearing_procedure)")
    end

    initialize!(
        QuiverOutput,
        outputs_post_processing;
        inputs,
        output_name = "bidding_group_costs_$(clearing_procedure)",
        # Remove bid_segment dimension for costs
        dimensions = dimensions[1:end-1],
        unit = "\$",
        labels = _get_bidding_group_bus_labels(inputs),
        run_time_options,
        dir_path = post_processing_dir,
    )

    bidding_group_costs_writer =
        get_writer(outputs_post_processing, "bidding_group_costs_$(clearing_procedure)")

    update_number_of_bid_segments!(inputs, number_of_bid_segments)

    generation_readers = Dict{String, Quiver.Reader{Quiver.csv}}()
    total_costs_readers = Dict{String, Quiver.Reader{Quiver.csv}}()
    bg_relations_mapping = Dict{String, Vector{Int}}()
    bus_relations_mapping = Dict{String, Vector{Int}}()
    for generation_technology in generation_technologies
        generation_file, costs_file = get_generation_and_costs_files(inputs, clearing_procedure, generation_technology)
        if isnothing(generation_file) || isnothing(costs_file)
            continue
        end
        generation_readers[generation_technology] =
            open_time_series_output(inputs, model_outputs_time_serie, joinpath(outputs_dir, get_filename(generation_file)))
        total_costs_readers[generation_technology] = open_time_series_output(
            inputs,
            model_outputs_time_serie,
            joinpath(post_processing_dir, get_filename(costs_file))
        )
        bg_relations_mapping[generation_technology] =
            PSRI.get_map(inputs.db, _get_generation_unit(generation_file), "BiddingGroup", "id")
        bus_relations_mapping[generation_technology] =
            PSRI.get_map(inputs.db, _get_generation_unit(generation_file), "Bus", "id")
    end

    for period in periods(inputs)
        for scenario in scenarios(inputs)
            if is_ex_post
                for subscenario in subscenarios(inputs, run_time_options)
                    for subperiod in subperiods(inputs)
                        bidding_group_generation = zeros(num_bidding_groups * num_buses)
                        bidding_group_costs = zeros(num_bidding_groups * num_buses)
                        for generation_technology in keys(generation_readers)
                            generation_reader = generation_readers[generation_technology]
                            costs_reader = total_costs_readers[generation_technology]
                            Quiver.goto!(
                                generation_reader;
                                period,
                                scenario,
                                subscenario = subscenario,
                                subperiod = subperiod,
                            )
                            Quiver.goto!(
                                costs_reader;
                                period,
                                scenario,
                                subscenario = subscenario,
                                subperiod = subperiod,
                            )
                            labels = generation_reader.metadata.labels
                            num_units = length(labels)

                            bg_relation_mapping = bg_relations_mapping[generation_technology]
                            bus_relation_mapping = bus_relations_mapping[generation_technology]

                            for unit in 1:num_units
                                bidding_group_index = bg_relation_mapping[unit]
                                bus_index = bus_relation_mapping[unit]
                                if is_null(bidding_group_index) || is_null(bus_index)
                                    continue
                                end
                                bidding_group_bus_index =
                                    _get_bidding_group_bus_index(bidding_group_index, bus_index, num_buses)
                                bidding_group_generation[bidding_group_bus_index] += generation_reader.data[unit]
                                bidding_group_costs[bidding_group_bus_index] += costs_reader.data[unit]
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
                        Quiver.write!(
                            bidding_group_costs_writer,
                            bidding_group_costs;
                            period,
                            scenario,
                            subscenario,
                            subperiod = subperiod,
                        )
                    end
                end
            else
                for subperiod in subperiods(inputs)
                    bidding_group_generation = zeros(num_bidding_groups * num_buses)
                    bidding_group_costs = zeros(num_bidding_groups * num_buses)
                    for generation_technology in keys(generation_readers)
                        generation_reader = generation_readers[generation_technology]
                        costs_reader = total_costs_readers[generation_technology]
                        Quiver.goto!(generation_reader; period, scenario, subperiod = subperiod)
                        Quiver.goto!(costs_reader; period, scenario, subperiod = subperiod)
                        labels = generation_reader.metadata.labels
                        num_units = length(labels)

                        bg_relation_mapping = bg_relations_mapping[generation_technology]
                        bus_relation_mapping = bus_relations_mapping[generation_technology]

                        for unit in 1:num_units
                            bidding_group_index = bg_relation_mapping[unit]
                            bus_index = bus_relation_mapping[unit]
                            if is_null(bidding_group_index) || is_null(bus_index)
                                continue
                            end
                            bidding_group_bus_index =
                                _get_bidding_group_bus_index(bidding_group_index, bus_index, num_buses)
                            bidding_group_generation[bidding_group_bus_index] +=
                                generation_reader.data[unit]
                            bidding_group_costs[bidding_group_bus_index] += costs_reader.data[unit]
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
                    Quiver.write!(
                        bidding_group_costs_writer,
                        bidding_group_costs;
                        period,
                        scenario,
                        subperiod = subperiod,
                    )
                end
            end
        end
    end

    Quiver.close!(bidding_group_costs_writer)
    if write_generation
        Quiver.close!(bidding_group_generation_writer)
    end

    return
end

function get_generation_and_costs_files(inputs::Inputs, clearing_procedure::String, technology::String)
    outputs_dir = output_path(inputs)
    post_processing_dir = post_processing_path(inputs)
    generation_file = filter(
        x -> endswith(x, clearing_procedure * ".csv") && occursin(technology, x) && occursin("generation", x),
        readdir(outputs_dir),
    )
    costs_file = filter(
        x -> endswith(x, clearing_procedure * ".csv") && occursin(technology, x) && occursin("total_costs", x),
        readdir(post_processing_dir),
    )
    # Only one file per technology and clearing procedure is expected
    if isempty(generation_file) || isempty(costs_file)
        return nothing, nothing
    end
    return generation_file[1], costs_file[1]
end

function _merge_costs_files(
    inputs::Inputs,
    clearing_procedure::String,
)
    outputs_dir = output_path(inputs)
    post_processing_dir = post_processing_path(inputs)

    generation_technologies = ["thermal", "hydro", "renewable", "battery"]
    for generation_technology in generation_technologies
        costs_files = filter(
            x ->
                (occursin("cost", x) || occursin("penalty", x)) && occursin(generation_technology, x)
                    && endswith(x, clearing_procedure * ".csv"), readdir(outputs_dir))
        if isempty(costs_files)
            continue
        end
        filename = generation_technology * "_total_costs_$(clearing_procedure).csv"
        sum_multiple_files(
            joinpath(post_processing_dir, get_filename(filename)),
            [joinpath(outputs_dir, get_filename(file)) for file in costs_files],
            Quiver.csv,
        )
    end
    return nothing
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

    write_generation_ex_physical =
        construction_type_ex_ante_physical(inputs) == Configurations_ConstructionType.COST_BASED
    write_generation_ex_commercial =
        construction_type_ex_ante_commercial(inputs) == Configurations_ConstructionType.COST_BASED
    write_generation_ex_post_physical =
        construction_type_ex_post_physical(inputs) == Configurations_ConstructionType.COST_BASED
    write_generation_ex_post_commercial =
        construction_type_ex_post_commercial(inputs) == Configurations_ConstructionType.COST_BASED

    clearing_procedures = ["ex_ante_physical", "ex_ante_commercial", "ex_post_physical", "ex_post_commercial"]
    is_ex_post = [false, false, true, true]
    write_generation = [
        write_generation_ex_physical,
        write_generation_ex_commercial,
        write_generation_ex_post_physical,
        write_generation_ex_post_commercial,
    ]

    for (i, clearing_procedure) in enumerate(clearing_procedures)
        _merge_costs_files(
            inputs,
            clearing_procedure,
        )
        _write_generation_costs_bg_file(
            inputs,
            outputs_post_processing,
            model_outputs_time_serie,
            run_time_options,
            clearing_procedure;
            is_ex_post = is_ex_post[i],
            write_generation = write_generation[i],
        )
    end

    return
end
