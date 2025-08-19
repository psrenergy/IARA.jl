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
    post_processing_generation(inputs::Inputs, run_time_options::RunTimeOptions)

Run post-processing routines for generation.
"""
function post_processing_generation(inputs::Inputs, run_time_options::RunTimeOptions)
    file_suffix = ""
    temp_path = joinpath(output_path(inputs), "temp")
    if !isdir(temp_path)
        mkdir(temp_path)
    end

    if is_market_clearing(inputs)
        if (construction_type_ex_post_physical(inputs) == Configurations_ConstructionType.SKIP) ||
           (construction_type_ex_post_physical(inputs) == Configurations_ConstructionType.BID_BASED)
            file_suffix *= "_ex_post_commercial"
        else
            file_suffix *= "_ex_post_physical"
        end
    end
    if is_single_period(inputs)
        file_suffix *= "_period_$(inputs.args.period)"
    end

    files = String[]
    for file in readdir(output_path(inputs))
        if occursin(r"generation", file)
            push!(files, joinpath(output_path(inputs), file))
        end
    end
    current_impl = _get_implementation_of_a_list_of_files(files)
    impl = Quiver.binary
    if number_of_elements(inputs, HydroUnit) > 0
        filename = joinpath(output_path(inputs), "hydro_generation$file_suffix")
        Quiver.convert(filename, Quiver.csv, Quiver.binary; destination_directory = temp_path)
        filename = joinpath(temp_path, "hydro_generation$file_suffix")
        filename_sum = joinpath(temp_path, "hydro_generation_sum$file_suffix")
        Quiver.apply_expression_over_agents(
            filename_sum,
            filename,
            sum,
            ["hydro"],
            impl;
            digits = 6,
        )
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "hydro_generation_mean$file_suffix")
            Quiver.apply_expression_over_dimension(
                filename_mean,
                filename_sum,
                mean,
                :subscenario,
                impl;
                digits = 6,
                suppress_dimension_order_warning = true,
            )
        end
    else
        filename_sum = joinpath(temp_path, "hydro_generation_sum$file_suffix")
        create_zero_file(inputs, run_time_options, "hydro_generation_sum$file_suffix", ["hydro"], impl, "GWh")
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "hydro_generation_mean$file_suffix")
            create_zero_file(inputs, run_time_options, "hydro_generation_mean$file_suffix", ["hydro"], impl, "GWh")
        end
    end
    if number_of_elements(inputs, ThermalUnit) > 0
        filename = joinpath(output_path(inputs), "thermal_generation$file_suffix")
        Quiver.convert(filename, Quiver.csv, Quiver.binary; destination_directory = temp_path)
        filename = joinpath(temp_path, "thermal_generation$file_suffix")
        filename_sum = joinpath(temp_path, "thermal_generation_sum$file_suffix")
        Quiver.apply_expression_over_agents(
            filename_sum,
            filename,
            sum,
            ["thermal"],
            impl;
            digits = 6,
        )
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "thermal_generation_mean$file_suffix")
            Quiver.apply_expression_over_dimension(
                filename_mean,
                filename_sum,
                mean,
                :subscenario,
                impl;
                digits = 6,
                suppress_dimension_order_warning = true,
            )
        end
    else
        filename_sum = joinpath(temp_path, "thermal_generation_sum$file_suffix")
        create_zero_file(inputs, run_time_options, "thermal_generation_sum$file_suffix", ["thermal"], impl, "GWh")
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "thermal_generation_mean$file_suffix")
            create_zero_file(inputs, run_time_options, "thermal_generation_mean$file_suffix", ["thermal"], impl, "GWh")
        end
    end
    if number_of_elements(inputs, RenewableUnit) > 0
        filename = joinpath(output_path(inputs), "renewable_generation$file_suffix")
        Quiver.convert(filename, Quiver.csv, Quiver.binary; destination_directory = temp_path)
        filename = joinpath(temp_path, "renewable_generation$file_suffix")
        filename_sum = joinpath(temp_path, "renewable_generation_sum$file_suffix")
        Quiver.apply_expression_over_agents(
            filename_sum,
            filename,
            sum,
            ["renewable"],
            impl;
            digits = 6,
        )
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "renewable_generation_mean$file_suffix")
            Quiver.apply_expression_over_dimension(
                filename_mean,
                filename_sum,
                mean,
                :subscenario,
                impl;
                digits = 6,
                suppress_dimension_order_warning = true,
            )
        end
    else
        filename_sum = joinpath(temp_path, "renewable_generation_sum$file_suffix")
        create_zero_file(inputs, run_time_options, "renewable_generation_sum$file_suffix", ["renewable"], impl, "GWh")
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "renewable_generation_mean$file_suffix")
            create_zero_file(
                inputs,
                run_time_options,
                "renewable_generation_mean$file_suffix",
                ["renewable"],
                impl,
                "GWh",
            )
        end
    end
    if number_of_elements(inputs, BatteryUnit) > 0
        filename = joinpath(output_path(inputs), "battery_generation$file_suffix")
        Quiver.convert(filename, Quiver.csv, Quiver.binary; destination_directory = temp_path)
        filename = joinpath(temp_path, "battery_generation$file_suffix")
        filename_sum = joinpath(temp_path, "battery_generation_sum$file_suffix")
        Quiver.apply_expression_over_agents(
            filename_sum,
            filename,
            sum,
            ["battery_unit"],
            impl;
            digits = 6,
        )
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "battery_generation_mean$file_suffix")
            Quiver.apply_expression_over_dimension(
                filename_mean,
                filename_sum,
                mean,
                :subscenario,
                impl;
                digits = 6,
                suppress_dimension_order_warning = true,
            )
        end
    else
        filename_sum = joinpath(temp_path, "battery_generation_sum$file_suffix")
        create_zero_file(inputs, run_time_options, "battery_generation_sum$file_suffix", ["battery_unit"], impl, "GWh")
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "battery_generation_mean$file_suffix")
            create_zero_file(
                inputs,
                run_time_options,
                "battery_generation_mean$file_suffix",
                ["battery_unit"],
                impl,
                "GWh",
            )
        end
    end
    filename = joinpath(output_path(inputs), "deficit$file_suffix")
    Quiver.convert(filename, Quiver.csv, Quiver.binary; destination_directory = temp_path)
    filename = joinpath(temp_path, "deficit$file_suffix")
    filename_sum = joinpath(temp_path, "deficit_sum$file_suffix")
    Quiver.apply_expression_over_agents(
        filename_sum,
        filename,
        sum,
        ["deficit"],
        impl;
        digits = 6,
    )
    if is_market_clearing(inputs)
        filename_mean = joinpath(temp_path, "deficit_mean$file_suffix")
        Quiver.apply_expression_over_dimension(
            filename_mean,
            filename_sum,
            mean,
            :subscenario,
            impl;
            digits = 6,
            suppress_dimension_order_warning = true,
        )
    end

    if current_impl == Quiver.csv
        dir_path = temp_path
    else
        dir_path = post_processing_path(inputs)
    end

    if is_market_clearing(inputs)
        Quiver.merge(
            joinpath(dir_path, "generation$file_suffix"),
            [
                joinpath(temp_path, "hydro_generation_mean$file_suffix"),
                joinpath(temp_path, "thermal_generation_mean$file_suffix"),
                joinpath(temp_path, "renewable_generation_mean$file_suffix"),
                joinpath(temp_path, "battery_generation_mean$file_suffix"),
                joinpath(temp_path, "deficit_mean$file_suffix"),
            ],
            impl;
            digits = 6,
        )
    else
        Quiver.merge(
            joinpath(dir_path, "generation$file_suffix"),
            [
                joinpath(temp_path, "hydro_generation_sum$file_suffix"),
                joinpath(temp_path, "thermal_generation_sum$file_suffix"),
                joinpath(temp_path, "renewable_generation_sum$file_suffix"),
                joinpath(temp_path, "battery_generation_sum$file_suffix"),
                joinpath(temp_path, "deficit_sum$file_suffix"),
            ],
            impl;
            digits = 6,
        )
    end

    if current_impl == Quiver.csv
        Quiver.convert(
            joinpath(temp_path, "generation$file_suffix"),
            Quiver.binary,
            Quiver.csv;
            destination_directory = post_processing_path(inputs),
        )
    end

    return nothing
end
