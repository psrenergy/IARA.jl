function _write_costs_bg_file(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions,
    clearing_procedure::String;
    is_ex_post = false,
)
    outputs_dir = output_path(inputs)
    post_processing_dir = post_processing_path(inputs)
    tempdir = joinpath(path_case(inputs), "temp")

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

    number_of_bid_segments = maximum_number_of_bidding_segments(inputs)
    # Set number of bidding segments to 1 to add the cost based generation only in the first segment
    update_number_of_bid_segments!(inputs, 1)

    if is_ex_post
        dimensions = ["period", "scenario", "subscenario", "subperiod", "bid_segment"]
    else
        dimensions = ["period", "scenario", "subperiod", "bid_segment"]
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
        get_writer(outputs_post_processing, inputs, run_time_options, "bidding_group_costs_$(clearing_procedure)")

    update_number_of_bid_segments!(inputs, number_of_bid_segments)

    total_costs_readers = Dict{String, Quiver.Reader{Quiver.csv}}()
    bg_relations_mapping = Dict{String, Vector{Int}}()
    bus_relations_mapping = Dict{String, Vector{Int}}()
    for generation_technology in generation_technologies
        costs_file = get_costs_files_from_tech(inputs, clearing_procedure, generation_technology)
        if isnothing(costs_file)
            continue
        end
        total_costs_readers[generation_technology] = open_time_series_output(
            inputs,
            model_outputs_time_serie,
            joinpath(tempdir, get_filename(costs_file)),
        )
        bg_relations_mapping[generation_technology] =
            PSRI.get_map(inputs.db, _get_generation_unit(costs_file), "BiddingGroup", "id")
        bus_relations_mapping[generation_technology] =
            PSRI.get_map(inputs.db, _get_generation_unit(costs_file), "Bus", "id")
    end

    for period in periods(inputs)
        for scenario in scenarios(inputs)
            if is_ex_post
                for subscenario in subscenarios(inputs, run_time_options)
                    for subperiod in subperiods(inputs)
                        bidding_group_costs = zeros(num_bidding_groups * num_buses)
                        for generation_technology in keys(total_costs_readers)
                            costs_reader = total_costs_readers[generation_technology]
                            Quiver.goto!(
                                costs_reader;
                                period,
                                scenario,
                                subscenario = subscenario,
                                subperiod = subperiod,
                            )
                            labels = costs_reader.metadata.labels
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
                                bidding_group_costs[bidding_group_bus_index] += costs_reader.data[unit]
                            end
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
                    bidding_group_costs = zeros(num_bidding_groups * num_buses)
                    for generation_technology in keys(total_costs_readers)
                        costs_reader = total_costs_readers[generation_technology]
                        Quiver.goto!(costs_reader; period, scenario, subperiod = subperiod)
                        labels = costs_reader.metadata.labels
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
                            bidding_group_costs[bidding_group_bus_index] += costs_reader.data[unit]
                        end
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

    return
end

function get_costs_files(output_dir::String, post_processing_dir::String; from_ex_post::Bool)
    files = get_costs_files(output_dir; from_ex_post = from_ex_post)
    if isempty(files)
        files = get_costs_files(post_processing_dir; from_ex_post = from_ex_post)
    end
    return files
end

function get_costs_files(path::String; from_ex_post::Bool)
    from_ex_post_string = from_ex_post ? "ex_post" : "ex_ante"

    commercial_generation_files = filter(
        x ->
            occursin("bidding_group_costs", x) &&
                occursin(from_ex_post_string * "_commercial", x) &&
                get_file_ext(x) == ".csv",
        readdir(path),
    )

    physical_generation_files = filter(
        x ->
            occursin("bidding_group_costs", x) &&
                occursin(from_ex_post_string * "_physical", x) &&
                get_file_ext(x) == ".csv",
        readdir(path),
    )

    if isempty(physical_generation_files)
        return joinpath.(path, commercial_generation_files)
    else
        return joinpath.(path, physical_generation_files)
    end
end

function get_costs_files_from_tech(inputs::Inputs, clearing_procedure::String, technology::String)
    post_processing_dir = post_processing_path(inputs)
    tempdir = joinpath(path_case(inputs), "temp")
    costs_file = filter(
        x -> endswith(x, clearing_procedure * ".csv") && occursin(technology, x) && occursin("total_costs", x),
        readdir(tempdir),
    )
    # Only one file per technology and clearing procedure is expected
    if isempty(costs_file)
        return nothing
    end
    return costs_file[1]
end

function _merge_costs_files(
    inputs::Inputs,
    clearing_procedure::String,
)
    outputs_dir = output_path(inputs)
    tempdir = joinpath(path_case(inputs), "temp")

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
            joinpath(tempdir, get_filename(filename)),
            [joinpath(outputs_dir, get_filename(file)) for file in costs_files],
            Quiver.csv,
        )
    end
    return nothing
end

"""
    create_bidding_group_cost_files(inputs::Inputs, outputs_post_processing::Outputs, model_outputs_time_serie::OutputReaders, run_time_options::RunTimeOptions)

Create the bidding group cost files for ex-ante and ex-post data (physical and commercial).
"""
function create_bidding_group_cost_files(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions,
)
    outputs_dir = output_path(inputs)

    num_bidding_groups = length(inputs.collections.bidding_group)

    if num_bidding_groups == 0
        return
    end

    clearing_procedures = ["ex_ante_physical", "ex_ante_commercial", "ex_post_physical", "ex_post_commercial"]
    is_ex_post = [false, false, true, true]

    for (i, clearing_procedure) in enumerate(clearing_procedures)
        _merge_costs_files(
            inputs,
            clearing_procedure,
        )
        _write_costs_bg_file(
            inputs,
            outputs_post_processing,
            model_outputs_time_serie,
            run_time_options,
            clearing_procedure;
            is_ex_post = is_ex_post[i],
        )
    end

    return
end
