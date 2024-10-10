#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

export update_configuration!
# ---------------------------------------------------------------------
# Collection definition
# ---------------------------------------------------------------------
"""
    Configurations

Configurations for the problem.
"""
@kwdef mutable struct Configurations <: AbstractCollection
    path_case::String = ""
    number_of_stages::Int = 0
    number_of_scenarios::Int = 0
    number_of_blocks::Int = 0
    number_of_nodes::Int = 0
    number_of_subscenarios::Int = 0
    iteration_limit::Int = 0
    initial_date_time::DateTime = DateTime(0)
    stage_type::Configurations_StageType.T = Configurations_StageType.MONTHLY
    block_duration_in_hours::Vector{Float64} = []
    run_mode::Configurations_RunMode.T = Configurations_RunMode.CENTRALIZED_OPERATION
    policy_graph_type::Configurations_PolicyGraphType.T = Configurations_PolicyGraphType.LINEAR
    hydro_balance_block_resolution::Configurations_HydroBalanceBlockResolution.T =
        Configurations_HydroBalanceBlockResolution.CHRONOLOGICAL_BLOCKS
    use_binary_variables::Bool = false
    loop_blocks_for_thermal_constraints::Bool = false
    yearly_discount_rate::Float64 = 0.0
    yearly_duration_in_hours::Float64 = 0.0
    aggregate_buses_for_strategic_bidding::Bool = false
    parp_max_lags::Int = 0
    inflow_source::Configurations_InflowSource.T = Configurations_InflowSource.READ_FROM_FILE
    clearing_bid_source::Configurations_ClearingBidSource.T = Configurations_ClearingBidSource.READ_FROM_FILE
    clearing_hydro_representation::Configurations_ClearingHydroRepresentation.T =
        Configurations_ClearingHydroRepresentation.PURE_BIDS
    ex_post_physical_hydro_representation::Configurations_ExPostPhysicalHydroRepresentation.T =
        Configurations_ExPostPhysicalHydroRepresentation.SAME_AS_CLEARING
    clearing_integer_variables::Configurations_ClearingIntegerVariables.T = Configurations_ClearingIntegerVariables.FIX
    clearing_network_representation::Configurations_ClearingNetworkRepresentation.T =
        Configurations_ClearingNetworkRepresentation.NODAL_NODAL
    settlement_type::Configurations_SettlementType.T = Configurations_SettlementType.EX_ANTE
    make_whole_payments::Configurations_MakeWholePayments.T =
        Configurations_MakeWholePayments.CONSTRAINED_ON_AND_OFF_INSTANT
    price_cap::Configurations_PriceCap.T = Configurations_PriceCap.REPRESENT
    number_of_virtual_reservoir_bidding_segments::Int = 0
    hour_block_map_file::String = ""
    fcf_cuts_file::String = ""

    # Penalty costs
    demand_deficit_cost::Float64 = 0.0
    hydro_minimum_outflow_violation_cost::Float64 = 0.0
    hydro_spillage_cost::Float64 = 0.0
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(configurations::Configurations, inputs)

Initialize the Configurations collection from the database.
"""
function initialize!(configurations::Configurations, inputs::AbstractInputs)
    configurations.path_case = path_case(inputs.db)
    configurations.number_of_stages =
        PSRI.get_parms(inputs.db, "Configuration", "number_of_stages")[1]
    configurations.number_of_scenarios =
        PSRI.get_parms(inputs.db, "Configuration", "number_of_scenarios")[1]
    configurations.number_of_blocks =
        PSRI.get_parms(inputs.db, "Configuration", "number_of_blocks")[1]
    configurations.number_of_nodes =
        PSRI.get_parms(inputs.db, "Configuration", "number_of_nodes")[1]
    configurations.number_of_subscenarios =
        PSRI.get_parms(inputs.db, "Configuration", "number_of_subscenarios")[1]
    configurations.iteration_limit =
        PSRI.get_parms(inputs.db, "Configuration", "iteration_limit")[1]
    configurations.initial_date_time = DateTime(
        PSRI.get_parms(inputs.db, "Configuration", "initial_date_time")[1],
        "yyyy-mm-ddTHH:MM:SS",
    )
    configurations.stage_type =
        PSRI.get_parms(inputs.db, "Configuration", "stage_type")[1] |> Configurations_StageType.T
    configurations.run_mode =
        PSRI.get_parms(inputs.db, "Configuration", "run_mode")[1] |> Configurations_RunMode.T
    configurations.policy_graph_type =
        PSRI.get_parms(inputs.db, "Configuration", "policy_graph_type")[1] |> Configurations_PolicyGraphType.T
    configurations.hydro_balance_block_resolution =
        PSRI.get_parms(inputs.db, "Configuration", "hydro_balance_block_resolution")[1] |>
        Configurations_HydroBalanceBlockResolution.T
    configurations.use_binary_variables =
        PSRI.get_parms(inputs.db, "Configuration", "use_binary_variables")[1] |> Bool
    loop_blocks_for_thermal_constraints =
        PSRI.get_parms(inputs.db, "Configuration", "loop_blocks_for_thermal_constraints")[1]
    configurations.loop_blocks_for_thermal_constraints =
        if is_null(loop_blocks_for_thermal_constraints)
            false
        else
            loop_blocks_for_thermal_constraints |> Bool
        end
    aggregate_buses_for_strategic_bidding =
        PSRI.get_parms(inputs.db, "Configuration", "aggregate_buses_for_strategic_bidding")[1]
    configurations.aggregate_buses_for_strategic_bidding =
        if is_null(aggregate_buses_for_strategic_bidding)
            false
        else
            aggregate_buses_for_strategic_bidding |> Bool
        end
    configurations.inflow_source =
        PSRI.get_parms(inputs.db, "Configuration", "inflow_source")[1] |> Configurations_InflowSource.T
    configurations.clearing_bid_source =
        PSRI.get_parms(inputs.db, "Configuration", "clearing_bid_source")[1] |> Configurations_ClearingBidSource.T
    configurations.clearing_hydro_representation =
        PSRI.get_parms(inputs.db, "Configuration", "clearing_hydro_representation")[1] |>
        Configurations_ClearingHydroRepresentation.T
    configurations.ex_post_physical_hydro_representation =
        PSRI.get_parms(inputs.db, "Configuration", "ex_post_physical_hydro_representation")[1] |>
        Configurations_ExPostPhysicalHydroRepresentation.T
    configurations.clearing_integer_variables =
        PSRI.get_parms(inputs.db, "Configuration", "clearing_integer_variables")[1] |>
        Configurations_ClearingIntegerVariables.T
    configurations.clearing_network_representation =
        PSRI.get_parms(inputs.db, "Configuration", "clearing_network_representation")[1] |>
        Configurations_ClearingNetworkRepresentation.T
    configurations.settlement_type =
        PSRI.get_parms(inputs.db, "Configuration", "settlement_type")[1] |> Configurations_SettlementType.T
    configurations.make_whole_payments =
        PSRI.get_parms(inputs.db, "Configuration", "make_whole_payments")[1] |> Configurations_MakeWholePayments.T
    configurations.price_cap =
        PSRI.get_parms(inputs.db, "Configuration", "price_cap")[1] |> Configurations_PriceCap.T
    configurations.yearly_discount_rate =
        PSRI.get_parms(inputs.db, "Configuration", "yearly_discount_rate")[1]
    configurations.yearly_duration_in_hours =
        PSRI.get_parms(inputs.db, "Configuration", "yearly_duration_in_hours")[1]
    configurations.parp_max_lags =
        PSRI.get_parms(inputs.db, "Configuration", "parp_max_lags")[1]
    configurations.demand_deficit_cost =
        PSRI.get_parms(inputs.db, "Configuration", "demand_deficit_cost")[1]
    configurations.hydro_minimum_outflow_violation_cost =
        PSRI.get_parms(inputs.db, "Configuration", "hydro_minimum_outflow_violation_cost")[1]
    configurations.hydro_spillage_cost =
        PSRI.get_parms(inputs.db, "Configuration", "hydro_spillage_cost")[1]
    configurations.number_of_virtual_reservoir_bidding_segments =
        PSRI.get_parms(inputs.db, "Configuration", "number_of_virtual_reservoir_bidding_segments")[1]

    # Load vectors
    configurations.block_duration_in_hours = PSRI.get_vectors(inputs.db, "Configuration", "block_duration_in_hours")[1]

    # Load time series files
    configurations.hour_block_map_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "Configuration", "hour_block_map")
    configurations.fcf_cuts_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "Configuration", "fcf_cuts")

    update_time_series_from_db!(configurations, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_configuration!(db::DatabaseSQLite; kwargs...)

Update the Configuration table in the database.
"""
function update_configuration!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    label = PSRI.get_parms(db, "Configuration", "label")[1]
    for (attribute, value) in sql_typed_kwargs
        if isa(value, Vector)
            PSRI.set_vector!(
                db,
                "Configuration",
                string(attribute),
                label,
                value,
            )
        else
            PSRI.set_parm!(
                db,
                "Configuration",
                string(attribute),
                label,
                value,
            )
        end
    end
    return db
end

"""
    update_time_series_from_db!(configurations::Configurations, db::DatabaseSQLite, stage_date_time::DateTime)

Update the Configuration collection time series from the database.
"""
function update_time_series_from_db!(
    configurations::Configurations,
    db::DatabaseSQLite,
    stage_date_time::DateTime,
)
    return nothing
end

"""
    validate(configurations::Configurations)

Validate the Configurations' parameters. Return the number of errors found.
"""
function validate(configurations::Configurations)
    num_errors = 0
    if configurations.number_of_stages <= 0
        @error("Number of stages must be positive.")
        num_errors += 1
    end
    if configurations.number_of_scenarios <= 0
        @error("Number of scenarios must be positive.")
        num_errors += 1
    end
    if configurations.number_of_blocks <= 0
        @error("Number of blocks must be positive.")
        num_errors += 1
    end
    if configurations.run_mode == Configurations_RunMode.MARKET_CLEARING
        if configurations.number_of_subscenarios <= 0
            @error("Number of subscenarios must be positive.")
            num_errors += 1
        end
    else
        if configurations.number_of_subscenarios != 1
            @error("Number of subscenarios must be one for run modes other than MARKET_CLEARING.")
            num_errors += 1
        end
    end
    if configurations.policy_graph_type == Configurations_PolicyGraphType.CYCLIC
        if is_null(configurations.number_of_nodes)
            @error("Configuration parameter number_of_nodes must be defined when using a cyclic policy graph for SDDP.")
            num_errors += 1
        elseif configurations.number_of_nodes <= 0
            @error(
                "Configuration parameter number_of_nodes must be positive. Current value is $(configurations.number_of_nodes)."
            )
            num_errors += 1
        end
    end
    if length(configurations.block_duration_in_hours) != configurations.number_of_blocks
        @error("Block duration in hours must have the same length as the number of blocks.")
        num_errors += 1
    end
    if configurations.demand_deficit_cost < 0
        @error("Demand deficit cost must be non-negative.")
        num_errors += 1
    end
    if configurations.hydro_minimum_outflow_violation_cost < 0
        @error("Hydro minimum outflow violation cost must be non-negative.")
        num_errors += 1
    end
    if configurations.hydro_spillage_cost < 0
        @error("Hydro spillage cost must be non-negative.")
        num_errors += 1
    end
    if configurations.policy_graph_type == Configurations_PolicyGraphType.CYCLIC &&
       configurations.yearly_discount_rate == 0
        @error(
            "If the policy graph is not linear, the yearly discount rate must be positive. Current discount rate: $(configurations.yearly_discount_rate)"
        )
        num_errors += 1
    end
    if configurations.inflow_source == Configurations_InflowSource.SIMULATE_WITH_PARP &&
       is_null(configurations.parp_max_lags)
        @error("Inflow is set to use the PAR(p) model, but the maximum number of lags is undefined.")
        num_errors += 1
    end
    if !is_null(configurations.number_of_virtual_reservoir_bidding_segments) &&
       configurations.number_of_virtual_reservoir_bidding_segments <= 0
        @error("Number of virtual reservoir bidding segments must be positive.")
        num_errors += 1
    end
    if configurations.clearing_hydro_representation == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS &&
       configurations.clearing_bid_source == Configurations_ClearingBidSource.READ_FROM_FILE
        @error("Virtual reservoirs cannot be used with clearing bid source READ_FROM_FILE.")
        num_errors += 1
    end
    return num_errors
end

"""
    validate_relations(inputs, configurations::Configurations)

Validate the Configurations' references. Return the number of errors found.
"""
function validate_relations(inputs::AbstractInputs, configurations::Configurations)
    num_errors = 0
    if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS &&
       is_null(configurations.number_of_virtual_reservoir_bidding_segments)
        @error("Number of virtual reservoir bidding segments must be defined when using virtual reservoirs.")
        num_errors += 1
    end
    if configurations.clearing_hydro_representation == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS &&
       !any_elements(inputs, VirtualReservoir)
        @error("Virtual reservoirs must be defined when using the virtual reservoirs clearing representation.")
        num_errors += 1
    end
    return num_errors
end

function iara_log(configurations::Configurations)
    println("   Number of stages: $(configurations.number_of_stages)")
    println("   Number of scenarios: $(configurations.number_of_scenarios)")
    println("   Number of blocks: $(configurations.number_of_blocks)")
    println("   Run mode: $(configurations.run_mode)")
    println("   Stage frequency: $(configurations.stage_type)")

    return nothing
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

"""
    path_case(inputs)

Return the path to the case.
"""
path_case(inputs::AbstractInputs) = inputs.collections.configurations.path_case

"""
    path_parp(inputs)

Return the path to the PAR(p) model files.
"""
path_parp(inputs::AbstractInputs) = joinpath(path_case(inputs), "parp")
path_parp(db::DatabaseSQLite) = joinpath(path_case(db), "parp")

"""
    number_of_stages(inputs)

Return the number of stages in the problem.
"""
number_of_stages(inputs::AbstractInputs) = inputs.collections.configurations.number_of_stages
"""
    stages(inputs)

Return all problem stages.
"""
stages(inputs::AbstractInputs) = collect(1:number_of_stages(inputs))

"""
    number_of_scenarios(inputs)

Return the number of scenarios in the problem.
"""
number_of_scenarios(inputs::AbstractInputs) = inputs.collections.configurations.number_of_scenarios

"""
    scenarios(inputs)

Return all problem scenarios.
"""
scenarios(inputs::AbstractInputs) = collect(1:number_of_scenarios(inputs))

"""
    number_of_blocks(inputs)

Return the number of blocks in the problem.
"""
number_of_blocks(inputs::AbstractInputs) = inputs.collections.configurations.number_of_blocks

"""
    blocks(inputs)

Return all problem blocks.
"""
blocks(inputs::AbstractInputs) = collect(1:number_of_blocks(inputs))

"""
    number_of_nodes(inputs)

Return the number of nodes in the SDDP policy graph.
"""
number_of_nodes(inputs::AbstractInputs) = inputs.collections.configurations.number_of_nodes

"""
    nodes(inputs)

Return all nodes in the SDDP policy graph, except for the root node.
"""
nodes(inputs::AbstractInputs) = collect(1:number_of_nodes(inputs))

"""
    number_of_subscenarios(inputs, run_time_options)

Return the number of subscenarios to simulate.
"""
function number_of_subscenarios(inputs::AbstractInputs, run_time_options)
    if is_ex_post_problem(run_time_options)
        return inputs.collections.configurations.number_of_subscenarios
    else
        return 1
    end
end

"""
    subscenarios(inputs, run_time_options)

Return all subscenarios to simulate.
"""
subscenarios(inputs::AbstractInputs, run_time_options) = collect(1:number_of_subscenarios(inputs, run_time_options))

"""
    iteration_limit(inputs)

Return the iteration limit.
"""
function iteration_limit(inputs::AbstractInputs)
    if is_null(inputs.collections.configurations.iteration_limit)
        return nothing
    else
        return inputs.collections.configurations.iteration_limit
    end
end

"""
    initial_date_time(inputs)

Return the initial date of the problem.
"""
initial_date_time(inputs::AbstractInputs) = inputs.collections.configurations.initial_date_time

"""
    stage_type(inputs)

Return the stage type.
"""
stage_type(inputs::AbstractInputs) = inputs.collections.configurations.stage_type

"""
    stages_per_year(inputs)

Return the number of stages per year.
"""
function stages_per_year(inputs::AbstractInputs)
    if stage_type(inputs) == Configurations_StageType.MONTHLY
        return 12
    else
        error("Stage type $(stage_type(inputs)) not implemented.")
    end
end

"""
    block_duration_in_hours(inputs)

Return the block duration in hours for all blocks.
"""
block_duration_in_hours(inputs::AbstractInputs) = inputs.collections.configurations.block_duration_in_hours

"""
    block_duration_in_hours(inputs, block::Int)

Return the block duration in hours for a given block.
"""
block_duration_in_hours(inputs::AbstractInputs, block::Int) =
    inputs.collections.configurations.block_duration_in_hours[block]

"""
    run_mode(inputs)

Return the run mode.
"""
run_mode(inputs::AbstractInputs) = inputs.collections.configurations.run_mode

"""
    linear_policy_graph(inputs)

Return whether the policy graph is linear.
"""
linear_policy_graph(inputs::AbstractInputs) =
    inputs.collections.configurations.policy_graph_type == Configurations_PolicyGraphType.LINEAR

"""
    use_binary_variables(inputs)

Return whether binary variables should be used.
"""
use_binary_variables(inputs::AbstractInputs) = inputs.collections.configurations.use_binary_variables

"""
    loop_blocks_for_thermal_constraints(inputs)

Return whether blocks should be looped for thermal constraints.
"""
loop_blocks_for_thermal_constraints(inputs::AbstractInputs) =
    inputs.collections.configurations.loop_blocks_for_thermal_constraints

"""
    yearly_discount_rate(inputs)

Return the yearly discount rate.
"""
yearly_discount_rate(inputs::AbstractInputs) = inputs.collections.configurations.yearly_discount_rate

"""
    stage_discount_rate(inputs)

Return the discount rate per stage.
"""
function stage_discount_rate(inputs::AbstractInputs)
    return 1 - ((1 - yearly_discount_rate(inputs))^(1 / stages_per_year(inputs)))
end

"""
    yearly_duration_in_hours(inputs)

Return the yearly duration in hours.
"""
yearly_duration_in_hours(inputs::AbstractInputs) =
    inputs.collections.configurations.yearly_duration_in_hours

"""
    aggregate_buses_for_strategic_bidding(inputs)

Return whether buses should be aggregated for strategic bidding.
"""
aggregate_buses_for_strategic_bidding(inputs::AbstractInputs) =
    inputs.collections.configurations.aggregate_buses_for_strategic_bidding

"""
    parp_max_lags(inputs)

Return the maximum number of lags in the PAR(p) model.
"""
parp_max_lags(inputs::AbstractInputs) = inputs.collections.configurations.parp_max_lags

"""
    read_inflow_from_file(inputs)

Return whether inflow should be read from a file.
"""
read_inflow_from_file(inputs::AbstractInputs) =
    inputs.collections.configurations.inflow_source == Configurations_InflowSource.READ_FROM_FILE

"""
    read_bids_from_file(inputs)

Return whether bids should be read from a file.
"""
read_bids_from_file(inputs::AbstractInputs) =
    inputs.collections.configurations.clearing_bid_source == Configurations_ClearingBidSource.READ_FROM_FILE

"""
    generate_heuristic_bids_for_clearing(inputs)

Return whether heuristic bids should be generated for clearing.
"""
generate_heuristic_bids_for_clearing(inputs::AbstractInputs) =
    inputs.collections.configurations.clearing_bid_source == Configurations_ClearingBidSource.HEURISTIC_BIDS

"""
    clearing_bid_source(inputs)

Return the clearing bid source.
"""
clearing_bid_source(inputs::AbstractInputs) = inputs.collections.configurations.clearing_bid_source

"""
    clearing_hydro_representation(inputs)

Return the clearing hydro representation.
"""
clearing_hydro_representation(inputs::AbstractInputs) =
    inputs.collections.configurations.clearing_hydro_representation

"""
    ex_post_physical_hydro_representation(inputs)

Return the ex-post physical hydro representation.
"""
ex_post_physical_hydro_representation(inputs::AbstractInputs) =
    inputs.collections.configurations.ex_post_physical_hydro_representation

"""
    clearing_integer_variables(inputs)

Return the clearing integer variables.
"""
clearing_integer_variables(inputs::AbstractInputs) =
    inputs.collections.configurations.clearing_integer_variables

"""
    clearing_network_representation(inputs)

Return the clearing network representation.
"""
clearing_network_representation(inputs::AbstractInputs) =
    inputs.collections.configurations.clearing_network_representation

"""
    settlement_type(inputs)

Return the settlement type.
"""
settlement_type(inputs::AbstractInputs) = inputs.collections.configurations.settlement_type

"""
    make_whole_payments(inputs)

Return the make whole payments type.
"""
make_whole_payments(inputs::AbstractInputs) = inputs.collections.configurations.make_whole_payments

"""
    price_cap(inputs)

Return the price cap type.
"""
price_cap(inputs::AbstractInputs) = inputs.collections.configurations.price_cap

"""
    demand_deficit_cost(inputs)

Return the deficit cost of demands.
"""
demand_deficit_cost(inputs::AbstractInputs) = inputs.collections.configurations.demand_deficit_cost

"""
    hydro_minimum_outflow_violation_cost(inputs)

Return the cost of violating the minimum outflow in hydro plants.
"""
hydro_minimum_outflow_violation_cost(inputs::AbstractInputs) =
    inputs.collections.configurations.hydro_minimum_outflow_violation_cost

"""
    hydro_spillage_cost(inputs)

Return the cost of spilling water in hydro plants.
"""
hydro_spillage_cost(inputs::AbstractInputs) = inputs.collections.configurations.hydro_spillage_cost

"""
    hour_block_map_file(inputs)

Return the file with the hour to block map.
"""
hour_block_map_file(inputs::AbstractInputs) = inputs.collections.configurations.hour_block_map_file

"""
    has_hour_block_map(inputs)

Return whether the hour to block map file is defined.
"""
has_hour_block_map(inputs::AbstractInputs) = hour_block_map_file(inputs) != ""

"""
    fcf_cuts_file(inputs)

Return the file with the FCF cuts.
"""
fcf_cuts_file(inputs::AbstractInputs) = inputs.collections.configurations.fcf_cuts_file

"""
    has_fcf_cuts(inputs)

Return whether the FCF cuts file is defined.
"""
has_fcf_cuts_to_read(inputs::AbstractInputs) = fcf_cuts_file(inputs) != ""

"""
    hydro_balance_block_resolution(inputs)
"""
hydro_balance_block_resolution(inputs::AbstractInputs) =
    inputs.collections.configurations.hydro_balance_block_resolution

"""
    number_of_virtual_reservoir_bidding_segments(inputs)

Return the number of bidding segments for virtual reservoirs.
"""
number_of_virtual_reservoir_bidding_segments(inputs) =
    inputs.collections.configurations.number_of_virtual_reservoir_bidding_segments
