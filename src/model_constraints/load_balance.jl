#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function load_balance! end

# Important notes for this implementation:
# Flow is in [MW], generation and deficit are in [MWh], demand is in [GWh]

function zonal_physical_generation_expression(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    # For clearing problems with BID_BASED or HYBRID representation, 
    # physical generation variables are used only for units without bidding groups
    filters =
        if run_mode(inputs) == RunMode.TRAIN_MIN_COST ||
           run_mode(inputs) == RunMode.MIN_COST ||
           construction_type(inputs, run_time_options) == Configurations_ConstructionType.COST_BASED
            [is_existing]
        else
            [is_existing, has_no_bidding_group]
        end
    hydro_filters =
        if run_mode(inputs) == RunMode.TRAIN_MIN_COST ||
           run_mode(inputs) == RunMode.MIN_COST ||
           construction_type(inputs, run_time_options) == Configurations_ConstructionType.COST_BASED
            [is_existing]
        else
            [is_existing, has_no_bidding_group, !is_associated_with_some_virtual_reservoir]
        end
    zones = index_of_elements(inputs, Zone)
    blks = subperiods(inputs)
    hydro_units = index_of_elements(inputs, HydroUnit; filters = hydro_filters)
    thermal_units = index_of_elements(inputs, ThermalUnit; filters = filters)
    renewable_units = index_of_elements(inputs, RenewableUnit; filters = filters)
    battery_units = index_of_elements(inputs, BatteryUnit; filters = filters)
    # Centralized Operation Variables
    hydro_generation = if any_elements(inputs, HydroUnit; filters = hydro_filters)
        get_model_object(model, :hydro_generation)
    end
    thermal_generation = if any_elements(inputs, ThermalUnit; filters = filters)
        get_model_object(model, :thermal_generation)
    end
    renewable_generation = if any_elements(inputs, RenewableUnit; filters = filters)
        get_model_object(model, :renewable_generation)
    end
    battery_unit_generation = if any_elements(inputs, BatteryUnit; filters = filters)
        get_model_object(model, :battery_unit_generation)
    end
    # Centralized Operation Generation
    @expression(
        model.jump_model,
        physical_generation[blk in blks, zone in zones],
        sum(
            hydro_generation[blk, h] for
            h in hydro_units if hydro_unit_zone_index(inputs, h) == zone;
            init = 0.0,
        ) +
        sum(
            thermal_generation[blk, t] for
            t in thermal_units if thermal_unit_zone_index(inputs, t) == zone;
            init = 0.0,
        ) +
        sum(
            renewable_generation[blk, r] for
            r in renewable_units if renewable_unit_zone_index(inputs, r) == zone;
            init = 0.0,
        ) +
        sum(
            battery_unit_generation[blk, bat] for
            bat in battery_units if battery_unit_zone_index(inputs, bat) == zone;
            init = 0.0,
        )
    )

    return physical_generation
end

function zonal_bid_generation_expression(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    zones = index_of_elements(inputs, Zone)
    blks = subperiods(inputs)
    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    hydro_units = index_of_elements(inputs, HydroUnit; filters = [is_existing])
    buses = index_of_elements(inputs, Bus)

    # Market Clearing Variables
    bidding_group_generation_profile = if has_any_profile_bids(inputs)
        get_model_object(model, :bidding_group_generation_profile)
    end
    bidding_group_generation =
        if any_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
            get_model_object(model, :bidding_group_generation)
        end
    hydro_generation = if any_elements(inputs, VirtualReservoir)
        get_model_object(model, :hydro_generation)
    end

    if has_any_simple_bids(inputs)
        valid_segments = get_maximum_valid_segments(inputs)
    end

    if has_any_profile_bids(inputs)
        valid_profiles = get_maximum_valid_profiles(inputs)
    end

    # Market Clearing Generation
    @expression(
        model.jump_model,
        bid_generation[blk in blks, zone in zones],
        if has_any_simple_bids(inputs)
            # The double for loop is necessary, otherwise it breaks
            sum(
                bidding_group_generation[blk, bg, bds, bus] for
                bus in buses, bg in bidding_groups for bds in 1:valid_segments[bg] if
                bus_zone_index(inputs, bus) == zone;
                init = 0.0,
            )
        else
            0.0
        end
        +
        if has_any_profile_bids(inputs)
            sum(
                bidding_group_generation_profile[blk, bg, prf, bus] for
                bus in buses, bg in bidding_groups for prf in 1:valid_profiles[bg] if
                bus_zone_index(inputs, bus) == zone;
                init = 0.0,
            )
        else
            0.0
        end
        +
        sum(
            hydro_generation[blk, h] for
            h in hydro_units if
            hydro_unit_zone_index(inputs, h) == zone &&
            is_associated_with_some_virtual_reservoir(inputs.collections.hydro_unit, h);
            init = 0.0,
        )
    )
    return bid_generation
end

function zonal_transmission_expression(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    zones = index_of_elements(inputs, Zone)
    blks = subperiods(inputs)
    interconnections = index_of_elements(inputs, Interconnection; filters = [is_existing])
    interconnection_flow = if any_elements(inputs, Interconnection; filters = [is_existing])
        get_model_object(model, :interconnection_flow)
    end

    @expression(
        model.jump_model,
        transmission[blk in blks, zone in zones],
        subperiod_duration_in_hours(inputs, blk) * (
            sum(
                interconnection_flow[blk, interc] for
                interc in interconnections if interconnection_zone_to(inputs, interc) == zone;
                init = 0.0,
            ) +
            sum(
                -interconnection_flow[blk, interc] for
                interc in interconnections if interconnection_zone_from(inputs, interc) == zone;
                init = 0.0,
            )
        )
    )
    return transmission
end

function zonal_demand_expression(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    zones = index_of_elements(inputs, Zone)
    blks = subperiods(inputs)
    inelastic_demands = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_inelastic])
    elastic_demands = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_elastic])
    flexible_demands = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_flexible])
    # Model Variables
    deficit = if any_elements(inputs, DemandUnit; filters = [is_existing])
        get_model_object(model, :deficit)
    end
    attended_elastic_demand = if any_elements(inputs, DemandUnit; filters = [is_existing, is_elastic])
        get_model_object(model, :attended_elastic_demand)
    end
    attended_flexible_demand = if any_elements(inputs, DemandUnit; filters = [is_existing, is_flexible])
        get_model_object(model, :attended_flexible_demand)
    end

    # Model parameters
    demand = if any_elements(inputs, DemandUnit; filters = [is_existing])
        get_model_object(model, :demand)
    end

    @expression(
        model.jump_model,
        net_demand[blk in blks, zone in zones],
        sum(
            demand[blk, d]
            for d in inelastic_demands if demand_unit_zone_index(inputs, d) == zone;
            init = 0.0,
        ) / MW_to_GW() -
        sum(
            deficit[blk, d] for
            d in inelastic_demands if demand_unit_zone_index(inputs, d) == zone;
            init = 0.0,
        ) +
        # The attended elastic demand is considered a bid offer in the market clearing case.
        if is_mincost(inputs) ||
           construction_type(inputs, run_time_options) == IARA.Configurations_ConstructionType.COST_BASED
            sum(
                attended_elastic_demand[blk, d] for
                d in elastic_demands if demand_unit_zone_index(inputs, d) == zone;
                init = 0.0,
            )
        else
            0.0
        end +
        sum(
            attended_flexible_demand[blk, d]
            for d in flexible_demands if demand_unit_zone_index(inputs, d) == zone;
            init = 0.0,
        )
    )

    return net_demand
end

function nodal_physical_generation_expression(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    # For clearing problems with BID_BASED or HYBRID representation, 
    # the only physical variables added to the load balance are of units without bidding groups
    filters =
        if run_mode(inputs) == RunMode.TRAIN_MIN_COST ||
           run_mode(inputs) == RunMode.MIN_COST ||
           construction_type(inputs, run_time_options) == Configurations_ConstructionType.COST_BASED
            [is_existing]
        else
            [is_existing, has_no_bidding_group]
        end
    hydro_filters =
        if run_mode(inputs) == RunMode.TRAIN_MIN_COST ||
           run_mode(inputs) == RunMode.MIN_COST ||
           construction_type(inputs, run_time_options) == Configurations_ConstructionType.COST_BASED
            [is_existing]
        else
            [is_existing, has_no_bidding_group, !is_associated_with_some_virtual_reservoir]
        end
    buses = index_of_elements(inputs, Bus)
    blks = subperiods(inputs)
    hydro_units = index_of_elements(inputs, HydroUnit; filters = hydro_filters)
    thermal_units = index_of_elements(inputs, ThermalUnit; filters = filters)
    renewable_units = index_of_elements(inputs, RenewableUnit; filters = filters)
    battery_units = index_of_elements(inputs, BatteryUnit; filters = filters)
    # Centralized Operation Variables
    hydro_generation = if any_elements(inputs, HydroUnit; filters = hydro_filters)
        get_model_object(model, :hydro_generation)
    end
    thermal_generation = if any_elements(inputs, ThermalUnit; filters = filters)
        get_model_object(model, :thermal_generation)
    end
    renewable_generation = if any_elements(inputs, RenewableUnit; filters = filters)
        get_model_object(model, :renewable_generation)
    end
    battery_unit_generation = if any_elements(inputs, BatteryUnit; filters = filters)
        get_model_object(model, :battery_unit_generation)
    end
    # Centralized Operation Generation
    @expression(
        model.jump_model,
        physical_generation[blk in blks, bus in buses],
        sum(
            hydro_generation[blk, h] for
            h in hydro_units if hydro_unit_bus_index(inputs, h) == bus;
            init = 0.0,
        ) +
        sum(
            thermal_generation[blk, t] for
            t in thermal_units if thermal_unit_bus_index(inputs, t) == bus;
            init = 0.0,
        ) +
        sum(
            renewable_generation[blk, r] for
            r in renewable_units if renewable_unit_bus_index(inputs, r) == bus;
            init = 0.0,
        ) +
        sum(
            battery_unit_generation[blk, bat] for
            bat in battery_units if battery_unit_bus_index(inputs, bat) == bus;
            init = 0.0,
        )
    )

    return physical_generation
end

function nodal_bid_generation_expression(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    buses = index_of_elements(inputs, Bus)
    blks = subperiods(inputs)
    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    hydro_units = index_of_elements(inputs, HydroUnit; filters = [is_existing])

    # Market Clearing Variables
    bidding_group_generation_profile = if has_any_profile_bids(inputs)
        get_model_object(model, :bidding_group_generation_profile)
    end
    bidding_group_generation =
        if any_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
            get_model_object(model, :bidding_group_generation)
        end
    hydro_generation = if any_elements(inputs, VirtualReservoir)
        get_model_object(model, :hydro_generation)
    end

    if has_any_simple_bids(inputs)
        valid_segments = get_maximum_valid_segments(inputs)
    end

    if has_any_profile_bids(inputs)
        valid_profiles = get_maximum_valid_profiles(inputs)
    end

    # Market Clearing Generation
    @expression(
        model.jump_model,
        bid_generation[blk in blks, bus in buses],
        if has_any_simple_bids(inputs)
            # The double for loop is necessary, otherwise it breaks
            sum(
                bidding_group_generation[blk, bg, bds, bus] for
                bg in bidding_groups for bds in 1:valid_segments[bg];
                init = 0.0,
            )
        else
            0.0
        end
        +
        if has_any_profile_bids(inputs)
            sum(
                bidding_group_generation_profile[blk, bg, prf, bus] for
                bg in bidding_groups for prf in 1:valid_profiles[bg];
                init = 0.0,
            )
        else
            0.0
        end
        +
        sum(
            hydro_generation[blk, h] for
            h in hydro_units if
            hydro_unit_bus_index(inputs, h) == bus &&
            is_associated_with_some_virtual_reservoir(inputs.collections.hydro_unit, h);
            init = 0.0,
        )
    )
    return bid_generation
end

function nodal_transmission_expression(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    buses = index_of_elements(inputs, Bus)
    blks = subperiods(inputs)
    dc_lines = index_of_elements(inputs, DCLine; filters = [is_existing])
    branches = index_of_elements(inputs, Branch; filters = [is_existing])
    blks = subperiods(inputs)

    # Model Variables
    dc_flow = if any_elements(inputs, DCLine; filters = [is_existing])
        get_model_object(model, :dc_flow)
    end
    branch_flow = if any_elements(inputs, Branch; filters = [is_existing])
        get_model_object(model, :branch_flow)
    end

    @expression(
        model.jump_model,
        transmission[blk in blks, bus in buses],
        subperiod_duration_in_hours(inputs, blk) * (
            sum(
                dc_flow[blk, l] for
                l in dc_lines if dc_line_bus_to(inputs, l) == bus;
                init = 0.0,
            ) +
            sum(
                -dc_flow[blk, l] for
                l in dc_lines if dc_line_bus_from(inputs, l) == bus;
                init = 0.0,
            ) +
            sum(
                branch_flow[blk, b] for
                b in branches if branch_bus_to(inputs, b) == bus;
                init = 0.0,
            ) +
            sum(
                -branch_flow[blk, b] for
                b in branches if branch_bus_from(inputs, b) == bus;
                init = 0.0,
            )
        )
    )
    return transmission
end

function nodal_demand_expression(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    buses = index_of_elements(inputs, Bus)
    blks = subperiods(inputs)
    inelastic_demands = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_inelastic])
    elastic_demands = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_elastic])
    flexible_demands = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_flexible])
    # Model Variables
    deficit = if any_elements(inputs, DemandUnit; filters = [is_existing])
        get_model_object(model, :deficit)
    end
    attended_elastic_demand = if any_elements(inputs, DemandUnit; filters = [is_existing, is_elastic])
        get_model_object(model, :attended_elastic_demand)
    end
    attended_flexible_demand = if any_elements(inputs, DemandUnit; filters = [is_existing, is_flexible])
        get_model_object(model, :attended_flexible_demand)
    end

    # Model parameters
    demand = if any_elements(inputs, DemandUnit; filters = [is_existing])
        get_model_object(model, :demand)
    end

    @expression(
        model.jump_model,
        net_demand[blk in blks, bus in buses],
        sum(
            demand[blk, d]
            for d in inelastic_demands if demand_unit_bus_index(inputs, d) == bus;
            init = 0.0,
        ) / MW_to_GW() -
        sum(
            deficit[blk, d] for
            d in inelastic_demands if demand_unit_bus_index(inputs, d) == bus;
            init = 0.0,
        ) +
        # The attended elastic demand is considered a bid offer in the market clearing case.
        if is_mincost(inputs) ||
           construction_type(inputs, run_time_options) == IARA.Configurations_ConstructionType.COST_BASED
            sum(
                attended_elastic_demand[blk, d] for
                d in elastic_demands if demand_unit_bus_index(inputs, d) == bus;
                init = 0.0,
            )
        else
            0.0
        end
        +
        sum(
            attended_flexible_demand[blk, d]
            for d in flexible_demands if demand_unit_bus_index(inputs, d) == bus;
            init = 0.0,
        )
    )

    return net_demand
end

function zonal_load_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    zones = index_of_elements(inputs, Zone)
    blks = subperiods(inputs)
    physical_generation = zonal_physical_generation_expression(model, inputs, run_time_options)
    generation =
        if run_mode(inputs) == RunMode.TRAIN_MIN_COST ||
           run_mode(inputs) == RunMode.MIN_COST ||
           construction_type(inputs, run_time_options) == Configurations_ConstructionType.COST_BASED
            physical_generation.data
        else
            bid_generation = zonal_bid_generation_expression(model, inputs, run_time_options)
            physical_generation.data + bid_generation.data
        end
    transmission = zonal_transmission_expression(model, inputs, run_time_options)
    net_demand = zonal_demand_expression(model, inputs, run_time_options)

    @constraint(
        model.jump_model,
        load_balance[blk in blks, zone in zones],
        generation[blk, zone] + transmission[blk, zone] == net_demand[blk, zone]
    )

    return nothing
end

function nodal_load_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    blks = subperiods(inputs)
    physical_generation = nodal_physical_generation_expression(model, inputs, run_time_options)
    generation =
        if run_mode(inputs) == RunMode.TRAIN_MIN_COST ||
           run_mode(inputs) == RunMode.MIN_COST ||
           construction_type(inputs, run_time_options) == Configurations_ConstructionType.COST_BASED
            physical_generation.data
        else
            bid_generation = nodal_bid_generation_expression(model, inputs, run_time_options)
            physical_generation.data + bid_generation.data
        end
    transmission = nodal_transmission_expression(model, inputs, run_time_options)
    net_demand = nodal_demand_expression(model, inputs, run_time_options)

    @constraint(
        model.jump_model,
        load_balance[blk in blks, bus in buses],
        generation[blk, bus] + transmission[blk, bus] == net_demand[blk, bus]
    )

    return nothing
end

"""
    load_balance!(
        model::SubproblemModel, 
        inputs::Inputs, 
        run_time_options::RunTimeOptions, 
        ::Type{SubproblemBuild}
    )

Add the load balance constraints to the model.
"""
function load_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    if network_representation(inputs, run_time_options) == Configurations_NetworkRepresentation.ZONAL
        zonal_load_balance!(model, inputs, run_time_options, SubproblemBuild)
    elseif network_representation(inputs, run_time_options) == Configurations_NetworkRepresentation.NODAL
        nodal_load_balance!(model, inputs, run_time_options, SubproblemBuild)
    else
        error("Network representation not implemented.")
    end
end

function load_balance!(
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
    load_balance!(outputs, inputs, run_time_options, ::Type{InitializeOutput})

Initialize the output files for:
- `load_marginal_cost`
"""
function load_balance!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    add_custom_recorder_to_query_from_subproblem_result!(
        outputs,
        :load_marginal_cost,
        constraint_dual_recorder(:load_balance),
    )

    if network_representation(inputs, run_time_options) == Configurations_NetworkRepresentation.ZONAL
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "load_marginal_cost",
            dimensions = ["period", "scenario", "subperiod"],
            unit = "\$/MWh",
            labels = zone_label(inputs),
            run_time_options,
        )
    elseif network_representation(inputs, run_time_options) == Configurations_NetworkRepresentation.NODAL
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "load_marginal_cost",
            dimensions = ["period", "scenario", "subperiod"],
            unit = "\$/MWh",
            labels = bus_label(inputs),
            run_time_options,
        )
    else
        error("Network representation not implemented.")
    end

    return nothing
end

"""
    load_balance!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput}) 


Write the load marginal cost output.
"""
function load_balance!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    load_marginal_cost = simulation_results.data[:load_marginal_cost]

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "load_marginal_cost",
        load_marginal_cost.data;
        period,
        scenario,
        subscenario,
        multiply_by = 1 / money_to_thousand_money(),
    )

    return nothing
end
