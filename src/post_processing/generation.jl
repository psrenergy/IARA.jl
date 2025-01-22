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
    generation = zeros(
        5,
        number_of_subperiods(inputs),
        number_of_scenarios(inputs),
        number_of_periods(inputs),
    )
    if number_of_elements(inputs, HydroUnit) > 0
        hydro_generation, _ = read_timeseries_file_in_outputs("hydro_generation", inputs)
        generation[1, :, :, :] = sum(hydro_generation; dims = 1)
    end
    if number_of_elements(inputs, ThermalUnit) > 0
        thermal_generation, _ = read_timeseries_file_in_outputs("thermal_generation", inputs)
        generation[2, :, :, :] = sum(thermal_generation; dims = 1)
    end
    if number_of_elements(inputs, RenewableUnit) > 0
        renewable_generation, _ = read_timeseries_file_in_outputs("renewable_generation", inputs)
        generation[3, :, :, :] = sum(renewable_generation; dims = 1)
    end
    if number_of_elements(inputs, BatteryUnit) > 0
        battery_unit_generation, _ = read_timeseries_file_in_outputs("battery_generation", inputs)
        generation[4, :, :, :] = sum(battery_unit_generation; dims = 1)
    end

    deficit, _ = read_timeseries_file_in_outputs("deficit", inputs)
    generation[5, :, :, :] = sum(deficit; dims = 1)

    write_timeseries_file(
        joinpath(post_processing_path(inputs), "generation"),
        generation;
        dimensions = ["period", "scenario", "subperiod"],
        labels = ["hydro", "thermal", "renewable", "battery_unit", "deficit"],
        time_dimension = "period",
        dimension_size = [number_of_periods(inputs), number_of_scenarios(inputs), number_of_subperiods(inputs)],
        initial_date = initial_date_time(inputs),
        unit = "GWh",
    )

    return nothing
end
