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
        physical_variables_suffix = if run_mode(inputs) == RunMode.TRAIN_MIN_COST
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
    file::String;
    convert_to_binary::Bool = false,
)
    if !isfile(file * ".csv")
        error("File $file.csv does not exist")
        return nothing
    end
    reader = if convert_to_binary
        convert_time_series_file_to_binary(file)
        # converting sends the converted file to a temp path
        file_path = joinpath(dirname(file), "temp", basename(file))
        Quiver.Reader{Quiver.binary}(file_path)
    else
        Quiver.Reader{Quiver.csv}(file)
    end
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
    filepath_quiv = joinpath(output_dir, filename * ".quiv")
    filepath = isfile(filepath_quiv) ? filepath_quiv : filepath_csv
    return read_timeseries_file(filepath)
end

function create_zero_file(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    filename::String,
    labels::Vector{String},
    impl::Type{<:Quiver.Implementation},
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
        implementation = impl,
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

    reader = Quiver.Reader{Quiver.csv}(filename)
    @assert reader.metadata.dimensions == [:period, :scenario]

    number_of_subscenarios = inputs.collections.configurations.number_of_subscenarios
    dimension_size = [reader.metadata.dimension_size..., number_of_subscenarios]

    writer = Quiver.Writer{Quiver.csv}(
        treated_filename;
        dimensions = ["period", "scenario", "subscenario"],
        labels = reader.metadata.labels,
        time_dimension = String(reader.metadata.time_dimension),
        dimension_size = dimension_size,
        frequency = reader.metadata.frequency,
        initial_date = reader.metadata.initial_date,
        unit = reader.metadata.unit,
    )

    for period in 1:dimension_size[1]
        for scenario in 1:dimension_size[2]
            Quiver.goto!(reader; period, scenario)
            data = reader.data
            for subscenario in 1:number_of_subscenarios
                Quiver.write!(writer, data; period, scenario, subscenario = subscenario)
            end
        end
    end

    Quiver.close!(reader)
    Quiver.close!(writer)

    return treated_filename
end
