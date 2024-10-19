#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function hydro_volume! end

function hydro_volume!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing])
    hydro_plants_with_reservoir =
        index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing, operates_with_reservoir])
    hydro_blks = hydro_blocks(inputs)

    @variable(
        model.jump_model,
        hydro_volume[b in hydro_blks, h in hydro_plants],
        lower_bound = hydro_plant_min_volume(inputs, h),
        upper_bound = hydro_plant_max_volume(inputs, h),
    )

    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        @variable(
            model.jump_model,
            hydro_volume_state[h in hydro_plants_with_reservoir],
            SDDP.State,
            initial_value = hydro_plant_initial_volume(inputs, h),
            lower_bound = hydro_plant_min_volume(inputs, h),
            upper_bound = hydro_plant_max_volume(inputs, h),
        )
    elseif clearing_has_volume_variables(inputs, run_time_options)
        placeholder_scenario = 1
        previous_volume = hydro_volume_from_previous_stage(inputs, model.stage, placeholder_scenario)
        @variable(
            model.jump_model,
            hydro_previous_stage_volume[h in hydro_plants_with_reservoir]
            in
            MOI.Parameter(previous_volume[h])
        )
    end

    return nothing
end

function hydro_volume!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        return nothing
    end

    if !clearing_has_volume_variables(inputs, run_time_options)
        return nothing
    end

    hydro_plants_with_reservoir =
        index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing, operates_with_reservoir])

    # Model parameters
    hydro_previous_stage_volume = get_model_object(model, :hydro_previous_stage_volume)

    # Data from previous stage
    previous_volume = hydro_volume_from_previous_stage(inputs, model.stage, scenario)

    for h in hydro_plants_with_reservoir
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            hydro_previous_stage_volume[h],
            previous_volume[h],
        )
    end
    return nothing
end

function hydro_volume!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, :hydro_volume)
    if run_time_options.clearing_model_procedure == RunTime_ClearingProcedure.EX_POST_PHYSICAL
        add_symbol_to_serialize!(outputs, :hydro_volume)
    end

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_initial_volume",
        dimensions = ["stage", "scenario", "block"],
        unit = "hm3",
        labels = hydro_plant_label(inputs)[hydro_plants],
        run_time_options,
    )

    if run_time_options.clearing_model_procedure == RunTime_ClearingProcedure.EX_POST_PHYSICAL
        add_symbol_to_serialize!(outputs, :hydro_volume)
    end

    return nothing
end

function hydro_volume!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options)
    existing_hydro_plants =
        index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing])

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = hydro_plants,
        elements_to_write = existing_hydro_plants,
    )

    hydro_volume = simulation_results.data[:hydro_volume]

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "hydro_initial_volume",
        hydro_volume.data[1:end-1, :]; # we filter the last block because we don`t write it to a file. This last block is auxiliary to the model.
        stage,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )
    return nothing
end
