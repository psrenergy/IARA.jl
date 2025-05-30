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
    unit_name = match(r"^([a-z]+)_.*", basename(file_path))
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

function generic_unit_bidding_group_index(inputs::Inputs, collection::String, unit_index::Int)
    if collection == "ThermalUnit"
        return thermal_unit_bidding_group_index(inputs, unit_index)
    elseif collection == "HydroUnit"
        return hydro_unit_bidding_group_index(inputs, unit_index)
    elseif collection == "BatteryUnit"
        return battery_unit_bidding_group_index(inputs, unit_index)
    elseif collection == "RenewableUnit"
        return renewable_unit_bidding_group_index(inputs, unit_index)
    end
end

function generic_unit_bus_index(inputs::Inputs, collection::String, unit_index::Int)
    if collection == "ThermalUnit"
        return thermal_unit_bus_index(inputs, unit_index)
    elseif collection == "HydroUnit"
        return hydro_unit_bus_index(inputs, unit_index)
    elseif collection == "BatteryUnit"
        return battery_unit_bus_index(inputs, unit_index)
    elseif collection == "RenewableUnit"
        return renewable_unit_bus_index(inputs, unit_index)
    end
end

function _write_generation_bg_file(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions,
    clearing_procedure::String;
    is_ex_post = false,
)
    outputs_dir = output_path(inputs)
    post_processing_dir = post_processing_path(inputs)

    num_periods = is_single_period(inputs) ? 1 : number_of_periods(inputs)
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
    bidding_group_ex_ante = nothing
    initial_date_time = nothing
    unit = nothing

    if is_ex_post
        dimensions = ["period", "scenario", "subscenario", "subperiod", "bid_segment"]
    else
        dimensions = ["period", "scenario", "subperiod", "bid_segment"]
    end

    bidding_group_bus_labels = labels_for_output_by_pair_of_agents(
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
        output_name = "bidding_group_generation_$(clearing_procedure)",
        dimensions = dimensions,
        unit = "GWh",
        labels = bidding_group_bus_labels,
        run_time_options,
        dir_path = post_processing_dir,
        consider_one_segment = true,
    )
    bidding_group_generation_writer =
        get_writer(
            outputs_post_processing,
            inputs,
            run_time_options,
            "bidding_group_generation_$(clearing_procedure)",
        )

    generation_readers = Dict{String, Quiver.Reader{Quiver.csv}}()
    for generation_technology in generation_technologies
        generation_file = get_generation_files(inputs, clearing_procedure, generation_technology)
        if isnothing(generation_file)
            continue
        end
        generation_readers[generation_technology] =
            open_time_series_output(
                inputs,
                model_outputs_time_serie,
                joinpath(outputs_dir, get_filename(generation_file)),
            )
    end

    for period in 1:num_periods
        for scenario in scenarios(inputs)
            if is_ex_post
                for subscenario in subscenarios(inputs, run_time_options)
                    for subperiod in subperiods(inputs)
                        bidding_group_generation = zeros(num_bidding_groups * num_buses)
                        for generation_technology in keys(generation_readers)
                            generation_reader = generation_readers[generation_technology]
                            collection = _get_generation_unit(generation_reader.filename)
                            Quiver.goto!(
                                generation_reader;
                                period,
                                scenario,
                                subscenario = subscenario,
                                subperiod = subperiod,
                            )
                            labels = generation_reader.metadata.labels
                            num_units = length(labels)

                            for unit in 1:num_units
                                bidding_group_index = generic_unit_bidding_group_index(inputs, collection, unit)
                                bus_index = generic_unit_bus_index(inputs, collection, unit)
                                if is_null(bidding_group_index) || is_null(bus_index)
                                    continue
                                end
                                bidding_group_bus_label = "$(bidding_group_label(inputs, bidding_group_index)) - $(bus_label(inputs, bus_index))"
                                bidding_group_bus_index =
                                    findfirst(x -> x == bidding_group_bus_label, bidding_group_bus_labels)
                                bidding_group_generation[bidding_group_bus_index] += generation_reader.data[unit]
                            end
                        end
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
            else
                for subperiod in subperiods(inputs)
                    bidding_group_generation = zeros(num_bidding_groups * num_buses)
                    for generation_technology in keys(generation_readers)
                        generation_reader = generation_readers[generation_technology]
                        collection = _get_generation_unit(generation_reader.filename)
                        Quiver.goto!(generation_reader; period, scenario, subperiod = subperiod)
                        labels = generation_reader.metadata.labels
                        num_units = length(labels)

                        for unit in 1:num_units
                            bidding_group_index = generic_unit_bidding_group_index(inputs, collection, unit)
                            bus_index = generic_unit_bus_index(inputs, collection, unit)
                            if is_null(bidding_group_index) || is_null(bus_index)
                                continue
                            end
                            bidding_group_bus_label = "$(bidding_group_label(inputs, bidding_group_index)) - $(bus_label(inputs, bus_index))"
                            bidding_group_bus_index =
                                findfirst(x -> x == bidding_group_bus_label, bidding_group_bus_labels)
                            bidding_group_generation[bidding_group_bus_index] +=
                                generation_reader.data[unit]
                        end
                    end
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

    Quiver.close!(bidding_group_generation_writer)

    return
end

function get_generation_files(inputs::Inputs, clearing_procedure::String, technology::String)
    outputs_dir = output_path(inputs)
    generation_file = filter(
        x -> endswith(x, clearing_procedure * ".csv") && occursin(technology, x) && occursin("generation", x),
        readdir(outputs_dir),
    )
    if isempty(generation_file)
        generation_file = filter(
            x ->
                endswith(x, clearing_procedure * "_period_$(inputs.args.period)" * ".csv") &&
                    occursin(technology, x) && occursin("generation", x),
            readdir(outputs_dir),
        )
    end
    if isempty(generation_file)
        return nothing
    end
    # Only one file per technology and clearing procedure is expected
    return generation_file[1]
end

"""
    create_bidding_group_generation_files(inputs::Inputs, outputs_post_processing::Outputs, model_outputs_time_serie::OutputReaders, run_time_options::RunTimeOptions)

Create the bidding group generation files for ex-ante and ex-post data (physical and commercial).
"""
function create_bidding_group_generation_files(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions,
)
    num_bidding_groups = length(inputs.collections.bidding_group)

    if num_bidding_groups == 0
        return
    end

    # Generate bidding group generation files if the construction type is cost-based
    if construction_type_ex_ante_physical(inputs) == Configurations_ConstructionType.COST_BASED
        _write_generation_bg_file(
            inputs,
            outputs_post_processing,
            model_outputs_time_serie,
            run_time_options,
            "ex_ante_physical";
            is_ex_post = false,
        )
    end

    if construction_type_ex_ante_commercial(inputs) == Configurations_ConstructionType.COST_BASED
        _write_generation_bg_file(
            inputs,
            outputs_post_processing,
            model_outputs_time_serie,
            run_time_options,
            "ex_ante_commercial";
            is_ex_post = false,
        )
    end

    if construction_type_ex_post_physical(inputs) == Configurations_ConstructionType.COST_BASED
        _write_generation_bg_file(
            inputs,
            outputs_post_processing,
            model_outputs_time_serie,
            run_time_options,
            "ex_post_physical";
            is_ex_post = true,
        )
    end

    if construction_type_ex_post_commercial(inputs) == Configurations_ConstructionType.COST_BASED
        _write_generation_bg_file(
            inputs,
            outputs_post_processing,
            model_outputs_time_serie,
            run_time_options,
            "ex_post_commercial";
            is_ex_post = true,
        )
    end

    return
end
