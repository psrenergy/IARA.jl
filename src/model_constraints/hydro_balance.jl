#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function hydro_balance! end

"""
    hydro_balance!(
        model,
        inputs,
        run_time_options,
        ::Type{SubproblemBuild},
    )

Add the hydro balance constraints to the model.
"""
function hydro_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    if hydro_balance_subperiod_resolution(inputs) ==
       Configurations_HydroBalanceSubperiodResolution.AGGREGATED_SUBPERIODS
        hydro_balance_aggregated_subperiods(model, inputs, run_time_options)
    elseif hydro_balance_subperiod_resolution(inputs) ==
           Configurations_HydroBalanceSubperiodResolution.CHRONOLOGICAL_SUBPERIODS
        hydro_balance_chronological_subperiods(model, inputs, run_time_options)
    else
        error("Hydro balance subperiod resolution $(hydro_balance_subperiod_resolution(inputs)) not implemented.")
    end

    return nothing
end

"""
    hydro_balance_aggregated_subperiods(
        model,
        inputs,
        run_time_options,
    )

Add the hydro balance constraints to the model for the aggregated subperiods resolution.
"""
function hydro_balance_aggregated_subperiods(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    existing_hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])
    hydro_units_operating_with_reservoir =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, operates_with_reservoir])

    # Model Variables
    hydro_turbining = get_model_object(model, :hydro_turbining)
    hydro_spillage = get_model_object(model, :hydro_spillage)
    hydro_volume = get_model_object(model, :hydro_volume)
    inflow_slack = get_model_object(model, :inflow_slack)

    # If we are solving a clearing problem, there is no state variable, and the previous volume is obtained
    # from the serialized results of the previous period
    hydro_volume_state = if is_mincost(inputs) || clearing_has_volume_variables(inputs, run_time_options)
        get_model_object(model, :hydro_volume_state)
    end
    hydro_previous_period_volume = if clearing_has_volume_variables(inputs, run_time_options)
        get_model_object(model, :hydro_previous_period_volume)
    end

    # Model parameters
    inflow = get_model_object(model, :inflow)

    @constraint(
        model.jump_model,
        hydro_balance[
            h in existing_hydro_units,
        ],
        if operates_with_reservoir(inputs.collections.hydro_unit, h)
            hydro_volume[2, h]
        else
            0.0
        end
        ==
        if operates_with_reservoir(inputs.collections.hydro_unit, h)
            hydro_volume[1, h]
        else
            0.0
        end
        +
        sum(
            -
            hydro_turbining[b, h]
            -
            hydro_spillage[b, h]
            +
            sum(
                hydro_turbining[b, h_upstream] for
                h_upstream in index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing]) if
                hydro_unit_turbine_to(inputs, h_upstream) == h
            )
            +
            sum(
                hydro_spillage[b, h_upstream] for
                h_upstream in index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing]) if
                hydro_unit_spill_to(inputs, h_upstream) == h
            )
            +
            inflow_slack[b, h]
            +
            inflow[b, h]
            for b in subperiods(inputs)
        )
    )

    if is_mincost(inputs) || clearing_has_volume_variables(inputs, run_time_options)
        if clearing_has_volume_variables(inputs, run_time_options)
            @constraint(
                model.jump_model,
                hydro_initial_state[h in hydro_units_operating_with_reservoir],
                hydro_volume[1, h] == hydro_previous_period_volume[h]
            )
        elseif is_mincost(inputs)
            @constraint(
                model.jump_model,
                hydro_state_in[h in hydro_units_operating_with_reservoir],
                hydro_volume_state[h].in == hydro_volume[1, h]
            )
        end

        @constraint(
            model.jump_model,
            hydro_state_out[h in hydro_units_operating_with_reservoir],
            hydro_volume_state[h].out == hydro_volume[2, h]
        )
    end

    return nothing
end

"""
    hydro_balance_chronological_subperiods(
        model,
        inputs,
        run_time_options,
    )

Add the hydro balance constraints to the model for the chronological subperiods resolution.
"""
function hydro_balance_chronological_subperiods(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    existing_hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])
    hydro_units_operating_with_reservoir =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, operates_with_reservoir])
    hydro_units_operating_as_run_of_river =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, operates_as_run_of_river])

    # Model Variables
    hydro_turbining = get_model_object(model, :hydro_turbining)
    hydro_spillage = get_model_object(model, :hydro_spillage)
    hydro_volume = get_model_object(model, :hydro_volume)
    inflow_slack = get_model_object(model, :inflow_slack)

    # If we are solving a clearing problem, there is no state variable, and the previous volume is obtained
    # from the serialized results of the previous period
    hydro_volume_state = if is_mincost(inputs) || clearing_has_volume_variables(inputs, run_time_options)
        get_model_object(model, :hydro_volume_state)
    end
    hydro_previous_period_volume = if clearing_has_volume_variables(inputs, run_time_options)
        get_model_object(model, :hydro_previous_period_volume)
    end

    # Model parameters
    inflow = get_model_object(model, :inflow)

    # Constraints
    # All variables are in [hm^3]
    @constraint(
        model.jump_model,
        hydro_balance[
            b in subperiods(inputs),
            h in existing_hydro_units,
        ],
        hydro_volume[b+1, h]
        ==
        hydro_volume[b, h]
        -
        hydro_turbining[b, h]
        -
        hydro_spillage[b, h]
        +
        sum(
            hydro_turbining[b, h_upstream] for
            h_upstream in existing_hydro_units if
            hydro_unit_turbine_to(inputs, h_upstream) == h
        )
        +
        sum(
            hydro_spillage[b, h_upstream] for
            h_upstream in existing_hydro_units if
            hydro_unit_spill_to(inputs, h_upstream) == h
        )
        +
        inflow_slack[b, h]
        +
        inflow[b, h]
    )

    if is_mincost(inputs) || clearing_has_volume_variables(inputs, run_time_options)
        # If we are in the min cost case we let SDDP.jl handle the state equality 
        # by adding a constraint with the variable.in in the model. If we are in the
        # case we ignore the state variable and use the previous volume as the initial volume.
        # This is handled without the syntaxes from SDDP.jl
        if is_mincost(inputs)
            @constraint(
                model.jump_model,
                hydro_state_in[h in hydro_units_operating_with_reservoir],
                hydro_volume_state[h].in == hydro_volume[1, h]
            )
        elseif clearing_has_volume_variables(inputs, run_time_options)
            @constraint(
                model.jump_model,
                hydro_initial_state[h in hydro_units_operating_with_reservoir],
                hydro_volume[1, h] == hydro_previous_period_volume[h]
            )
        end

        @constraint(
            model.jump_model,
            hydro_state_out[h in hydro_units_operating_with_reservoir],
            hydro_volume_state[h].out == hydro_volume[end, h]
        )
    end

    @constraint(
        model.jump_model,
        hydro_units_run_of_river_vivf[h in hydro_units_operating_as_run_of_river],
        hydro_volume[1, h] == hydro_volume[end, h]
    )

    return nothing
end

function hydro_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

"""
    hydro_balance!(
        outputs,
        inputs,
        run_time_options,
        ::Type{InitializeOutput},
    )

Initialize the output file for:
- `hydro_opportunity_cost`
"""
function hydro_balance!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    hydros = index_of_elements(inputs, HydroUnit; run_time_options)

    # The names water_marginal_cost and hydro_opportunity_cost are different
    # because the first is the constraint dual 
    # and the second is the actual output, which has some adjustments

    add_custom_recorder_to_query_from_subproblem_result!(
        outputs,
        :water_marginal_cost,
        constraint_dual_recorder(:hydro_balance),
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_opportunity_cost",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "\$/MWh",
        labels = hydro_unit_label(inputs)[hydros],
        run_time_options,
    )

    return nothing
end

"""
    hydro_balance!(
        outputs,
        inputs,
        run_time_options,
        simulation_results,
        period,
        scenario,
        subscenario,
        ::Type{WriteOutput},
    )

Write the hydro opportunity cost to the output file.
"""
function hydro_balance!(
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
    existing_hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = hydro_units,
        elements_to_write = existing_hydro_units,
    )

    water_marginal_cost = simulation_results.data[:water_marginal_cost] * (-1)
    hydro_opportunity_cost = marginal_cost_to_opportunity_cost(
        inputs,
        water_marginal_cost,
        existing_hydro_units,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "hydro_opportunity_cost",
        hydro_opportunity_cost;
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )

    return nothing
end
