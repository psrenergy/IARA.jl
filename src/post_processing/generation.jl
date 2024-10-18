#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function post_processing_generation(inputs::Inputs)
    generation = zeros(
        5,
        number_of_blocks(inputs),
        number_of_scenarios(inputs),
        number_of_stages(inputs),
    )
    if number_of_elements(inputs, HydroPlant) > 0
        hydro_generation, _ = read_timeseries_file_in_outputs("hydro_generation", inputs)
        generation[1, :, :, :] = sum(hydro_generation; dims = 1)
    end
    if number_of_elements(inputs, ThermalPlant) > 0
        thermal_generation, _ = read_timeseries_file_in_outputs("thermal_generation", inputs)
        generation[2, :, :, :] = sum(thermal_generation; dims = 1)
    end
    if number_of_elements(inputs, RenewablePlant) > 0
        renewable_generation, _ = read_timeseries_file_in_outputs("renewable_generation", inputs)
        generation[3, :, :, :] = sum(renewable_generation; dims = 1)
    end
    if number_of_elements(inputs, Battery) > 0
        battery_generation, _ = read_timeseries_file_in_outputs("battery_generation", inputs)
        generation[4, :, :, :] = sum(battery_generation; dims = 1)
    end

    deficit, _ = read_timeseries_file_in_outputs("deficit", inputs)
    generation[5, :, :, :] = sum(deficit; dims = 1)

    write_timeseries_file(
        joinpath(path_case(inputs), "outputs", "generation"),
        generation;
        dimensions = ["stage", "scenario", "block"],
        labels = ["hydro", "thermal", "renewable", "battery", "deficit"],
        time_dimension = "stage",
        dimension_size = [number_of_stages(inputs), number_of_scenarios(inputs), number_of_blocks(inputs)],
        initial_date = initial_date_time(inputs),
        unit = "GWh",
    )

    return nothing
end
