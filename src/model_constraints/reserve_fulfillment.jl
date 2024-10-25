#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function reserve_fulfillment! end

function reserve_fulfillment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    reserves = index_of_elements(inputs, Reserve)
    equality_reserves = index_of_elements(inputs, Reserve; filters = [is_equality])
    inequality_reserves = index_of_elements(inputs, Reserve; filters = [is_equality])
    any_reserves_associated_with_thermal_units = any_elements(inputs, Reserve; filters = [has_thermal_unit])
    any_reserves_associated_with_hydro_units = any_elements(inputs, Reserve; filters = [has_hydro_unit])
    any_reserves_associated_with_battery_units = any_elements(inputs, Reserve; filters = [has_battery_unit])

    # Model Variables
    reserve_violation = get_model_object(model, :reserve_violation)
    reserve_generation_in_thermal_unit = if any_reserves_associated_with_thermal_units
        get_model_object(model, :reserve_generation_in_thermal_unit)
    end
    reserve_generation_in_hydro_unit = if any_reserves_associated_with_hydro_units
        get_model_object(model, :reserve_generation_in_hydro_unit)
    end
    reserve_generation_in_battery_unit = if any_reserves_associated_with_battery_units
        get_model_object(model, :reserve_generation_in_battery_unit)
    end

    # Model parameters
    reserve_requirement = get_model_object(model, :reserve_requirement)

    # Constraints
    @constraint(
        model.jump_model,
        reserve_equality_fulfillment[
            subperiod in subperiods(inputs),
            r in equality_reserves,
        ],
        reserve_angular_coefficient(inputs, r) * (
            sum(
                reserve_generation_in_thermal_unit[subperiod, r, j]
                for j in reserve_thermal_unit_indices(inputs, r);
                init = 0.0,
            ) +
            sum(
                reserve_generation_in_hydro_unit[subperiod, r, j]
                for j in reserve_hydro_unit_indices(inputs, r);
                init = 0.0,
            ) +
            sum(
                reserve_generation_in_battery_unit[subperiod, r, j]
                for j in reserve_battery_unit_indices(inputs, r);
                init = 0.0,
            )
        ) + reserve_linear_coefficient(inputs, r) ==
        reserve_requirement[subperiod, r] * subperiod_duration_in_hours(inputs, subperiod) -
        reserve_violation[subperiod, r]
    )

    @constraint(
        model.jump_model,
        reserve_inequality_fulfillment[
            subperiod in subperiods(inputs),
            r in inequality_reserves,
        ],
        reserve_angular_coefficient(inputs, r) * (
            sum(
                reserve_generation_in_thermal_unit[subperiod, r, j]
                for j in reserve_thermal_unit_indices(inputs, r);
                init = 0.0,
            ) +
            sum(
                reserve_generation_in_hydro_unit[subperiod, r, j]
                for j in reserve_hydro_unit_indices(inputs, r);
                init = 0.0,
            ) +
            sum(
                reserve_generation_in_battery_unit[subperiod, r, j]
                for j in reserve_battery_unit_indices(inputs, r);
                init = 0.0,
            )
        ) + reserve_linear_coefficient(inputs, r) >=
        reserve_requirement[subperiod, r] * subperiod_duration_in_hours(inputs, subperiod) -
        reserve_violation[subperiod, r]
    )

    return nothing
end

function reserve_fulfillment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function reserve_fulfillment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function reserve_fulfillment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    return nothing
end
