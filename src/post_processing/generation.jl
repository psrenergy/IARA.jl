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
    post_processing_generation(inputs::Inputs)

Run post-processing routines for generation.
"""
function post_processing_generation(inputs::Inputs)
    periods = if is_single_period(inputs)
        1
    else
        number_of_periods(inputs)
    end
    generation = zeros(
        5,
        number_of_subperiods(inputs),
        number_of_scenarios(inputs),
        periods,
    )
    file_suffix = ""
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
        hydro_generation, _ = read_timeseries_file_in_outputs("hydro_generation$file_suffix", inputs)
        generation[1, :, :, :] = if is_market_clearing(inputs)
            mean(sum(hydro_generation; dims = 1); dims = 3)
        else
            sum(hydro_generation; dims = 1)
        end
    end
    if number_of_elements(inputs, ThermalUnit) > 0
        thermal_generation, _ = read_timeseries_file_in_outputs("thermal_generation$file_suffix", inputs)
        generation[2, :, :, :] = if is_market_clearing(inputs)
            mean(sum(thermal_generation; dims = 1); dims = 3)
        else
            sum(thermal_generation; dims = 1)
        end
    end
    if number_of_elements(inputs, RenewableUnit) > 0
        renewable_generation, _ = read_timeseries_file_in_outputs("renewable_generation$file_suffix", inputs)
        generation[3, :, :, :] = if is_market_clearing(inputs)
            mean(sum(renewable_generation; dims = 1); dims = 3)
        else
            sum(renewable_generation; dims = 1)
        end
    end
    if number_of_elements(inputs, BatteryUnit) > 0
        battery_unit_generation, _ = read_timeseries_file_in_outputs("battery_generation$file_suffix", inputs)
        generation[4, :, :, :] = if is_market_clearing(inputs)
            mean(sum(battery_unit_generation; dims = 1); dims = 3)
        else
            sum(battery_unit_generation; dims = 1)
        end
    end

    deficit, _ = read_timeseries_file_in_outputs("deficit$file_suffix", inputs)
    generation[5, :, :, :] = if is_market_clearing(inputs)
        mean(sum(deficit; dims = 1); dims = 3)
    else
        sum(deficit; dims = 1)
    end

    write_timeseries_file(
        joinpath(post_processing_path(inputs), "generation"),
        generation;
        dimensions = ["period", "scenario", "subperiod"],
        labels = ["hydro", "thermal", "renewable", "battery_unit", "deficit"],
        time_dimension = "period",
        dimension_size = [periods, number_of_scenarios(inputs), number_of_subperiods(inputs)],
        initial_date = initial_date_time(inputs),
        unit = "GWh",
    )

    return nothing
end
