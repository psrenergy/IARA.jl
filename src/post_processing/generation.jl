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
    post_processing_generation(inputs::Inputs, outputs_post_processing::Outputs, model_outputs_time_serie::TimeSeriesOutputs, run_time_options::RunTimeOptions)

Run post-processing routines for generation.
"""
function post_processing_generation(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::TimeSeriesOutputs,
    run_time_options::RunTimeOptions,
)
    post_processing_dir = post_processing_path(inputs)
    labels = ["hydro", "thermal", "renewable", "battery_unit", "deficit"]

    initialize!(
        QuiverOutput,
        outputs_post_processing;
        inputs,
        output_name = "generation",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "GWh",
        labels = labels,
        run_time_options,
        dir_path = post_processing_dir,
    )

    hydro_generation_reader = nothing
    thermal_generation_reader = nothing
    renewable_generation_reader = nothing
    battery_unit_generation_reader = nothing
    deficit_reader = nothing

    if number_of_elements(inputs, HydroUnit) > 0
        hydro_generation_reader = open_time_series_output(inputs, model_outputs_time_serie, "hydro_generation")
    end
    if number_of_elements(inputs, ThermalUnit) > 0
        thermal_generation_reader = open_time_series_output(inputs, model_outputs_time_serie, "thermal_generation")
    end
    if number_of_elements(inputs, RenewableUnit) > 0
        renewable_generation_reader = open_time_series_output(inputs, model_outputs_time_serie, "renewable_generation")
    end
    if number_of_elements(inputs, BatteryUnit) > 0
        battery_unit_generation_reader = open_time_series_output(inputs, model_outputs_time_serie, "battery_generation")
    end
    deficit_reader = open_time_series_output(inputs, model_outputs_time_serie, "deficit")

    for period in periods(inputs)
        for scenario in scenarios(inputs)
            for subperiod in subperiods(inputs)
                vector = AbstractFloat[]
                add_generation_to_array!(vector, hydro_generation_reader, period, scenario, subperiod)
                add_generation_to_array!(vector, thermal_generation_reader, period, scenario, subperiod)
                add_generation_to_array!(vector, renewable_generation_reader, period, scenario, subperiod)
                add_generation_to_array!(vector, battery_unit_generation_reader, period, scenario, subperiod)
                add_generation_to_array!(vector, deficit_reader, period, scenario, subperiod)

                Quiver.write!(
                    outputs_post_processing.outputs["generation"].writer,
                    vector;
                    period,
                    scenario,
                    subperiod = subperiod,
                )
            end
        end
    end

    return nothing
end

function add_generation_to_array!(
    vector::Vector{<:AbstractFloat},
    reader::Union{Quiver.Reader{Quiver.csv}, Nothing},
    period::Int,
    scenario::Int,
    subperiod::Int,
)
    if reader === nothing
        push!(vector, 0.0)
        return nothing
    end

    Quiver.goto!(reader; period, scenario, subperiod = subperiod)
    summed_generation = sum(reader.data)
    push!(vector, summed_generation)

    return nothing
end
