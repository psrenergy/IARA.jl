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

"""
    hydro_volume!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the hydro volume variables to the model.
"""
function hydro_volume!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])
    hydro_units_with_reservoir =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, operates_with_reservoir])
    hydro_blks = hydro_subperiods(inputs)

    @variable(
        model.jump_model,
        hydro_volume[b in hydro_blks, h in hydro_units],
        lower_bound = hydro_unit_min_volume(inputs, h),
        upper_bound = hydro_unit_max_volume(inputs, h),
    )

    if is_mincost(inputs, run_time_options) || clearing_has_volume_variables(inputs, run_time_options) ||
       single_period_heuristic_bid_has_volume_variables(inputs)
        @variable(
            model.jump_model,
            hydro_volume_state[h in hydro_units_with_reservoir],
            SDDP.State,
            initial_value = hydro_unit_initial_volume(inputs, h),
            lower_bound = hydro_unit_min_volume(inputs, h),
            upper_bound = hydro_unit_max_volume(inputs, h),
        )
    end

    if clearing_has_volume_variables(inputs, run_time_options) ||
       single_period_heuristic_bid_has_volume_variables(inputs)
        placeholder_previous_volume = 0.0
        @variable(
            model.jump_model,
            hydro_previous_period_volume[h in hydro_units_with_reservoir]
            in
            MOI.Parameter(placeholder_previous_volume)
        )
    end

    return nothing
end

"""
    hydro_volume!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, scenario, subscenario, ::Type{SubproblemUpdate})

Updates the hydro volume variables in the model.
"""
function hydro_volume!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    hydro_units_with_reservoir =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, operates_with_reservoir])

    if some_initial_volume_varies_by_scenario(inputs) && simulation_period == 1
        hydro_volume_state = get_model_object(model, :hydro_volume_state)
        for h in hydro_units_with_reservoir
            JuMP.fix(hydro_volume_state[h].in, hydro_unit_initial_volume(inputs, h))
        end
    end

    if !is_market_clearing(inputs)
        return nothing
    end
    # If the current asset owner is a price maker or a price taker we do not need to
    # update the hydro volume variables.
    # The mincost model already has the hydro volume variables updated when it is built.
    # This check is only for the Nash Equilibrium iterations with Min Cost initialization.
    if is_current_asset_owner_price_maker(inputs, run_time_options) ||
       is_current_asset_owner_price_taker(inputs, run_time_options) ||
       is_mincost(inputs, run_time_options)
        return nothing
    end

    if !clearing_has_volume_variables(inputs, run_time_options)
        return nothing
    end

    # Model parameters
    hydro_previous_period_volume = get_model_object(model, :hydro_previous_period_volume)

    # Data from previous period
    previous_volume =
        hydro_volume_from_previous_period(inputs, run_time_options, simulation_period, simulation_trajectory)

    for h in hydro_units_with_reservoir
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            hydro_previous_period_volume[h],
            previous_volume[h],
        )
    end
    return nothing
end

"""
    hydro_volume!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize the output files for
- hydro_initial_volume
- hydro_final_volume
"""
function hydro_volume!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    hydro_units = index_of_elements(inputs, HydroUnit; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, :hydro_volume)
    if run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_POST_PHYSICAL
        add_symbol_to_serialize!(outputs, :hydro_volume)
    elseif run_mode(inputs) == RunMode.SINGLE_PERIOD_MARKET_CLEARING &&
           run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_ANTE_PHYSICAL
        add_symbol_to_serialize!(outputs, :hydro_volume)
    end

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_final_volume",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "hm3",
        labels = hydro_unit_label(inputs)[hydro_units],
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_initial_volume",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "hm3",
        labels = hydro_unit_label(inputs)[hydro_units],
        run_time_options,
    )

    return nothing
end

"""
    hydro_volume!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the hydro final and initial volume values to the output file.
"""
function hydro_volume!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    hydro_units = index_of_elements(inputs, HydroUnit; run_time_options)
    existing_hydro_units =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = hydro_units,
        elements_to_write = existing_hydro_units,
    )

    hydro_volume = simulation_results.data[:hydro_volume]

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "hydro_initial_volume",
        hydro_volume.data[1:end-1, :]; # we filter the last subperiod because we don`t write it to a file. This last subperiod is auxiliary to the model.
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "hydro_final_volume",
        hydro_volume.data[2:end, :];
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )
    return nothing
end
