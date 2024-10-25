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

function load_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    flexible_demands = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_flexible])
    elastic_demands = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_elastic])
    inelastic_demands = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_inelastic])
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

    # Generation expression
    if run_mode(inputs) == Configurations_RunMode.CENTRALIZED_OPERATION ||
       run_mode(inputs) == Configurations_RunMode.CENTRALIZED_OPERATION_SIMULATION ||
       clearing_model_type(inputs, run_time_options) == Configurations_ClearingModelType.COST_BASED
        hydro_units = index_of_elements(inputs, HydroUnit; filters = [is_existing])
        thermal_units = index_of_elements(inputs, ThermalUnit; filters = [is_existing])
        renewable_units = index_of_elements(inputs, RenewableUnit; filters = [is_existing])
        battery_units = index_of_elements(inputs, BatteryUnit; filters = [is_existing])
        # Centralized Operation Variables
        hydro_generation = if any_elements(inputs, HydroUnit; filters = [is_existing])
            get_model_object(model, :hydro_generation)
        end
        thermal_generation = if any_elements(inputs, ThermalUnit; filters = [is_existing])
            get_model_object(model, :thermal_generation)
        end
        renewable_generation = if any_elements(inputs, RenewableUnit; filters = [is_existing])
            get_model_object(model, :renewable_generation)
        end
        battery_unit_generation = if any_elements(inputs, BatteryUnit; filters = [is_existing])
            get_model_object(model, :battery_unit_generation)
        end
        # Centralized Operation Generation
        @expression(
            model.jump_model,
            generation[blk in blks, bus in buses],
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
    elseif run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING
        independent_bidding_groups =
            index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_independent_bids])
        hydro_units = index_of_elements(inputs, HydroUnit; filters = [is_existing])
        profile_bidding_groups =
            index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_profile_bids])

        # Market Clearing Variables
        bidding_group_generation_multihour = if any_elements(inputs, BiddingGroup; filters = [has_profile_bids])
            get_model_object(model, :bidding_group_generation_multihour)
        end
        bidding_group_generation = if any_elements(inputs, BiddingGroup; filters = [has_independent_bids])
            get_model_object(model, :bidding_group_generation)
        end
        hydro_generation = if any_elements(inputs, VirtualReservoir)
            get_model_object(model, :hydro_generation)
        end

        # Market Clearing Generation
        @expression(
            model.jump_model,
            generation[blk in blks, bus in buses],
            sum(
                bidding_group_generation[blk, bg, bds, bus] for
                bg in independent_bidding_groups, bds in 1:maximum_bid_segments(inputs, bg);
                init = 0.0,
            ) +
            sum(
                bidding_group_generation_multihour[blk, bg, prf, bus] for
                bg in profile_bidding_groups, prf in 1:maximum_multihour_profiles(inputs, bg);
                init = 0.0,
            ) +
            sum(
                hydro_generation[blk, h] for
                h in hydro_units if
                hydro_unit_bus_index(inputs, h) == bus &&
                is_associated_with_some_virtual_reservoir(inputs.collections.hydro_unit, h);
                init = 0.0,
            )
        )

    else
        error("Load balance not implemented for run mode $(run_mode(inputs)).")
    end

    # Constraints
    # Flow is in [MW], generation and deficit are in [MWh], demand is in [GWh]
    @constraint(
        model.jump_model,
        load_balance[blk in blks, bus in buses],
        subperiod_duration_in_hours(inputs, blk) *
        (
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
        ) +
        (
            generation[blk, bus] +
            sum(
                deficit[blk, d] for
                d in inelastic_demands if demand_unit_bus_index(inputs, d) == bus;
                init = 0.0,
            ) -
            sum(
                attended_elastic_demand[blk, d] for
                d in elastic_demands if demand_unit_bus_index(inputs, d) == bus;
                init = 0.0,
            ) -
            sum(
                attended_flexible_demand[blk, d]
                for d in flexible_demands if demand_unit_bus_index(inputs, d) == bus;
                init = 0.0,
            )
        )
        ==
        sum(
            demand[blk, d]
            for d in inelastic_demands if demand_unit_bus_index(inputs, d) == bus;
            init = 0.0,
        ) / MW_to_GW()
    )

    return nothing
end

function load_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

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

    return nothing
end

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
