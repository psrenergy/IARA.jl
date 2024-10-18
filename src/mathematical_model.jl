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
    stage::Int
end

@kwdef mutable struct ProblemModel
    policy_graph::SDDP.PolicyGraph
end

function get_model_object(sp_model::SubproblemModel, object_name::Symbol)
    return sp_model.jump_model[object_name]
end

function constraint_dual_recorder(constraint_name::Symbol)
    return (sp_model -> JuMP.dual.(sp_model[constraint_name]))
end

function build_subproblem_model(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    stage::Int;
    jump_model = JuMP.Model(),
)
    sp_model = SubproblemModel(; jump_model = jump_model, stage = stage)
    model_action(sp_model, inputs, run_time_options, SubproblemBuild)

    obj_weight = if linear_policy_graph(inputs)
        (1.0 - stage_discount_rate(inputs))^(stage - 1)
    else
        1.0
    end
    @stageobjective(sp_model.jump_model, obj_weight * sp_model.obj_exp)

    return sp_model
end

function model_action(args...)
    inputs = locate_inputs_in_args(args...)

    if run_mode(inputs) == Configurations_RunMode.CENTRALIZED_OPERATION
        centralized_operation_model_action(args...)
    elseif run_mode(inputs) == Configurations_RunMode.PRICE_TAKER_BID
        price_taker_bid_model_action(args...)
    elseif run_mode(inputs) == Configurations_RunMode.STRATEGIC_BID
        strategic_bid_model_action(args...)
    elseif run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING
        market_clearing_model_action(args...)
    else
        error("Run mode $(run_mode(inputs)) not implemented")
    end
end

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

function centralized_operation_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Model variables
    # ---------------
    if any_valid_elements(inputs, run_time_options, HydroPlant, action)
        hydro_generation!(args...)
        hydro_volume!(args...)
        hydro_inflow!(args...)
        if any_valid_elements(inputs, run_time_options, HydroPlant, action; filters = [has_commitment])
            hydro_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalPlant, action)
        thermal_generation!(args...)
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_commitment])
            thermal_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewablePlant, action)
        renewable_generation!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Battery, action)
        battery_generation!(args...)
        battery_storage!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Demand, action)
        demand!(args...)
        if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_elastic])
            elastic_demand!(args...)
        end
        if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_flexible])
            flexible_demand!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, DCLine, action)
        dc_flow!(args...)
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
    if any_valid_elements(inputs, run_time_options, HydroPlant, action)
        hydro_balance!(args...)
        if any_valid_elements(inputs, run_time_options, HydroPlant, action; filters = [has_min_outflow])
            hydro_minimum_outflow!(args...)
        end
        if any_valid_elements(inputs, run_time_options, HydroPlant, action; filters = [has_commitment])
            hydro_generation_bound_by_commitment!(args...)
        end
        if !read_inflow_from_file(inputs) && parp_max_lags(inputs) > 0
            parp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalPlant, action)
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_commitment])
            thermal_generation_bound_by_commitment!(args...)
            thermal_startup_and_shutdown!(args...)
            thermal_min_max_up_down_time!(args...)
        end
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_ramp_constraints])
            thermal_ramp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, Battery, action)
        battery_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, RenewablePlant, action)
        renewable_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_elastic])
        elastic_demand_bounds!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_flexible])
        flexible_demand_shift_bounds!(args...)
        flexible_demand_window_maximum_curtailment!(args...)
        flexible_demand_window_sum!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action; filters = [is_ac])
        kirchhoffs_voltage_law!(args...)
    end

    return nothing
end

function price_taker_bid_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Model variables
    # ---------------
    bidding_group_energy_offer!(args...)
    if any_valid_elements(inputs, run_time_options, HydroPlant, action)
        hydro_generation!(args...)
        hydro_volume!(args...)
        hydro_inflow!(args...)
        if any_valid_elements(inputs, run_time_options, HydroPlant, action; filters = [has_min_outflow])
            hydro_minimum_outflow!(args...)
        end
        if any_valid_elements(inputs, run_time_options, HydroPlant, action; filters = [has_commitment])
            hydro_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalPlant, action)
        thermal_generation!(args...)
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_commitment])
            thermal_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewablePlant, action)
        renewable_generation!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Battery, action)
        battery_generation!(args...)
        battery_storage!(args...)
    end

    # Model constraints
    # -----------------
    bidding_group_balance!(args...)
    if any_valid_elements(inputs, run_time_options, HydroPlant, action)
        hydro_balance!(args...)
        if any_valid_elements(inputs, run_time_options, HydroPlant, action; filters = [has_commitment])
            hydro_generation_bound_by_commitment!(args...)
        end
        if !read_inflow_from_file(inputs) && parp_max_lags(inputs) > 0
            parp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalPlant, action)
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_commitment])
            thermal_generation_bound_by_commitment!(args...)
            thermal_startup_and_shutdown!(args...)
            thermal_min_max_up_down_time!(args...)
        end
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_ramp_constraints])
            thermal_ramp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, Battery, action)
        battery_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, RenewablePlant, action)
        renewable_balance!(args...)
    end

    return nothing
end

function strategic_bid_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Model variables
    # ---------------
    bidding_group_energy_offer!(args...)
    convex_hull_coefficients!(args...)
    if any_valid_elements(inputs, run_time_options, HydroPlant, action)
        hydro_generation!(args...)
        hydro_volume!(args...)
        hydro_inflow!(args...)
        if any_valid_elements(inputs, run_time_options, HydroPlant, action; filters = [has_min_outflow])
            hydro_minimum_outflow!(args...)
        end
        if any_valid_elements(inputs, run_time_options, HydroPlant, action; filters = [has_commitment])
            hydro_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalPlant, action)
        thermal_generation!(args...)
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_commitment])
            thermal_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewablePlant, action)
        renewable_generation!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Battery, action)
        battery_generation!(args...)
        battery_storage!(args...)
    end

    # Model constraints
    # -----------------
    bidding_group_balance!(args...)
    revenue_convex_combination!(args...)
    if any_valid_elements(inputs, run_time_options, HydroPlant, action)
        hydro_balance!(args...)
        if any_valid_elements(inputs, run_time_options, HydroPlant, action; filters = [has_commitment])
            hydro_generation_bound_by_commitment!(args...)
        end
        if !read_inflow_from_file(inputs) && parp_max_lags(inputs) > 0
            parp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalPlant, action)
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_commitment])
            thermal_generation_bound_by_commitment!(args...)
            thermal_startup_and_shutdown!(args...)
            thermal_min_max_up_down_time!(args...)
        end
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_ramp_constraints])
            thermal_ramp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, Battery, action)
        battery_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, RenewablePlant, action)
        renewable_balance!(args...)
    end

    return nothing
end

function market_clearing_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    if clearing_model_type(inputs, run_time_options) == Configurations_ClearingModelType.HYBRID
        hybrid_market_clearing_model_action(args...)
    elseif clearing_model_type(inputs, run_time_options) == Configurations_ClearingModelType.COST_BASED
        cost_based_market_clearing_model_action(args...)
    elseif clearing_model_type(inputs, run_time_options) == Configurations_ClearingModelType.BID_BASED
        bid_based_market_clearing_model_action(args...)
    else
        error("Clearing model $(clearing_model(inputs)) not implemented")
    end

    return nothing
end

function hybrid_market_clearing_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Model variables
    # ---------------

    if any_valid_elements(inputs, run_time_options, HydroPlant, action)
        hydro_generation!(args...)
        hydro_volume!(args...)
        hydro_inflow!(args...)
        if any_valid_elements(
            inputs,
            run_time_options,
            HydroPlant,
            action;
            filters = [has_commitment, is_associated_with_some_virtual_reservoir],
        )
            hydro_commitment!(args...)
        end
        if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
            virtual_reservoir_generation!(args...)
            virtual_reservoir_volume_distance_to_waveguide!(args...)
            virtual_reservoir_energy_stock!(args...)
        end
    end

    if any_valid_elements(inputs, run_time_options, Demand, action)
        demand!(args...)
        if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_elastic])
            elastic_demand!(args...)
        end
        if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_flexible])
            flexible_demand!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, DCLine, action)
        dc_flow!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action)
        branch_flow!(args...)
        if some_branch_does_not_have_dc_flag(inputs)
            bus_voltage_angle!(args...)
        end
    end

    if any_valid_elements(inputs, run_time_options, ThermalPlant, action)
        thermal_generation!(args...)
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_commitment])
            thermal_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewablePlant, action)
        renewable_generation!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Battery, action)
        battery_generation!(args...)
        battery_storage!(args...)
    end

    if any_valid_elements(inputs, run_time_options, BiddingGroup, action)
        bidding_group_generation!(args...)
    end

    if any_valid_elements(inputs, run_time_options, BiddingGroup, action; filters = [has_multihour_bids])
        bidding_group_multihour_energy_offer!(args...)
        if has_any_multihour_complex_input_files(inputs)
            multihour_min_activation_level!(args...)
        end
    end

    # Model constraints
    # -----------------
    if any_valid_elements(inputs, run_time_options, BiddingGroup, action)
        bidding_group_generation_bound_by_offer!(args...)
    end

    load_balance!(args...)
    if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_elastic])
        elastic_demand_bounds!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_flexible])
        flexible_demand_shift_bounds!(args...)
        flexible_demand_window_maximum_curtailment!(args...)
        flexible_demand_window_sum!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action; filters = [is_ac])
        kirchhoffs_voltage_law!(args...)
    end
    if any_valid_elements(inputs, run_time_options, BiddingGroup, action; filters = [has_multihour_bids])
        bidding_group_multihour_generation_bound_by_offer!(args...)
        if has_any_multihour_complex_input_files(inputs)
            bidding_group_multihour_complementary_profile!(args...)
            bidding_group_multihour_minimum_activation!(args...)
            bidding_group_multihour_precedence!(args...)
        end
    end

    if any_valid_elements(inputs, run_time_options, HydroPlant, action)
        hydro_balance!(args...)
        if !read_inflow_from_file(inputs) && parp_max_lags(inputs) > 0
            parp!(args...)
        end

        if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
            if any_valid_elements(
                inputs,
                run_time_options,
                HydroPlant,
                action;
                filters = [has_commitment, is_associated_with_some_virtual_reservoir],
            )
                hydro_generation_bound_by_commitment!(args...)
            end
            if any_valid_elements(
                inputs,
                run_time_options,
                HydroPlant,
                action;
                filters = [has_min_outflow, is_associated_with_some_virtual_reservoir],
            )
                hydro_minimum_outflow!(args...)
            end
            virtual_reservoir_volume_balance!(args...)
            virtual_reservoir_generation_bounds!(args...)
            waveguide_convex_combination_sum!(args...)
        end
    end

    if any_valid_elements(inputs, run_time_options, ThermalPlant, action)
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_commitment])
            thermal_generation_bound_by_commitment!(args...)
            thermal_startup_and_shutdown!(args...)
            thermal_min_max_up_down_time!(args...)
        end
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_ramp_constraints])
            thermal_ramp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewablePlant, action)
        renewable_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Battery, action)
        battery_balance!(args...)
    end

    link_offers_and_generation!(args...)

    return nothing
end

function cost_based_market_clearing_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Model variables
    # ---------------
    if any_valid_elements(inputs, run_time_options, HydroPlant, action)
        hydro_generation!(args...)
        hydro_volume!(args...)
        hydro_inflow!(args...)
        if any_valid_elements(inputs, run_time_options, HydroPlant, action; filters = [has_commitment])
            hydro_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalPlant, action)
        thermal_generation!(args...)
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_commitment])
            thermal_commitment!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, RenewablePlant, action)
        renewable_generation!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Battery, action)
        battery_generation!(args...)
        battery_storage!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Demand, action)
        demand!(args...)
        if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_elastic])
            elastic_demand!(args...)
        end
        if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_flexible])
            flexible_demand!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, DCLine, action)
        dc_flow!(args...)
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
    if any_valid_elements(inputs, run_time_options, HydroPlant, action)
        hydro_balance!(args...)
        if any_valid_elements(inputs, run_time_options, HydroPlant, action; filters = [has_min_outflow])
            hydro_minimum_outflow!(args...)
        end
        if any_valid_elements(inputs, run_time_options, HydroPlant, action; filters = [has_commitment])
            hydro_generation_bound_by_commitment!(args...)
        end
        if !read_inflow_from_file(inputs) && parp_max_lags(inputs) > 0
            parp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, ThermalPlant, action)
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_commitment])
            thermal_generation_bound_by_commitment!(args...)
            thermal_startup_and_shutdown!(args...)
            thermal_min_max_up_down_time!(args...)
        end
        if any_valid_elements(inputs, run_time_options, ThermalPlant, action; filters = [has_ramp_constraints])
            thermal_ramp!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, Battery, action)
        battery_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, RenewablePlant, action)
        renewable_balance!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_elastic])
        elastic_demand_bounds!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_flexible])
        flexible_demand_shift_bounds!(args...)
        flexible_demand_window_maximum_curtailment!(args...)
        flexible_demand_window_sum!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action; filters = [is_ac])
        kirchhoffs_voltage_law!(args...)
    end

    return nothing
end

function bid_based_market_clearing_model_action(args...)
    inputs = locate_inputs_in_args(args...)
    action = locate_action_in_args(args...)
    run_time_options = locate_run_time_options_in_args(args...)

    # Model variables
    # ---------------
    if any_valid_elements(inputs, run_time_options, BiddingGroup, action)
        bidding_group_generation!(args...)
    end

    if any_valid_elements(inputs, run_time_options, Demand, action)
        demand!(args...)
        if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_elastic])
            elastic_demand!(args...)
        end
        if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_flexible])
            flexible_demand!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, DCLine, action)
        dc_flow!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action)
        branch_flow!(args...)
        if some_branch_does_not_have_dc_flag(inputs)
            bus_voltage_angle!(args...)
        end
    end
    if any_valid_elements(inputs, run_time_options, BiddingGroup, action; filters = [has_multihour_bids])
        bidding_group_multihour_energy_offer!(args...)
        if has_any_multihour_complex_input_files(inputs)
            multihour_min_activation_level!(args...)
        end
    end

    # Model constraints
    # -----------------
    if any_valid_elements(inputs, run_time_options, BiddingGroup, action)
        bidding_group_generation_bound_by_offer!(args...)
    end

    load_balance!(args...)
    if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_elastic])
        elastic_demand_bounds!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Demand, action; filters = [is_flexible])
        flexible_demand_shift_bounds!(args...)
        flexible_demand_window_maximum_curtailment!(args...)
        flexible_demand_window_sum!(args...)
    end
    if any_valid_elements(inputs, run_time_options, Branch, action; filters = [is_ac])
        kirchhoffs_voltage_law!(args...)
    end
    if any_valid_elements(inputs, run_time_options, BiddingGroup, action; filters = [has_multihour_bids])
        bidding_group_multihour_generation_bound_by_offer!(args...)
        if has_any_multihour_complex_input_files(inputs)
            bidding_group_multihour_complementary_profile!(args...)
            bidding_group_multihour_minimum_activation!(args...)
            bidding_group_multihour_precedence!(args...)
        end
    end

    return nothing
end
