#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

abstract type AbstractAction end
abstract type SubproblemAction <: AbstractAction end # executed once or more per SDDP subproblem
abstract type ProblemAction <: AbstractAction end # executed once per SDDP problem

"""
    SubproblemBuild

Abstract type for subproblem actions that build the subproblem model.
"""
abstract type SubproblemBuild <: SubproblemAction end

"""
    SubproblemUpdate

Abstract type for subproblem actions that update the subproblem model.
"""
abstract type SubproblemUpdate <: SubproblemAction end

"""
    InitializeOutput

Abstract type for problem actions that initialize the output.
"""
abstract type InitializeOutput <: ProblemAction end

"""
    WriteOutput

Abstract type for problem actions that write the output.
"""
abstract type WriteOutput <: ProblemAction end

@kwdef mutable struct SubproblemModel
    jump_model::JuMP.Model
    obj_exp::Union{JuMP.AffExpr, JuMP.QuadExpr} = zero(JuMP.AffExpr)
    # The QuadExpr type is necessary because of POI, with products between variables and POI.parameters (treated as variables at first)
    node::Int
end

@kwdef mutable struct ProblemModel
    policy_graph::SDDP.PolicyGraph
end

"""
    get_model_object(sp_model::SubproblemModel, object_name::Symbol)    

Retrieve an object (variable, constraint or expression) from the `sp_model`'s JuMP model 
using the provided `object_name`. This allows flexible access to model components by name.
"""
function get_model_object(sp_model::SubproblemModel, object_name::Symbol)
    return sp_model.jump_model[object_name]
end

"""
    get_model_object(jump_model::Model, object_name::Symbol)    

Retrieve an object (variable, constraint or expression) from the `jump_model` 
using the provided `object_name`. This allows flexible access to model components by name.
"""
function get_model_object(jump_model::Model, object_name::Symbol)
    return jump_model[object_name]
end

"""
    constraint_dual_recorder(constraint_name::Symbol)

Return a function that retrieves the dual value of a constraint with the provided name.
"""
function constraint_dual_recorder(inputs::Inputs, constraint_name::Symbol)
    return (
        sp_model ->
            JuMP.dual.(sp_model[constraint_name]) * discount_rate_correction(inputs, SDDP.get_node(sp_model).index)
    )
end

function discount_rate_correction(inputs::Inputs, node::Int)
    if linear_policy_graph(inputs)
        return 1 / (1.0 - period_discount_rate(inputs))^(node - 1)
    else
        # TODO: Implement a more general discount rate correction for non-linear policy graphs
        return 1.0
    end
end

"""
    build_subproblem_model(
        inputs::Inputs,
        run_time_options::RunTimeOptions,
        period::Int;
        jump_model = JuMP.Model(),
    )

Build the subproblem model for the given period.
"""
function build_subproblem_model(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    node::Int;
    jump_model = JuMP.Model(),
)
    sp_model = SubproblemModel(; jump_model, node)
    model_action(sp_model, inputs, run_time_options, SubproblemBuild)

    obj_weight = if linear_policy_graph(inputs)
        (1.0 - period_discount_rate(inputs))^(node - 1)
    else
        1.0
    end
    @stageobjective(sp_model.jump_model, obj_weight * sp_model.obj_exp)

    return sp_model
end

"""
    model_action(args...)

Dispatch the model action based on the run mode and the action type.
"""
function model_action(args...)
    inputs = locate_inputs_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    if is_reference_curve(inputs, run_time_options)
        reference_curve_model_action(args...)
    elseif is_mincost(inputs, run_time_options)
        train_min_cost_model_action(args...)
    elseif is_current_asset_owner_price_taker(inputs, run_time_options)
        price_taker_bid_model_action(args...)
    elseif is_current_asset_owner_price_maker(inputs, run_time_options)
        price_maker_bid_model_action(args...)
    elseif is_market_clearing(inputs)
        market_clearing_model_action(args...)
    else
        error("Run mode $(run_mode(inputs)) not implemented")
    end
end

"""
    any_valid_elements(
        inputs::Inputs,
        run_time_options::RunTimeOptions,
        collection::Type{<:AbstractCollection},
        action::Type{<:AbstractAction};
        filters::Vector{<:Function} = Function[]
    )

Check if there are any valid elements in the collection for the given action.
"""
function any_valid_elements(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    collection::Type{<:AbstractCollection},
    action::Type{<:AbstractAction};
    @nospecialize(filters::Vector{<:Function} = Function[])
)
    if isa(action, SubproblemAction)
        updated_filters = [is_existing, filters]
        return any_elements(inputs, collection; run_time_options, filters = updated_filters)
    else
        return any_elements(inputs, collection; run_time_options, filters)
    end
end

"""
    train_min_cost_model_action(args...)

Min cost model action.
"""
function train_min_cost_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Model variables
    # ---------------
    if any_valid_elements(inputs, run_time_options, HydroUnit, action)
        hydro_generation!(args...)
        hydro_volume!(args...)
        hydro_inflow!(args...)
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_commitment])
            hydro_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalUnit, action)
        thermal_generation!(args...)
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_commitment])
            thermal_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewableUnit, action)
        renewable_generation!(args...)
    end
    if any_valid_elements(inputs, run_time_options, BatteryUnit, action)
        battery_unit_generation!(args...)
        battery_unit_storage!(args...)
    end
    if any_valid_elements(inputs, run_time_options, DemandUnit, action)
        demand!(args...)
        if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_elastic])
            elastic_demand!(args...)
        end
        if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_flexible])
            flexible_demand!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, DCLine, action)
        dc_flow!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Interconnection, action)
        interconnection_flow!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action)
        branch_flow!(args...)
        if some_branch_does_not_have_dc_flag(inputs)
            bus_voltage_angle!(args...)
        end
    end

    # Model constraints
    # -----------------
    load_balance!(args...)
    if any_valid_elements(inputs, run_time_options, HydroUnit, action)
        hydro_balance!(args...)
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_min_outflow])
            hydro_minimum_outflow!(args...)
        end
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_commitment])
            hydro_generation_bound_by_commitment!(args...)
        end
        if !read_inflow_from_file(inputs) && parp_max_lags(inputs) > 0
            parp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalUnit, action)
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_commitment])
            thermal_generation_bound_by_commitment!(args...)
            thermal_startup_and_shutdown!(args...)
            thermal_min_max_up_down_time!(args...)
        end
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_ramp_constraints])
            thermal_ramp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, BatteryUnit, action)
        battery_unit_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, RenewableUnit, action)
        renewable_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_elastic])
        elastic_demand_bounds!(args...)
    end
    if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_flexible])
        flexible_demand_shift_bounds!(args...)
        flexible_demand_window_maximum_curtailment!(args...)
        flexible_demand_window_sum!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action; filters = [is_ac])
        kirchhoffs_voltage_law!(args...)
    end

    return nothing
end

"""
    price_taker_bid_model_action(args...)

Price taker bid model action.
"""
function price_taker_bid_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Model variables
    # ---------------
    bidding_group_energy_bid!(args...)
    if any_valid_elements(inputs, run_time_options, HydroUnit, action)
        hydro_generation!(args...)
        hydro_volume!(args...)
        hydro_inflow!(args...)
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_min_outflow])
            hydro_minimum_outflow!(args...)
        end
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_commitment])
            hydro_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalUnit, action)
        thermal_generation!(args...)
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_commitment])
            thermal_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewableUnit, action)
        renewable_generation!(args...)
    end
    if any_valid_elements(inputs, run_time_options, BatteryUnit, action)
        battery_unit_generation!(args...)
        battery_unit_storage!(args...)
    end

    # Model constraints
    # -----------------
    link_bids_and_generation!(args...)
    if any_valid_elements(inputs, run_time_options, HydroUnit, action)
        hydro_balance!(args...)
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_commitment])
            hydro_generation_bound_by_commitment!(args...)
        end
        if !read_inflow_from_file(inputs) && parp_max_lags(inputs) > 0
            parp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalUnit, action)
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_commitment])
            thermal_generation_bound_by_commitment!(args...)
            thermal_startup_and_shutdown!(args...)
            thermal_min_max_up_down_time!(args...)
        end
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_ramp_constraints])
            thermal_ramp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, BatteryUnit, action)
        battery_unit_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, RenewableUnit, action)
        renewable_balance!(args...)
    end

    return nothing
end

"""
    price_maker_bid_model_action(args...)

Strategic bid model action.
"""
function price_maker_bid_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Model variables
    # ---------------
    bidding_group_energy_bid!(args...)
    convex_hull_coefficients!(args...)
    if any_valid_elements(inputs, run_time_options, HydroUnit, action)
        hydro_generation!(args...)
        hydro_volume!(args...)
        hydro_inflow!(args...)
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_min_outflow])
            hydro_minimum_outflow!(args...)
        end
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_commitment])
            hydro_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalUnit, action)
        thermal_generation!(args...)
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_commitment])
            thermal_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewableUnit, action)
        renewable_generation!(args...)
    end
    if any_valid_elements(inputs, run_time_options, BatteryUnit, action)
        battery_unit_generation!(args...)
        battery_unit_storage!(args...)
    end

    # Model constraints
    # -----------------
    link_bids_and_generation!(args...)
    revenue_convex_combination!(args...)
    if any_valid_elements(inputs, run_time_options, HydroUnit, action)
        hydro_balance!(args...)
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_commitment])
            hydro_generation_bound_by_commitment!(args...)
        end
        if !read_inflow_from_file(inputs) && parp_max_lags(inputs) > 0
            parp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalUnit, action)
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_commitment])
            thermal_generation_bound_by_commitment!(args...)
            thermal_startup_and_shutdown!(args...)
            thermal_min_max_up_down_time!(args...)
        end
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_ramp_constraints])
            thermal_ramp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, BatteryUnit, action)
        battery_unit_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, RenewableUnit, action)
        renewable_balance!(args...)
    end

    return nothing
end

"""
    market_clearing_model_action(args...)

Market clearing model action.
"""
function market_clearing_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    if construction_type(inputs, run_time_options) == Configurations_ConstructionType.HYBRID
        hybrid_market_clearing_model_action(args...)
    elseif construction_type(inputs, run_time_options) == Configurations_ConstructionType.COST_BASED
        cost_based_market_clearing_model_action(args...)
    elseif construction_type(inputs, run_time_options) == Configurations_ConstructionType.BID_BASED
        bid_based_market_clearing_model_action(args...)
    elseif construction_type(inputs, run_time_options) == Configurations_ConstructionType.SKIP
        nothing
    else
        error("Clearing model type $(construction_type(inputs)) not implemented")
    end

    return nothing
end

function hybrid_market_clearing_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Model variables
    # ---------------

    if any_valid_elements(inputs, run_time_options, HydroUnit, action)
        hydro_generation!(args...)
        hydro_volume!(args...)
        hydro_inflow!(args...)
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_commitment])
            hydro_commitment!(args...)
        end
        if clearing_hydro_representation(inputs) ==
           Configurations_VirtualReservoirBidProcessing.HEURISTIC_BID_FROM_WATER_VALUES
            virtual_reservoir_generation!(args...)
            virtual_reservoir_volume_distance_to_waveguide!(args...)
            virtual_reservoir_energy_account!(args...)
            virtual_reservoir_generation_bounds_values!(args...)
        end
    end

    if any_valid_elements(inputs, run_time_options, DemandUnit, action)
        demand!(args...)
        if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_elastic])
            elastic_demand!(args...)
        end
        if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_flexible])
            flexible_demand!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, DCLine, action)
        dc_flow!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Interconnection, action)
        interconnection_flow!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action)
        branch_flow!(args...)
        if some_branch_does_not_have_dc_flag(inputs)
            bus_voltage_angle!(args...)
        end
    end

    if any_valid_elements(inputs, run_time_options, ThermalUnit, action)
        thermal_generation!(args...)
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_commitment])
            thermal_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewableUnit, action)
        renewable_generation!(args...)
    end
    if any_valid_elements(inputs, run_time_options, BatteryUnit, action)
        battery_unit_generation!(args...)
        battery_unit_storage!(args...)
    end

    if has_any_simple_bids(inputs)
        bidding_group_generation!(args...)
    end

    if has_any_profile_bids(inputs)
        bidding_group_profile_energy_bid!(args...)
        if has_any_profile_complex_bids(inputs)
            profile_min_activation_level!(args...)
        end
    end

    # Model constraints
    # -----------------
    if has_any_simple_bids(inputs)
        bidding_group_generation_bound_by_bid!(args...)
    end

    load_balance!(args...)
    if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_elastic])
        elastic_demand_bounds!(args...)
    end
    if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_flexible])
        flexible_demand_shift_bounds!(args...)
        flexible_demand_window_maximum_curtailment!(args...)
        flexible_demand_window_sum!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action; filters = [is_ac])
        kirchhoffs_voltage_law!(args...)
    end
    if has_any_profile_bids(inputs)
        bidding_group_profile_generation_bound_by_bid!(args...)
        if has_any_profile_complex_bids(inputs)
            bidding_group_profile_complementary_profile!(args...)
            bidding_group_profile_minimum_activation!(args...)
            bidding_group_profile_precedence!(args...)
        end
    end

    if any_valid_elements(inputs, run_time_options, HydroUnit, action)
        hydro_balance!(args...)
        if !read_inflow_from_file(inputs) && parp_max_lags(inputs) > 0
            parp!(args...)
        end

        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_commitment])
            hydro_generation_bound_by_commitment!(args...)
        end
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_min_outflow])
            hydro_minimum_outflow!(args...)
        end

        if clearing_hydro_representation(inputs) ==
           Configurations_VirtualReservoirBidProcessing.HEURISTIC_BID_FROM_WATER_VALUES
            if virtual_reservoir_correspondence_type(inputs) ==
               Configurations_VirtualReservoirCorrespondenceType.STANDARD_CORRESPONDENCE_CONSTRAINT
                virtual_reservoir_correspondence_by_volume!(args...)
            elseif virtual_reservoir_correspondence_type(inputs) ==
                   Configurations_VirtualReservoirCorrespondenceType.DELTA_CORRESPONDENCE_CONSTRAINT
                virtual_reservoir_correspondence_by_generation!(args...)
            end
            virtual_reservoir_generation_bounds!(args...)
            waveguide_convex_combination_sum!(args...)
            waveguide_distance_bounds!(args...)
        end
    end

    if any_valid_elements(inputs, run_time_options, ThermalUnit, action)
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_commitment])
            thermal_generation_bound_by_commitment!(args...)
            thermal_startup_and_shutdown!(args...)
            thermal_min_max_up_down_time!(args...)
        end
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_ramp_constraints])
            thermal_ramp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewableUnit, action)
        renewable_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, BatteryUnit, action)
        battery_unit_balance!(args...)
    end

    link_bids_and_generation!(args...)

    return nothing
end

"""
    cost_based_market_clearing_model_action(args...)

Cost based market clearing model action.
"""
function cost_based_market_clearing_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Model variables
    # ---------------
    if any_valid_elements(inputs, run_time_options, HydroUnit, action)
        hydro_generation!(args...)
        hydro_volume!(args...)
        hydro_inflow!(args...)
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_commitment])
            hydro_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalUnit, action)
        thermal_generation!(args...)
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_commitment])
            thermal_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewableUnit, action)
        renewable_generation!(args...)
    end
    if any_valid_elements(inputs, run_time_options, BatteryUnit, action)
        battery_unit_generation!(args...)
        battery_unit_storage!(args...)
    end
    if any_valid_elements(inputs, run_time_options, DemandUnit, action)
        demand!(args...)
        if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_elastic])
            elastic_demand!(args...)
        end
        if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_flexible])
            flexible_demand!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, DCLine, action)
        dc_flow!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Interconnection, action)
        interconnection_flow!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action)
        branch_flow!(args...)
        if some_branch_does_not_have_dc_flag(inputs)
            bus_voltage_angle!(args...)
        end
    end

    # Model constraints
    # -----------------
    load_balance!(args...)
    if any_valid_elements(inputs, run_time_options, HydroUnit, action)
        hydro_balance!(args...)
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_min_outflow])
            hydro_minimum_outflow!(args...)
        end
        if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_commitment])
            hydro_generation_bound_by_commitment!(args...)
        end
        if !read_inflow_from_file(inputs) && parp_max_lags(inputs) > 0
            parp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalUnit, action)
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_commitment])
            thermal_generation_bound_by_commitment!(args...)
            thermal_startup_and_shutdown!(args...)
            thermal_min_max_up_down_time!(args...)
        end
        if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_ramp_constraints])
            thermal_ramp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, BatteryUnit, action)
        battery_unit_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, RenewableUnit, action)
        renewable_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_elastic])
        elastic_demand_bounds!(args...)
    end
    if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_flexible])
        flexible_demand_shift_bounds!(args...)
        flexible_demand_window_maximum_curtailment!(args...)
        flexible_demand_window_sum!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action; filters = [is_ac])
        kirchhoffs_voltage_law!(args...)
    end

    return nothing
end

"""
    bid_based_market_clearing_model_action(args...)

Bid based market clearing model action.
"""
function bid_based_market_clearing_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Model variables
    # ---------------
    if has_any_simple_bids(inputs)
        bidding_group_generation!(args...)
    end

    # For clearing problems with BID_BASED representation, physical variables are only created for units without bidding groups
    if any_valid_elements(inputs, run_time_options, HydroUnit, action; filters = [has_no_bidding_group])
        hydro_generation!(args...)
        hydro_volume!(args...)
        hydro_inflow!(args...)
        if any_valid_elements(
            inputs,
            run_time_options,
            HydroUnit,
            action;
            filters = [has_no_bidding_group, has_commitment],
        )
            hydro_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalUnit, action; filters = [has_no_bidding_group])
        thermal_generation!(args...)
        if any_valid_elements(
            inputs,
            run_time_options,
            ThermalUnit,
            action;
            filters = [has_no_bidding_group, has_commitment],
        )
            thermal_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewableUnit, action; filters = [has_no_bidding_group])
        renewable_generation!(args...)
    end
    if any_valid_elements(inputs, run_time_options, BatteryUnit, action; filters = [has_no_bidding_group])
        battery_unit_generation!(args...)
        battery_unit_storage!(args...)
    end

    if any_valid_elements(inputs, run_time_options, DemandUnit, action)
        demand!(args...)
        if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_elastic])
            elastic_demand!(args...)
        end
        if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_flexible])
            flexible_demand!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, DCLine, action)
        dc_flow!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Interconnection, action)
        interconnection_flow!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action)
        branch_flow!(args...)
        if some_branch_does_not_have_dc_flag(inputs)
            bus_voltage_angle!(args...)
        end
    end
    if has_any_profile_bids(inputs)
        bidding_group_profile_energy_bid!(args...)
        if has_any_profile_complex_bids(inputs)
            profile_min_activation_level!(args...)
        end
    end

    # Model constraints
    # -----------------
    if has_any_simple_bids(inputs)
        bidding_group_generation_bound_by_bid!(args...)
    end

    load_balance!(args...)
    if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_elastic])
        elastic_demand_bounds!(args...)
    end
    if any_valid_elements(inputs, run_time_options, DemandUnit, action; filters = [is_flexible])
        flexible_demand_shift_bounds!(args...)
        flexible_demand_window_maximum_curtailment!(args...)
        flexible_demand_window_sum!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action; filters = [is_ac])
        kirchhoffs_voltage_law!(args...)
    end
    if has_any_profile_bids(inputs)
        bidding_group_profile_generation_bound_by_bid!(args...)
        if has_any_profile_complex_bids(inputs)
            bidding_group_profile_complementary_profile!(args...)
            bidding_group_profile_minimum_activation!(args...)
            bidding_group_profile_precedence!(args...)
        end
    end

    return nothing
end

function reference_curve_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Variables
    if any_valid_elements(inputs, run_time_options, HydroUnit, action)
        hydro_generation!(args...)
        hydro_volume!(args...)
        hydro_inflow!(args...)
        virtual_reservoir_total_generation!(args...)
        virtual_reservoir_previous_reference_quantity!(args...)
    end

    # Constraints
    if any_valid_elements(inputs, run_time_options, HydroUnit, action)
        hydro_balance!(args...)
        virtual_reservoir_total_generation_correspondence!(args...)
        virtual_reservoir_generation_reference!(args...)
        virtual_reservoir_non_decreasing_reference_quantity!(args...)
    end

    return nothing
end
