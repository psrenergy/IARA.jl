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
    post_processing(inputs::Inputs)

Run post-processing routines.
"""
function post_processing(inputs::Inputs)
    @info("Running post-processing routines")
    post_proc_path = post_processing_path(inputs)
    if !isdir(post_proc_path)
        mkdir(post_proc_path)
    end

    outputs_post_processing = Outputs()
    model_outputs_time_series = OutputReaders()
    run_time_options = RunTimeOptions(; force_all_subscenarios = true)

    try
        post_process_outputs(inputs, outputs_post_processing, model_outputs_time_series, run_time_options)
    finally
        finalize_outputs!(outputs_post_processing)
        finalize_outputs!(model_outputs_time_series)
    end

    if inputs.args.plot_outputs
        build_plots(inputs)
    end
    if inputs.args.plot_ui_outputs && is_market_clearing(inputs)
        build_ui_plots(inputs)
    end
    return nothing
end

function post_process_outputs(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions,
)
    gather_outputs_separated_by_asset_owners(inputs; run_time_options)
    if run_mode(inputs) == RunMode.TRAIN_MIN_COST ||
       (is_market_clearing(inputs) && clearing_has_physical_variables(inputs, run_time_options))
        post_processing_generation(inputs, run_time_options)
    end

    if any_elements(inputs, HydroUnit; filters = [has_min_outflow])
        physical_variables_suffix = if is_mincost(inputs)
            ""
        elseif is_skipped(inputs, "ex_post_physical")
            "_ex_post_commercial"
        else
            "_ex_post_physical"
        end

        post_processing_minimum_outflow_violation(
            inputs,
            outputs_post_processing,
            model_outputs_time_serie,
            run_time_options;
            physical_variables_suffix = physical_variables_suffix,
        )

        if is_market_clearing(inputs) &&
           settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
            ex_ante_physical_suffix =
                is_skipped(inputs, "ex_ante_physical") ? "_ex_ante_commercial" : "_ex_ante_physical"
            post_processing_minimum_outflow_violation(
                inputs,
                outputs_post_processing,
                model_outputs_time_serie,
                run_time_options;
                physical_variables_suffix = ex_ante_physical_suffix,
            )
        end
    end
    if is_market_clearing(inputs)
        if any_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
            create_bidding_group_generation_files(
                inputs,
                outputs_post_processing,
                model_outputs_time_serie,
                run_time_options,
            )
            create_bidding_group_cost_files(
                inputs,
                outputs_post_processing,
                model_outputs_time_serie,
                run_time_options,
            )
            if settlement_type(inputs) != IARA.Configurations_FinancialSettlementType.NONE
                post_processing_bidding_group_revenue(
                    inputs,
                    outputs_post_processing,
                    model_outputs_time_serie,
                    run_time_options,
                )
                _join_independent_and_profile_bid(
                    inputs,
                    run_time_options,
                )
                if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
                    post_processing_bidding_group_total_revenue(
                        inputs,
                        outputs_post_processing,
                        model_outputs_time_serie,
                        run_time_options,
                    )
                end
                calculate_profits_settlement(
                    inputs,
                    run_time_options,
                )
            end
        end
        if use_virtual_reservoirs(inputs)
            physical_variables_suffix =
                is_skipped(inputs, "ex_post_physical") ? "_ex_post_commercial" : "_ex_post_physical"

            if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_ANTE
                commercial_variables_suffix =
                    is_skipped(inputs, "ex_ante_commercial") ? "_ex_ante_physical" : "_ex_ante_commercial"

                post_processing_virtual_reservoirs(
                    inputs,
                    outputs_post_processing,
                    model_outputs_time_serie,
                    run_time_options;
                    physical_variables_suffix = physical_variables_suffix,
                    commercial_variables_suffix = commercial_variables_suffix,
                    output_suffix = "_ex_ante",
                )
            elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_POST
                commercial_variables_suffix =
                    is_skipped(inputs, "ex_post_commercial") ? "_ex_post_physical" : "_ex_post_commercial"

                post_processing_virtual_reservoirs(
                    inputs,
                    outputs_post_processing,
                    model_outputs_time_serie,
                    run_time_options;
                    physical_variables_suffix = physical_variables_suffix,
                    commercial_variables_suffix = commercial_variables_suffix,
                    output_suffix = "_ex_post",
                )
            elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
                ex_post_physical_suffix =
                    is_skipped(inputs, "ex_post_physical") ? "_ex_post_commercial" : "_ex_post_physical"
                ex_post_commercial_suffix =
                    is_skipped(inputs, "ex_post_commercial") ? "_ex_post_physical" : "_ex_post_commercial"
                ex_ante_physical_suffix =
                    is_skipped(inputs, "ex_ante_physical") ? "_ex_ante_commercial" : "_ex_ante_physical"
                ex_ante_commercial_suffix =
                    is_skipped(inputs, "ex_ante_commercial") ? "_ex_ante_physical" : "_ex_ante_commercial"

                post_processing_virtual_reservoirs_double_settlement(
                    inputs,
                    outputs_post_processing,
                    model_outputs_time_serie,
                    run_time_options;
                    ex_post_physical_suffix = ex_post_physical_suffix,
                    ex_ante_physical_suffix = ex_ante_physical_suffix,
                    ex_post_commercial_suffix = ex_post_commercial_suffix,
                    ex_ante_commercial_suffix = ex_ante_commercial_suffix,
                )
            end
        end
    end

    return nothing
end

function open_time_series_output(
    inputs::Inputs,
    model_outputs::OutputReaders,
    file::String,
)
    if !isfile(file * ".qvr")
        error("File $file.qvr does not exist")
        return nothing
    end
    reader = Quiver.Binary.open_file(file; mode = 'r')
    output_timeseries = QuiverInput(reader)
    model_outputs.outputs[file] = output_timeseries
    return reader
end

function get_writer(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, output_name::String)
    return outputs.outputs[output_name*run_time_file_suffixes(inputs, run_time_options)].writer
end

function get_file_ext(filename::String)
    return splitext(filename)[2]
end

function get_filename(filename::String)
    return splitext(filename)[1]
end

"""
    read_timeseries_file_in_outputs(filename::String, inputs::Inputs)

Read a timeseries file in the outputs directory.
"""
function read_timeseries_file_in_outputs(filename, inputs)
    output_dir = output_path(inputs)
    filepath_csv = joinpath(output_dir, filename * ".csv")
    filepath_qvr = joinpath(output_dir, filename * ".qvr")
    filepath = isfile(filepath_qvr) ? filepath_qvr : filepath_csv
    return read_timeseries_file(filepath)
end

function create_zero_file(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    filename::String,
    labels::Vector{String},
    unit::String;
    has_subscenarios::Bool = false,
    has_subperiods::Bool = true,
)
    periods = if is_single_period(inputs)
        1
    else
        number_of_periods(inputs)
    end
    temp_path = joinpath(output_path(inputs, run_time_options), "temp")

    dimensions = ["period", "scenario"]
    if has_subscenarios
        push!(dimensions, "subscenario")
    end
    if has_subperiods
        push!(dimensions, "subperiod")
    end

    dimension_size_dict = Dict{String, Int}(
        "period" => periods,
        "scenario" => number_of_scenarios(inputs),
        "subscenario" => number_of_subscenarios(inputs, run_time_options),
        "subperiod" => number_of_subperiods(inputs),
    )

    dimension_size = [dimension_size_dict[d] for d in dimensions]
    zeros_array = zeros(Float64, length(labels), reverse(dimension_size)...)

    path = joinpath(temp_path, filename)
    write_timeseries_file(
        path,
        zeros_array;
        dimensions = dimensions,
        labels = labels,
        time_dimension = "period",
        dimension_size = dimension_size,
        initial_date = initial_date_time(inputs),
        unit = unit,
        frequency = period_type_string(inputs.collections.configurations.time_series_step),
    )
    return path
end

function create_temporary_file_with_subscenario_dimension(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    model_outputs_time_serie::OutputReaders,
    filename::String;
)
    tempdir = joinpath(output_path(inputs, run_time_options), "temp")
    treated_filename = joinpath(tempdir, basename(filename))

    reader = Quiver.Binary.open_file(filename; mode = 'r')
    reader_metadata = Quiver.Binary.get_metadata(reader)
    @assert metadata_dimension_names(reader_metadata) == [:period, :scenario]

    number_of_subscenarios = inputs.collections.configurations.number_of_subscenarios
    dimension_size = [metadata_dimension_sizes(reader_metadata)..., number_of_subscenarios]

    reader_time_dimensions = Quiver.Binary.get_dimensions(reader_metadata)
    time_dimensions = [d.name for d in reader_time_dimensions if d.is_time_dimension]
    frequencies = [d.frequency for d in reader_time_dimensions if d.is_time_dimension]

    md = Quiver.Binary.Metadata(;
        initial_datetime = Quiver.Binary.get_initial_datetime(reader_metadata),
        unit = Quiver.Binary.get_unit(reader_metadata),
        labels = Quiver.Binary.get_labels(reader_metadata),
        dimensions = ["period", "scenario", "subscenario"],
        dimension_sizes = Int64.(dimension_size),
        time_dimensions = time_dimensions,
        frequencies = frequencies,
    )
    writer = Quiver.Binary.open_file(treated_filename; mode = 'w', metadata = md)

    for period in 1:dimension_size[1]
        for scenario in 1:dimension_size[2]
            data = Quiver.Binary.read(reader; period, scenario)
            for subscenario in 1:number_of_subscenarios
                Quiver.Binary.write!(writer; data = data, period, scenario, subscenario = subscenario)
            end
        end
    end

    Quiver.Binary.close!(reader)
    Quiver.Binary.close!(writer)

    return treated_filename
end

"""
    merge_binary_files(output_path::String, input_paths::Vector{String})

Concatenate the labels of N binary files sharing the same dimensions into one output file.
"""
function merge_binary_files(output_path::String, input_paths::Vector{String})
    readers = [Quiver.Binary.open_file(p; mode = 'r') for p in input_paths]
    metadatas = [Quiver.Binary.get_metadata(r) for r in readers]

    first_dimensions = Quiver.Binary.get_dimensions(first(metadatas))
    dimension_names = [Symbol(d.name) for d in first_dimensions]
    dimension_sizes = [Int(d.size) for d in first_dimensions]
    unit = Quiver.Binary.get_unit(first(metadatas))
    initial_datetime = Quiver.Binary.get_initial_datetime(first(metadatas))
    time_dimensions = String[d.name for d in first_dimensions if d.is_time_dimension]
    frequencies = String[d.frequency for d in first_dimensions if d.is_time_dimension]

    errors = String[]
    for (path, md) in zip(input_paths[2:end], metadatas[2:end])
        md_dimensions = Quiver.Binary.get_dimensions(md)
        md_dimension_names = [Symbol(d.name) for d in md_dimensions]
        md_dimension_sizes = [Int(d.size) for d in md_dimensions]
        md_time_dimensions = String[d.name for d in md_dimensions if d.is_time_dimension]
        md_frequencies = String[d.frequency for d in md_dimensions if d.is_time_dimension]

        if md_dimension_names != dimension_names || md_dimension_sizes != dimension_sizes
            push!(
                errors,
                "\"$(input_paths[1])\" has dimensions $dimension_names (sizes $dimension_sizes), but " *
                "\"$path\" has $md_dimension_names (sizes $md_dimension_sizes).",
            )
        end
        md_unit = Quiver.Binary.get_unit(md)
        if md_unit != unit
            push!(errors, "\"$(input_paths[1])\" has unit \"$unit\", but \"$path\" has \"$md_unit\".")
        end
        md_initial_datetime = Quiver.Binary.get_initial_datetime(md)
        if md_initial_datetime != initial_datetime
            push!(
                errors,
                "\"$(input_paths[1])\" has initial datetime \"$initial_datetime\", but " *
                "\"$path\" has \"$md_initial_datetime\".",
            )
        end
        if md_time_dimensions != time_dimensions || md_frequencies != frequencies
            push!(
                errors,
                "\"$(input_paths[1])\" has time dimension(s) $time_dimensions with frequency(ies) $frequencies, " *
                "but \"$path\" has $md_time_dimensions with $md_frequencies.",
            )
        end
    end

    merged_labels = vcat([Quiver.Binary.get_labels(md) for md in metadatas]...)
    duplicated_labels = [label for label in unique(merged_labels) if count(==(label), merged_labels) > 1]
    if !isempty(duplicated_labels)
        push!(errors, "label(s) $duplicated_labels appear in more than one of $input_paths.")
    end

    if !isempty(errors)
        for r in readers
            Quiver.Binary.close!(r)
        end
        error("Cannot merge binary files ($(length(errors)) error(s)):\n" * join(("  - " * e for e in errors), "\n"))
    end

    out_md = Quiver.Binary.Metadata(;
        initial_datetime = initial_datetime,
        unit = unit,
        labels = merged_labels,
        dimensions = String.(dimension_names),
        dimension_sizes = dimension_sizes,
        time_dimensions = time_dimensions,
        frequencies = frequencies,
    )
    writer = Quiver.Binary.open_file(output_path; mode = 'w', metadata = out_md)

    dims = first_position!(copy(dimension_sizes))
    names_tuple = Tuple(dimension_names)
    for _ in 1:prod(dimension_sizes)
        next_dim!(dims, dimension_sizes)
        read_kwargs = NamedTuple{names_tuple}(Tuple(dims))
        merged_data = vcat([Quiver.Binary.read(r; allow_nulls = true, read_kwargs...) for r in readers]...)
        Quiver.Binary.write!(writer; data = merged_data, read_kwargs...)
    end

    for r in readers
        Quiver.Binary.close!(r)
    end
    Quiver.Binary.close!(writer)
    return output_path
end

"""
    sum_over_agents(file_or_expr, new_label::String)

Sum across all agent/label columns and rename the result to `new_label`.
"""
function sum_over_agents(file_or_expr, new_label::String)
    summed = Quiver.aggregate_agents(file_or_expr, Quiver.C.QUIVER_EXPRESSION_AGGREGATE_AGENTS_OPERATION_SUM)
    return Quiver.rename_agents(summed, Dict("sum" => new_label))
end
