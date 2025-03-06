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
    end

    num_periods = if is_single_period(inputs)
        1
    else
        number_of_periods(inputs)
    end

    for period in 1:num_periods
        for scenario in scenarios(inputs)
            if is_ex_post
                for subscenario in subscenarios(inputs, run_time_options)
                    for subperiod in subperiods(inputs)
                        bidding_group_costs = zeros(num_bidding_groups * num_buses)
                        for generation_technology in keys(total_costs_readers)
                            costs_reader = total_costs_readers[generation_technology]
                            collection = _get_generation_unit(costs_reader.filename)
                            Quiver.goto!(
                                costs_reader;
                                period,
                                scenario,
                                subscenario = subscenario,
                                subperiod = subperiod,
                            )
                            labels = costs_reader.metadata.labels
                            num_units = length(labels)

                            for unit in 1:num_units
                                bidding_group_index = generic_unit_bidding_group_index(inputs, collection, unit)
                                bus_index = generic_unit_bus_index(inputs, collection, unit)
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
                        collection = _get_generation_unit(costs_reader.filename)
                        Quiver.goto!(costs_reader; period, scenario, subperiod = subperiod)
                        labels = costs_reader.metadata.labels
                        num_units = length(labels)

                        for unit in 1:num_units
                            bidding_group_index = generic_unit_bidding_group_index(inputs, collection, unit)
                            bus_index = generic_unit_bus_index(inputs, collection, unit)
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

function get_costs_files(path::String; from_ex_post::Bool)
    from_ex_post_string = from_ex_post ? "ex_post" : "ex_ante"

    commercial_costs_files = filter(
        x ->
            occursin("bidding_group_costs", x) &&
                occursin(from_ex_post_string * "_commercial", x) &&
                get_file_ext(x) == ".csv",
        readdir(path),
    )

    physical_costs_files = filter(
        x ->
            occursin("bidding_group_costs", x) &&
                occursin(from_ex_post_string * "_physical", x) &&
                get_file_ext(x) == ".csv",
        readdir(path),
    )

    if isempty(physical_costs_files)
        return joinpath.(path, commercial_costs_files)
    else
        return joinpath.(path, physical_costs_files)
    end
end

function get_costs_files_from_tech(inputs::Inputs, clearing_procedure::String, technology::String)
    post_processing_dir = post_processing_path(inputs)
    tempdir = joinpath(path_case(inputs), "temp")
    costs_file = filter(
        x -> endswith(x, clearing_procedure * ".csv") && occursin(technology, x) && occursin("total_costs", x),
        readdir(tempdir),
    )
    if isempty(costs_file)
        return nothing
    end
    # Only one file per technology and clearing procedure is expected
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
            costs_files = filter(
                x ->
                    (occursin("cost", x) || occursin("penalty", x)) && occursin(generation_technology, x)
                        && endswith(x, clearing_procedure * "_period_$(inputs.args.period)" * ".csv"),
                readdir(outputs_dir))
        end
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
