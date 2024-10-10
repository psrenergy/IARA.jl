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
    any_reserves_associated_with_thermal_plants = any_elements(inputs, Reserve; filters = [has_thermal_plant])
    any_reserves_associated_with_hydro_plants = any_elements(inputs, Reserve; filters = [has_hydro_plant])
    any_reserves_associated_with_batteries = any_elements(inputs, Reserve; filters = [has_battery])

    # Model Variables
    reserve_violation = get_model_object(model, :reserve_violation)
    reserve_generation_in_thermal_plant = if any_reserves_associated_with_thermal_plants
        get_model_object(model, :reserve_generation_in_thermal_plant)
    end
    reserve_generation_in_hydro_plant = if any_reserves_associated_with_hydro_plants
        get_model_object(model, :reserve_generation_in_hydro_plant)
    end
    reserve_generation_in_battery = if any_reserves_associated_with_batteries
        get_model_object(model, :reserve_generation_in_battery)
    end

    # Model parameters
    reserve_requirement = get_model_object(model, :reserve_requirement)

    # Constraints
    @constraint(
        model.jump_model,
        reserve_equality_fulfillment[
            block in blocks(inputs),
            r in equality_reserves,
        ],
        reserve_angular_coefficient(inputs, r) * (
            sum(
                reserve_generation_in_thermal_plant[block, r, j]
                for j in reserve_thermal_plant_indices(inputs, r);
                init = 0.0,
            ) +
            sum(
                reserve_generation_in_hydro_plant[block, r, j]
                for j in reserve_hydro_plant_indices(inputs, r);
                init = 0.0,
            ) +
            sum(
                reserve_generation_in_battery[block, r, j]
                for j in reserve_battery_indices(inputs, r);
                init = 0.0,
            )
        ) + reserve_linear_coefficient(inputs, r) ==
        reserve_requirement[block, r] * block_duration_in_hours(inputs, block) - reserve_violation[block, r]
    )

    @constraint(
        model.jump_model,
        reserve_inequality_fulfillment[
            block in blocks(inputs),
            r in inequality_reserves,
        ],
        reserve_angular_coefficient(inputs, r) * (
            sum(
                reserve_generation_in_thermal_plant[block, r, j]
                for j in reserve_thermal_plant_indices(inputs, r);
                init = 0.0,
            ) +
            sum(
                reserve_generation_in_hydro_plant[block, r, j]
                for j in reserve_hydro_plant_indices(inputs, r);
                init = 0.0,
            ) +
            sum(
                reserve_generation_in_battery[block, r, j]
                for j in reserve_battery_indices(inputs, r);
                init = 0.0,
            )
        ) + reserve_linear_coefficient(inputs, r) >=
        reserve_requirement[block, r] * block_duration_in_hours(inputs, block) - reserve_violation[block, r]
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
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    return nothing
end
