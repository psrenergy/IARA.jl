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
    temp_path = joinpath(output_path(inputs, run_time_options), "temp")
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

    if number_of_elements(inputs, HydroUnit) > 0
        filename = joinpath(output_path(inputs, run_time_options), "hydro_generation$file_suffix")
        filename_sum = joinpath(temp_path, "hydro_generation_sum$file_suffix")
        reader = Quiver.Binary.open_file(filename; mode = 'r')
        summed = sum_over_agents(reader, "hydro")
        Quiver.save(summed, filename_sum)
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "hydro_generation_mean$file_suffix")
            Quiver.save(
                Quiver.aggregate(summed, "subscenario", Quiver.C.QUIVER_EXPRESSION_AGGREGATE_OPERATION_MEAN),
                filename_mean,
            )
        end
        Quiver.Binary.close!(reader)
    else
        filename_sum = joinpath(temp_path, "hydro_generation_sum$file_suffix")
        create_zero_file(inputs, run_time_options, "hydro_generation_sum$file_suffix", ["hydro"], "GWh")
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "hydro_generation_mean$file_suffix")
            create_zero_file(inputs, run_time_options, "hydro_generation_mean$file_suffix", ["hydro"], "GWh")
        end
    end
    if number_of_elements(inputs, ThermalUnit) > 0
        filename = joinpath(output_path(inputs, run_time_options), "thermal_generation$file_suffix")
        filename_sum = joinpath(temp_path, "thermal_generation_sum$file_suffix")
        reader = Quiver.Binary.open_file(filename; mode = 'r')
        summed = sum_over_agents(reader, "thermal")
        Quiver.save(summed, filename_sum)
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "thermal_generation_mean$file_suffix")
            Quiver.save(
                Quiver.aggregate(summed, "subscenario", Quiver.C.QUIVER_EXPRESSION_AGGREGATE_OPERATION_MEAN),
                filename_mean,
            )
        end
        Quiver.Binary.close!(reader)
    else
        filename_sum = joinpath(temp_path, "thermal_generation_sum$file_suffix")
        create_zero_file(inputs, run_time_options, "thermal_generation_sum$file_suffix", ["thermal"], "GWh")
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "thermal_generation_mean$file_suffix")
            create_zero_file(inputs, run_time_options, "thermal_generation_mean$file_suffix", ["thermal"], "GWh")
        end
    end
    if number_of_elements(inputs, RenewableUnit) > 0
        filename = joinpath(output_path(inputs, run_time_options), "renewable_generation$file_suffix")
        filename_sum = joinpath(temp_path, "renewable_generation_sum$file_suffix")
        reader = Quiver.Binary.open_file(filename; mode = 'r')
        summed = sum_over_agents(reader, "renewable")
        Quiver.save(summed, filename_sum)
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "renewable_generation_mean$file_suffix")
            Quiver.save(
                Quiver.aggregate(summed, "subscenario", Quiver.C.QUIVER_EXPRESSION_AGGREGATE_OPERATION_MEAN),
                filename_mean,
            )
        end
        Quiver.Binary.close!(reader)
    else
        filename_sum = joinpath(temp_path, "renewable_generation_sum$file_suffix")
        create_zero_file(inputs, run_time_options, "renewable_generation_sum$file_suffix", ["renewable"], "GWh")
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "renewable_generation_mean$file_suffix")
            create_zero_file(
                inputs,
                run_time_options,
                "renewable_generation_mean$file_suffix",
                ["renewable"],
                "GWh",
            )
        end
    end
    if number_of_elements(inputs, BatteryUnit) > 0
        filename = joinpath(output_path(inputs, run_time_options), "battery_generation$file_suffix")
        filename_sum = joinpath(temp_path, "battery_generation_sum$file_suffix")
        reader = Quiver.Binary.open_file(filename; mode = 'r')
        summed = sum_over_agents(reader, "battery_unit")
        Quiver.save(summed, filename_sum)
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "battery_generation_mean$file_suffix")
            Quiver.save(
                Quiver.aggregate(summed, "subscenario", Quiver.C.QUIVER_EXPRESSION_AGGREGATE_OPERATION_MEAN),
                filename_mean,
            )
        end
        Quiver.Binary.close!(reader)
    else
        filename_sum = joinpath(temp_path, "battery_generation_sum$file_suffix")
        create_zero_file(inputs, run_time_options, "battery_generation_sum$file_suffix", ["battery_unit"], "GWh")
        if is_market_clearing(inputs)
            filename_mean = joinpath(temp_path, "battery_generation_mean$file_suffix")
            create_zero_file(
                inputs,
                run_time_options,
                "battery_generation_mean$file_suffix",
                ["battery_unit"],
                "GWh",
            )
        end
    end
    filename = joinpath(output_path(inputs, run_time_options), "deficit$file_suffix")
    filename_sum = joinpath(temp_path, "deficit_sum$file_suffix")
    reader = Quiver.Binary.open_file(filename; mode = 'r')
    summed = sum_over_agents(reader, "deficit")
    Quiver.save(summed, filename_sum)
    if is_market_clearing(inputs)
        filename_mean = joinpath(temp_path, "deficit_mean$file_suffix")
        Quiver.save(
            Quiver.aggregate(summed, "subscenario", Quiver.C.QUIVER_EXPRESSION_AGGREGATE_OPERATION_MEAN),
            filename_mean,
        )
    end
    Quiver.Binary.close!(reader)

    dir_path = post_processing_path(inputs, run_time_options)

    if is_market_clearing(inputs)
        quiver_binary_merge(
            joinpath(dir_path, "generation$file_suffix"),
            [
                joinpath(temp_path, "hydro_generation_mean$file_suffix"),
                joinpath(temp_path, "thermal_generation_mean$file_suffix"),
                joinpath(temp_path, "renewable_generation_mean$file_suffix"),
                joinpath(temp_path, "battery_generation_mean$file_suffix"),
                joinpath(temp_path, "deficit_mean$file_suffix"),
            ],
        )
    else
        quiver_binary_merge(
            joinpath(dir_path, "generation$file_suffix"),
            [
                joinpath(temp_path, "hydro_generation_sum$file_suffix"),
                joinpath(temp_path, "thermal_generation_sum$file_suffix"),
                joinpath(temp_path, "renewable_generation_sum$file_suffix"),
                joinpath(temp_path, "battery_generation_sum$file_suffix"),
                joinpath(temp_path, "deficit_sum$file_suffix"),
            ],
        )
    end

    export_binary_to_csv(joinpath(dir_path, "generation$file_suffix"))

    return nothing
end
