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
    tempdir = joinpath(output_path(inputs), "temp")

    num_bidding_groups = number_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    num_buses = length(inputs.collections.bus)

    generation_technologies = ["thermal", "hydro", "renewable", "battery"]

    suffix = "$(clearing_procedure)"
    suffix *= run_time_file_suffixes(inputs, run_time_options)
    generation_files =
        filter(x -> endswith(x, "_generation_" * suffix * ".csv"), readdir(outputs_dir))
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

    labels_by_pairs = labels_for_output_by_pair_of_agents(
        inputs,
        run_time_options,
        inputs.collections.bidding_group,
        inputs.collections.bus;
        index_getter = all_buses,
        filters_to_apply_in_first_collection = [has_generation_besides_virtual_reservoirs],
    )

    initialize!(
        QuiverOutput,
        outputs_post_processing;
        inputs,
        output_name = "bidding_group_costs_$(clearing_procedure)",
        # Remove bid_segment dimension for costs
        dimensions = dimensions[1:end-1],
        unit = "\$",
        labels = labels_by_pairs,
        run_time_options,
        dir_path = post_processing_dir,
    )

    bidding_group_costs_writer =
        get_writer(outputs_post_processing, inputs, run_time_options, "bidding_group_costs_$(clearing_procedure)")

    update_number_of_bid_segments!(inputs, number_of_bid_segments)

    total_costs_readers = Dict{String, Quiver.Reader{Quiver.csv}}()
    for generation_technology in generation_technologies
        costs_file = get_costs_files_from_tech(inputs, suffix, generation_technology)
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
                                if collection == "HydroUnit" &&
                                   clearing_hydro_representation(inputs) ==
                                   Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
                                    if is_associated_with_some_virtual_reservoir(inputs.collections.hydro_unit, unit)
                                        continue
                                    end
                                end
                                bidding_group_index = generic_unit_bidding_group_index(inputs, collection, unit)
                                bus_index = generic_unit_bus_index(inputs, collection, unit)
                                if is_null(bidding_group_index) || is_null(bus_index)
                                    continue
                                end
                                bidding_group_bus_label = "$(bidding_group_label(inputs, bidding_group_index)) - $(bus_label(inputs, bus_index))"
                                bidding_group_bus_index = findfirst(x -> x == bidding_group_bus_label, labels_by_pairs)
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
                            if collection == "HydroUnit" &&
                               clearing_hydro_representation(inputs) ==
                               Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
                                if is_associated_with_some_virtual_reservoir(inputs.collections.hydro_unit, unit)
                                    continue
                                end
                            end
                            bidding_group_index = generic_unit_bidding_group_index(inputs, collection, unit)
                            bus_index = generic_unit_bus_index(inputs, collection, unit)
                            if is_null(bidding_group_index) || is_null(bus_index)
                                continue
                            end
                            bidding_group_bus_label = "$(bidding_group_label(inputs, bidding_group_index)) - $(bus_label(inputs, bus_index))"
                            bidding_group_bus_index = findfirst(x -> x == bidding_group_bus_label, labels_by_pairs)
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

function get_costs_files_from_tech(inputs::Inputs, suffix::String, technology::String)
    post_processing_dir = post_processing_path(inputs)
    tempdir = joinpath(output_path(inputs), "temp")
    costs_file = filter(
        x -> endswith(x, suffix * ".csv") && occursin(technology, x) && occursin("total_costs", x),
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
    tempdir = joinpath(output_path(inputs), "temp")

    generation_technologies = ["thermal", "hydro", "renewable", "battery"]
    for generation_technology in generation_technologies
        costs_files = filter(
            x ->
                (occursin("cost", x) || occursin("penalty", x)) && occursin(generation_technology, x) &&
                    !occursin("opportunity_cost", x)
                    &&
                    (
                        endswith(x, clearing_procedure * ".csv") || endswith(x, clearing_procedure * ".quiv") ||
                        endswith(x, clearing_procedure * "_period_$(inputs.args.period)" * ".csv") ||
                        endswith(x, clearing_procedure * "_period_$(inputs.args.period)" * ".quiv")
                    ), readdir(outputs_dir))
        impl = _get_implementation_of_a_list_of_files(costs_files)
        if isempty(costs_files)
            continue
        end
        if is_single_period(inputs)
            filename = generation_technology * "_total_costs_$(clearing_procedure)_period_$(inputs.args.period)"
        else
            filename = generation_technology * "_total_costs_$(clearing_procedure)"
        end
        output_file = joinpath(tempdir, get_filename(filename))
        files = [joinpath(outputs_dir, get_filename(file)) for file in costs_files]
        Quiver.apply_expression(
            output_file,
            files,
            +,
            impl;
            digits = 6,
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

    num_bidding_groups = any_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])

    if num_bidding_groups == 0
        return
    end

    clearing_procedures = ["ex_ante_physical", "ex_ante_commercial", "ex_post_physical", "ex_post_commercial"]
    construction_types = [
        construction_type_ex_ante_physical(inputs)
        construction_type_ex_ante_commercial(inputs)
        construction_type_ex_post_physical(inputs)
        construction_type_ex_post_commercial(inputs)
    ]
    is_ex_post = [false, false, true, true]

    for (i, clearing_procedure) in enumerate(clearing_procedures)
        # Skip if there isn't physical data for construction type
        if construction_types[i] in
           [Configurations_ConstructionType.SKIP, Configurations_ConstructionType.BID_BASED]
            continue
        end
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
