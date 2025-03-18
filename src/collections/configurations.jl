#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

# ---------------------------------------------------------------------
# Collection definition
# ---------------------------------------------------------------------
"""
    Configurations

Configurations for the problem.
"""
@kwdef mutable struct Configurations <: AbstractCollection
    path_case::String = ""
    number_of_periods::Int = 0
    number_of_scenarios::Int = 0
    number_of_subperiods::Int = 0
    number_of_nodes::Int = 0
    number_of_subscenarios::Int = 0
    iteration_limit::Int = 0
    initial_date_time::DateTime = DateTime(0)
    time_series_step::Configurations_TimeSeriesStep.T = Configurations_TimeSeriesStep.ONE_MONTH_PER_PERIOD
    subperiod_duration_in_hours::Vector{Float64} = []
    policy_graph_type::Configurations_PolicyGraphType.T = Configurations_PolicyGraphType.LINEAR
    expected_number_of_repeats_per_node::Vector{Int} = []
    hydro_balance_subperiod_resolution::Configurations_HydroBalanceSubperiodResolution.T =
        Configurations_HydroBalanceSubperiodResolution.CHRONOLOGICAL_SUBPERIODS
    loop_subperiods_for_thermal_constraints::Configurations_ConsiderSubperiodsLoopForThermalConstraints.T =
        Configurations_ConsiderSubperiodsLoopForThermalConstraints.DO_NOT_CONSIDER
    cycle_discount_rate::Float64 = 0.0
    cycle_duration_in_hours::Float64 = 0.0
    aggregate_buses_for_strategic_bidding::Configurations_BusesAggregationForStrategicBidding.T =
        Configurations_BusesAggregationForStrategicBidding.DO_NOT_AGGREGATE
    parp_max_lags::Int = 0
    renewable_scenarios_files::Configurations_UncertaintyScenariosFiles.T =
        Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST
    inflow_scenarios_files::Configurations_UncertaintyScenariosFiles.T =
        Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST
    demand_scenarios_files::Configurations_UncertaintyScenariosFiles.T =
        Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST
    bid_data_source::Configurations_BidDataSource.T = Configurations_BidDataSource.READ_FROM_FILE
    clearing_hydro_representation::Configurations_ClearingHydroRepresentation.T =
        Configurations_ClearingHydroRepresentation.PURE_BIDS
    construction_type_ex_ante_physical::Configurations_ConstructionType.T =
        Configurations_ConstructionType.SKIP
    construction_type_ex_ante_commercial::Configurations_ConstructionType.T =
        Configurations_ConstructionType.SKIP
    construction_type_ex_post_physical::Configurations_ConstructionType.T =
        Configurations_ConstructionType.SKIP
    construction_type_ex_post_commercial::Configurations_ConstructionType.T =
        Configurations_ConstructionType.SKIP
    use_fcf_in_clearing::Bool = false
    integer_variable_representation_mincost::Configurations_IntegerVariableRepresentation.T =
        Configurations_IntegerVariableRepresentation.CALCULATE_NORMALLY
    integer_variable_representation_ex_ante_physical::Configurations_IntegerVariableRepresentation.T =
        Configurations_IntegerVariableRepresentation.CALCULATE_NORMALLY
    integer_variable_representation_ex_ante_commercial::Configurations_IntegerVariableRepresentation.T =
        Configurations_IntegerVariableRepresentation.CALCULATE_NORMALLY
    integer_variable_representation_ex_post_physical::Configurations_IntegerVariableRepresentation.T =
        Configurations_IntegerVariableRepresentation.CALCULATE_NORMALLY
    integer_variable_representation_ex_post_commercial::Configurations_IntegerVariableRepresentation.T =
        Configurations_IntegerVariableRepresentation.CALCULATE_NORMALLY
    network_representation_mincost::Configurations_NetworkRepresentation.T =
        Configurations_NetworkRepresentation.NODAL
    network_representation_ex_ante_physical::Configurations_NetworkRepresentation.T =
        Configurations_NetworkRepresentation.NODAL
    network_representation_ex_ante_commercial::Configurations_NetworkRepresentation.T =
        Configurations_NetworkRepresentation.NODAL
    network_representation_ex_post_physical::Configurations_NetworkRepresentation.T =
        Configurations_NetworkRepresentation.NODAL
    network_representation_ex_post_commercial::Configurations_NetworkRepresentation.T =
        Configurations_NetworkRepresentation.NODAL
    settlement_type::Configurations_SettlementType.T = Configurations_SettlementType.EX_ANTE
    make_whole_payments::Configurations_MakeWholePayments.T =
        Configurations_MakeWholePayments.CONSTRAINED_ON_AND_OFF_PER_SUBPERIOD
    price_limits::Configurations_PriceLimits.T = Configurations_PriceLimits.REPRESENT
    vr_curveguide_data_source::Configurations_VRCurveguideDataSource.T =
        Configurations_VRCurveguideDataSource.UNIFORM_ACROSS_RESERVOIRS
    vr_curveguide_data_format::Configurations_VRCurveguideDataFormat.T =
        Configurations_VRCurveguideDataFormat.CSV_FILE
    hour_subperiod_map_file::String = ""
    fcf_cuts_file::String = ""
    period_season_map_file::String = ""
    spot_price_floor::Float64 = 0.0
    spot_price_cap::Float64 = 0.0
    virtual_reservoir_correspondence_type::Configurations_VirtualReservoirCorrespondenceType.T =
        Configurations_VirtualReservoirCorrespondenceType.STANDARD_CORRESPONDENCE_CONSTRAINT

    # Penalty costs
    demand_deficit_cost::Float64 = 0.0
    hydro_minimum_outflow_violation_cost::Float64 = 0.0
    hydro_spillage_cost::Float64 = 0.0
    market_clearing_tiebreaker_weight::Float64 = 0.0

    # Caches
    period_season_map = Array{Float64, 3}(undef, 3, 0, 0)
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(configurations::Configurations, inputs::AbstractInputs)

Initialize the Configurations collection from the database.
"""
function initialize!(configurations::Configurations, inputs::AbstractInputs)
    configurations.path_case = path_case(inputs.db)
    configurations.number_of_periods =
        PSRI.get_parms(inputs.db, "Configuration", "number_of_periods")[1]
    configurations.number_of_scenarios =
        PSRI.get_parms(inputs.db, "Configuration", "number_of_scenarios")[1]
    configurations.number_of_subperiods =
        PSRI.get_parms(inputs.db, "Configuration", "number_of_subperiods")[1]
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
    configurations.time_series_step =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "time_series_step")[1],
            Configurations_TimeSeriesStep.T,
        )
    configurations.policy_graph_type =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "policy_graph_type")[1],
            Configurations_PolicyGraphType.T,
        )
    configurations.hydro_balance_subperiod_resolution =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "hydro_balance_subperiod_resolution")[1],
            Configurations_HydroBalanceSubperiodResolution.T,
        )
    loop_subperiods_for_thermal_constraints =
        PSRI.get_parms(inputs.db, "Configuration", "loop_subperiods_for_thermal_constraints")[1]
    configurations.loop_subperiods_for_thermal_constraints =
        if is_null(loop_subperiods_for_thermal_constraints)
            Configurations_ConsiderSubperiodsLoopForThermalConstraints.DO_NOT_CONSIDER
        else
            convert_to_enum(
                loop_subperiods_for_thermal_constraints,
                Configurations_ConsiderSubperiodsLoopForThermalConstraints.T,
            )
        end
    aggregate_buses_for_strategic_bidding =
        PSRI.get_parms(inputs.db, "Configuration", "aggregate_buses_for_strategic_bidding")[1]
    configurations.aggregate_buses_for_strategic_bidding =
        if is_null(aggregate_buses_for_strategic_bidding)
            Configurations_BusesAggregationForStrategicBidding.DO_NOT_AGGREGATE
        else
            convert_to_enum(aggregate_buses_for_strategic_bidding, Configurations_BusesAggregationForStrategicBidding.T)
        end
    configurations.renewable_scenarios_files =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "renewable_scenarios_files")[1],
            Configurations_UncertaintyScenariosFiles.T,
        )
    configurations.inflow_scenarios_files =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "inflow_scenarios_files")[1],
            Configurations_UncertaintyScenariosFiles.T,
        )
    configurations.demand_scenarios_files =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "demand_scenarios_files")[1],
            Configurations_UncertaintyScenariosFiles.T,
        )
    configurations.bid_data_source =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "bid_data_source")[1],
            Configurations_BidDataSource.T,
        )
    configurations.clearing_hydro_representation =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "clearing_hydro_representation")[1],
            Configurations_ClearingHydroRepresentation.T,
        )
    configurations.settlement_type =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "settlement_type")[1],
            Configurations_SettlementType.T,
        )
    configurations.make_whole_payments =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "make_whole_payments")[1],
            Configurations_MakeWholePayments.T,
        )
    configurations.price_limits =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "price_limits")[1],
            Configurations_PriceLimits.T,
        )
    configurations.cycle_discount_rate =
        PSRI.get_parms(inputs.db, "Configuration", "cycle_discount_rate")[1]
    configurations.cycle_duration_in_hours =
        PSRI.get_parms(inputs.db, "Configuration", "cycle_duration_in_hours")[1]
    configurations.parp_max_lags =
        PSRI.get_parms(inputs.db, "Configuration", "parp_max_lags")[1]
    configurations.demand_deficit_cost =
        PSRI.get_parms(inputs.db, "Configuration", "demand_deficit_cost")[1]
    configurations.hydro_minimum_outflow_violation_cost =
        PSRI.get_parms(inputs.db, "Configuration", "hydro_minimum_outflow_violation_cost")[1]
    configurations.hydro_spillage_cost =
        PSRI.get_parms(inputs.db, "Configuration", "hydro_spillage_cost")[1]
    configurations.market_clearing_tiebreaker_weight =
        PSRI.get_parms(inputs.db, "Configuration", "market_clearing_tiebreaker_weight")[1]
    configurations.vr_curveguide_data_source =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "vr_curveguide_data_source")[1],
            Configurations_VRCurveguideDataSource.T,
        )
    configurations.vr_curveguide_data_format =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "vr_curveguide_data_format")[1],
            Configurations_VRCurveguideDataFormat.T,
        )
    configurations.construction_type_ex_ante_physical =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "construction_type_ex_ante_physical")[1],
            Configurations_ConstructionType.T,
        )
    configurations.construction_type_ex_ante_commercial =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "construction_type_ex_ante_commercial")[1],
            Configurations_ConstructionType.T,
        )
    configurations.construction_type_ex_post_physical =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "construction_type_ex_post_physical")[1],
            Configurations_ConstructionType.T,
        )
    configurations.construction_type_ex_post_commercial =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "construction_type_ex_post_commercial")[1],
            Configurations_ConstructionType.T,
        )
    configurations.use_fcf_in_clearing =
        PSRI.get_parms(inputs.db, "Configuration", "use_fcf_in_clearing")[1] |> Bool
    configurations.integer_variable_representation_ex_ante_physical =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "integer_variable_representation_ex_ante_physical")[1],
            Configurations_IntegerVariableRepresentation.T,
        )
    configurations.integer_variable_representation_ex_ante_commercial =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "integer_variable_representation_ex_ante_commercial")[1],
            Configurations_IntegerVariableRepresentation.T,
        )
    configurations.integer_variable_representation_ex_post_physical =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "integer_variable_representation_ex_post_physical")[1],
            Configurations_IntegerVariableRepresentation.T,
        )
    configurations.integer_variable_representation_ex_post_commercial =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "integer_variable_representation_ex_post_commercial")[1],
            Configurations_IntegerVariableRepresentation.T,
        )
    configurations.network_representation_mincost =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "network_representation_mincost")[1],
            Configurations_NetworkRepresentation.T,
        )
    configurations.network_representation_ex_ante_physical =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "network_representation_ex_ante_physical")[1],
            Configurations_NetworkRepresentation.T,
        )
    configurations.network_representation_ex_ante_commercial =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "network_representation_ex_ante_commercial")[1],
            Configurations_NetworkRepresentation.T,
        )
    configurations.network_representation_ex_post_physical =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "network_representation_ex_post_physical")[1],
            Configurations_NetworkRepresentation.T,
        )
    configurations.spot_price_floor = PSRI.get_parms(inputs.db, "Configuration", "spot_price_floor")[1]
    configurations.spot_price_cap = PSRI.get_parms(inputs.db, "Configuration", "spot_price_cap")[1]
    configurations.virtual_reservoir_correspondence_type =
        convert_to_enum(
            PSRI.get_parms(inputs.db, "Configuration", "virtual_reservoir_correspondence_type")[1],
            Configurations_VirtualReservoirCorrespondenceType.T,
        )

    # Load vectors
    configurations.subperiod_duration_in_hours =
        PSRI.get_vectors(inputs.db, "Configuration", "subperiod_duration_in_hours")[1]
    configurations.expected_number_of_repeats_per_node =
        PSRI.get_vectors(inputs.db, "Configuration", "expected_number_of_repeats_per_node")[1]

    # Load time series files
    configurations.hour_subperiod_map_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "Configuration", "hour_subperiod_map")
    configurations.fcf_cuts_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "Configuration", "fcf_cuts")
    configurations.period_season_map_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "Configuration", "period_season_map")

    update_time_series_from_db!(configurations, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_configuration!(db::DatabaseSQLite; kwargs...)

Update the Configuration table in the database.

Example:
```julia
IARA.update_configuration!(
    db;
    number_of_scenarios = 12,
)
```
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

function update_time_series_from_db!(
    configurations::Configurations,
    db::DatabaseSQLite,
    period_date_time::DateTime,
)
    return nothing
end

"""
    validate(configurations::Configurations)

Validate the Configurations' parameters. Return the number of errors found.
"""
function validate(configurations::Configurations)
    num_errors = 0
    if configurations.number_of_periods <= 0
        @error("Number of periods must be positive.")
        num_errors += 1
    end
    if configurations.number_of_scenarios <= 0
        @error("Number of scenarios must be positive.")
        num_errors += 1
    end
    if configurations.number_of_subperiods <= 0
        @error("Number of subperiods must be positive.")
        num_errors += 1
    end
    if configurations.policy_graph_type == Configurations_PolicyGraphType.CYCLIC_WITH_NULL_ROOT
        if is_null(configurations.number_of_nodes)
            @error("Configuration parameter number_of_nodes must be defined when using a cyclic policy graph for SDDP.")
            num_errors += 1
        elseif configurations.number_of_nodes <= 0
            @error(
                "Configuration parameter number_of_nodes must be positive. Current value is $(configurations.number_of_nodes)."
            )
            num_errors += 1
        else # valid number_of_nodes
            if length(configurations.expected_number_of_repeats_per_node) != 0 &&
               length(configurations.expected_number_of_repeats_per_node) != configurations.number_of_nodes
                @error(
                    "Expected number of repeats per node must either be empty or have the same length as the number of nodes."
                )
                num_errors += 1
            end
        end
    end
    if length(configurations.subperiod_duration_in_hours) != configurations.number_of_subperiods
        @error("Subperiod duration in hours must have the same length as the number of subperiods.")
        num_errors += 1
    end
    if configurations.demand_deficit_cost < 0
        @error("Demand Unit deficit cost must be non-negative.")
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
    if configurations.market_clearing_tiebreaker_weight < 0
        @error(
            "Market clearing tiebreaker weight cannot be less than zero. Current value: $(configurations.market_clearing_tiebreaker_weight)"
        )
        num_errors += 1
    end
    if configurations.policy_graph_type == Configurations_PolicyGraphType.CYCLIC_WITH_NULL_ROOT &&
       configurations.cycle_discount_rate == 0
        @error(
            "If the policy graph is not linear, the cycle discount rate must be positive. Current discount rate: $(configurations.cycle_discount_rate)"
        )
        num_errors += 1
    end
    if configurations.inflow_scenarios_files == Configurations_UncertaintyScenariosFiles.NONE &&
       is_null(configurations.parp_max_lags)
        @error("Inflow is set to use the PAR(p) model, but the maximum number of lags is undefined.")
        num_errors += 1
    end
    if configurations.clearing_hydro_representation == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS &&
       configurations.bid_data_source == Configurations_BidDataSource.READ_FROM_FILE
        @error("Virtual reservoirs cannot be used with clearing bid source READ_FROM_FILE.")
        num_errors += 1
    end
    if configurations.integer_variable_representation_ex_ante_physical ==
       Configurations_IntegerVariableRepresentation.FROM_EX_ANTE_PHYSICAL
        @error(
            "Ex-ante physical clearing model cannot have fixed integer variables from previous step, because it is the first step."
        )
        num_errors += 1
    end
    if !is_null(configurations.spot_price_floor) && configurations.spot_price_floor < 0
        @error("Spot price floor must be non-negative.")
        num_errors += 1
    end
    if !is_null(configurations.spot_price_cap) && configurations.spot_price_cap < 0
        @error("Spot price cap must be non-negative.")
        num_errors += 1
    end
    if !is_null(configurations.spot_price_cap) && !is_null(configurations.spot_price_floor) &&
       configurations.spot_price_cap <= configurations.spot_price_floor
        @error("Spot price cap must be greater than the spot price floor.")
        num_errors += 1
    end
    if configurations.integer_variable_representation_mincost ==
       Configurations_IntegerVariableRepresentation.FROM_EX_ANTE_PHYSICAL
        @error(
            "Mincost model cannot have FROM_EX_ANTE_PHYSICAL integer variables, because it is not a clearing problem."
        )
        num_errors += 1
    end
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, configurations::Configurations)

Validate the Configurations' context within the inputs. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, configurations::Configurations)
    num_errors = 0

    if is_market_clearing(inputs)
        model_type_warning = false
        if configurations.clearing_hydro_representation == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
            if (
                configurations.construction_type_ex_ante_physical != Configurations_ConstructionType.HYBRID &&
                configurations.construction_type_ex_ante_physical != Configurations_ConstructionType.SKIP
            )
                model_type_warning = true
                configurations.construction_type_ex_ante_physical = Configurations_ConstructionType.HYBRID
            end
            if (
                configurations.construction_type_ex_ante_commercial != Configurations_ConstructionType.HYBRID &&
                configurations.construction_type_ex_ante_physical != Configurations_ConstructionType.SKIP
            )
                model_type_warning = true
                configurations.construction_type_ex_ante_commercial = Configurations_ConstructionType.HYBRID
            end
            if configurations.construction_type_ex_post_physical == Configurations_ConstructionType.SKIP
                @error("Ex-post physical clearing model cannot be skipped when using virtual reservoirs.")
                num_errors += 1
            elseif configurations.construction_type_ex_ante_physical != Configurations_ConstructionType.HYBRID
                model_type_warning = true
                configurations.construction_type_ex_post_physical = Configurations_ConstructionType.HYBRID
            end
            if (
                configurations.construction_type_ex_post_commercial != Configurations_ConstructionType.HYBRID &&
                configurations.construction_type_ex_ante_physical != Configurations_ConstructionType.SKIP
            )
                model_type_warning = true
                configurations.construction_type_ex_post_commercial = Configurations_ConstructionType.HYBRID
            end
            if model_type_warning
                @warn("All clearing models must be hybrid when using virtual reservoirs.")
            end
        end
        if settlement_type(inputs) == Configurations_SettlementType.NONE
            @warn("Settlement type is NONE. No revenue will be calculated.")
        else
            if configurations.construction_type_ex_post_physical == Configurations_ConstructionType.SKIP &&
               configurations.construction_type_ex_post_commercial == Configurations_ConstructionType.SKIP
                @error(
                    "When using a settlement type, either ex-post physical or ex-post commercial clearing must occur — both cannot be skipped."
                )
                num_errors += 1
            end
            if settlement_type(inputs) in [Configurations_SettlementType.DUAL, Configurations_SettlementType.EX_ANTE]
                if configurations.construction_type_ex_ante_physical == Configurations_ConstructionType.SKIP &&
                   configurations.construction_type_ex_ante_commercial == Configurations_ConstructionType.SKIP
                    @error(
                        "When using settlement type $(settlement_type(inputs)), either ex-ante physical or ex-ante commercial clearing must occur — both cannot be skipped."
                    )
                    num_errors += 1
                end
            end
            if configurations.construction_type_ex_ante_physical == Configurations_ConstructionType.SKIP &&
               settlement_type(inputs) == Configurations_SettlementType.DUAL
                @warn(
                    "The ex-ante physical clearing model is skipped. " *
                    "Instead, generation data for revenue calculation will be sourced from the ex-ante commercial clearing model. " *
                    "This represents a non-standard execution type."
                )
            end
            if configurations.construction_type_ex_post_physical == Configurations_ConstructionType.SKIP
                @warn(
                    "The ex-post physical clearing model is skipped. " *
                    "Instead, generation data for revenue calculation will be sourced from the ex-post commercial clearing model. " *
                    "This represents a non-standard execution type."
                )
            end
        end
    end
    if is_market_clearing(inputs) || run_mode(inputs) == RunMode.SINGLE_PERIOD_HEURISTIC_BID ||
       run_mode(inputs) == RunMode.INTERFACE_CALL
        if configurations.number_of_subscenarios <= 0
            @error("Number of subscenarios must be positive.")
            num_errors += 1
        end
    end
    if configurations.clearing_hydro_representation == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS &&
       !any_elements(inputs, VirtualReservoir)
        @error("Virtual reservoirs must be defined when using the virtual reservoirs clearing representation.")
        num_errors += 1
    end

    # Validate if the cycle_duration_in_years matches other time parameters
    if cyclic_policy_graph(inputs)
        subproblem_duration = sum(subperiod_duration_in_hours(inputs, subperiod) for subperiod in subperiods(inputs))
        calculated_cycle_duration =
            subproblem_duration * sum(expected_number_of_repeats_per_node(inputs, node) for node in nodes(inputs))
        if configurations.cycle_duration_in_hours != calculated_cycle_duration
            @warn(
                """
            Cycle duration in hours is $(configurations.cycle_duration_in_hours). This parameter is used to determine the node discount rate from the cycle discount rate. 
            Actual cycle duration is calculated considering the subproblem duration, number of nodes, and expected number of repeats per node. Its value is $calculated_cycle_duration.
            """
            )
        end
    end

    return num_errors
end

function iara_log_configurations(inputs::AbstractInputs)
    @info("   periods: $(number_of_periods(inputs))")
    @info("   scenarios: $(number_of_scenarios(inputs))")
    @info("   subperiods: $(number_of_subperiods(inputs))")
    @info("")

    if is_market_clearing(inputs)
        @info("Market Clearing Subproblems:")
        @info("")
        @info(Printf.@sprintf " %-20s %-20s %-20s" "Subproblem" "Execution Mode" "Integer Variables")
        for clearing_model_subproblem in instances(RunTime_ClearingSubproblem.T)
            run_time_options = RunTimeOptions(; clearing_model_subproblem = clearing_model_subproblem)
            iara_log(inputs, run_time_options)
        end
    end

    return nothing
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

"""
    path_case(inputs::AbstractInputs)

Return the path to the case.
"""
path_case(inputs::AbstractInputs) = inputs.collections.configurations.path_case

"""
    path_parp(inputs::AbstractInputs)

Return the path to the PAR(p) model files.
"""
path_parp(inputs::AbstractInputs) = joinpath(path_case(inputs), "parp")
path_parp(db::DatabaseSQLite) = joinpath(path_case(db), "parp")

"""
    number_of_periods(inputs::AbstractInputs)

Return the number of periods in the problem.
"""
number_of_periods(inputs::AbstractInputs) = inputs.collections.configurations.number_of_periods
"""
    periods(inputs::AbstractInputs)

Return all problem periods.
"""
periods(inputs::AbstractInputs) = collect(1:number_of_periods(inputs))

"""
    number_of_scenarios(inputs::AbstractInputs)

Return the number of scenarios in the problem.
"""
number_of_scenarios(inputs::AbstractInputs) = inputs.collections.configurations.number_of_scenarios

"""
    scenarios(inputs::AbstractInputs)

Return all problem scenarios.
"""
scenarios(inputs::AbstractInputs) = collect(1:number_of_scenarios(inputs))

"""
    number_of_subperiods(inputs::AbstractInputs)

Return the number of subperiods in the problem.
"""
number_of_subperiods(inputs::AbstractInputs) = inputs.collections.configurations.number_of_subperiods

"""
    subperiods(inputs::AbstractInputs)

Return all problem subperiods.
"""
subperiods(inputs::AbstractInputs) = collect(1:number_of_subperiods(inputs))

"""
    number_of_nodes(inputs::AbstractInputs)

Return the number of nodes in the SDDP policy graph.
"""
number_of_nodes(inputs::AbstractInputs) = inputs.collections.configurations.number_of_nodes

"""
    nodes(inputs::AbstractInputs)

Return all nodes in the SDDP policy graph, except for the root node.
"""
nodes(inputs::AbstractInputs) = collect(1:number_of_nodes(inputs))

"""
    number_of_subscenarios(inputs::AbstractInputs, run_time_options)

Return the number of subscenarios to simulate.
"""
function number_of_subscenarios(inputs::AbstractInputs, run_time_options)
    if is_ex_post_problem(run_time_options) || run_time_options.is_post_processing
        return inputs.collections.configurations.number_of_subscenarios
    else
        return 1
    end
end

"""
    subscenarios(inputs::AbstractInputs, run_time_options)

Return all subscenarios to simulate.
"""
subscenarios(inputs::AbstractInputs, run_time_options) = collect(1:number_of_subscenarios(inputs, run_time_options))

"""
    iteration_limit(inputs::AbstractInputs)

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
    initial_date_time(inputs::AbstractInputs)

Return the initial date of the problem.
"""
initial_date_time(inputs::AbstractInputs) = inputs.collections.configurations.initial_date_time

"""
    time_series_step(inputs::AbstractInputs)

Return the Time series step.
"""
time_series_step(inputs::AbstractInputs) = inputs.collections.configurations.time_series_step

"""
    periods_per_year(inputs::AbstractInputs)

Return the number of periods per year.
"""
function periods_per_year(inputs::AbstractInputs)
    if time_series_step(inputs) == Configurations_TimeSeriesStep.ONE_MONTH_PER_PERIOD
        return 12
    else
        error("Time series step $(time_series_step(inputs)) not implemented.")
    end
end

"""
    subperiod_duration_in_hours(inputs::AbstractInputs)

Return the subperiod duration in hours for all subperiods.
"""
subperiod_duration_in_hours(inputs::AbstractInputs) = inputs.collections.configurations.subperiod_duration_in_hours

"""
    subperiod_duration_in_hours(inputs::AbstractInputs, subperiod::Int)

Return the subperiod duration in hours for a given subperiod.
"""
subperiod_duration_in_hours(inputs::AbstractInputs, subperiod::Int) =
    inputs.collections.configurations.subperiod_duration_in_hours[subperiod]

"""
    run_mode(inputs::AbstractInputs)

Return the run mode.
"""
run_mode(inputs::AbstractInputs) = inputs.args.run_mode

"""
    is_market_clearing(inputs::AbstractInputs)

Return whether the run mode is MARKET_CLEARING or SINGLE_PERIOD_MARKET_CLEARING.
"""
is_market_clearing(inputs::AbstractInputs) =
    run_mode(inputs) in [RunMode.MARKET_CLEARING, RunMode.SINGLE_PERIOD_MARKET_CLEARING]

"""
    is_single_period(inputs::AbstractInputs)

Return whether the run mode is SINGLE_PERIOD_MARKET_CLEARING or SINGLE_PERIOD_HEURISTIC_BID.
"""
is_single_period(inputs::AbstractInputs) =
    run_mode(inputs) in [RunMode.SINGLE_PERIOD_MARKET_CLEARING, RunMode.SINGLE_PERIOD_HEURISTIC_BID]

"""
    policy_graph_type(inputs::AbstractInputs)

Return the policy graph type.
"""
policy_graph_type(inputs::AbstractInputs) = inputs.collections.configurations.policy_graph_type

"""
    linear_policy_graph(inputs::AbstractInputs)

Return whether the policy graph is linear.
"""
linear_policy_graph(inputs::AbstractInputs) =
    policy_graph_type(inputs) == Configurations_PolicyGraphType.LINEAR

"""
    cyclic_policy_graph(inputs::AbstractInputs)

Return whether the policy graph is cyclic.
"""
function cyclic_policy_graph(inputs::AbstractInputs)
    if policy_graph_type(inputs) == Configurations_PolicyGraphType.CYCLIC_WITH_NULL_ROOT ||
       policy_graph_type(inputs) == Configurations_PolicyGraphType.CYCLIC_WITH_SEASON_ROOT
        return true
    else
        return false
    end
end

"""
    expected_number_of_repeats_per_node(inputs::AbstractInputs)

Return the expected number of repeats per node.
"""
function expected_number_of_repeats_per_node(inputs::AbstractInputs)
    # If the vector is empty, return 1 as a default value
    if isempty(inputs.collections.configurations.expected_number_of_repeats_per_node)
        return ones(Int, number_of_nodes(inputs))
    else
        return inputs.collections.configurations.expected_number_of_repeats_per_node
    end
end

"""
    expected_number_of_repeats_per_node(inputs::AbstractInputs, node::Int)

Return the expected number of repeats for a given node.
"""
function expected_number_of_repeats_per_node(inputs::AbstractInputs, node::Int)
    # If the vector is empty, return 1 as a default value
    if isempty(inputs.collections.configurations.expected_number_of_repeats_per_node)
        return 1
    else
        return inputs.collections.configurations.expected_number_of_repeats_per_node[node]
    end
end

"""
    use_binary_variables(inputs::AbstractInputs, run_time_options)

Return whether binary variables should be used.
"""
function use_binary_variables(inputs::AbstractInputs, run_time_options)
    ivr = integer_variable_representation(inputs, run_time_options)
    return ivr == Configurations_IntegerVariableRepresentation.CALCULATE_NORMALLY ||
           ivr == Configurations_IntegerVariableRepresentation.FROM_EX_ANTE_PHYSICAL
end

"""
    loop_subperiods_for_thermal_constraints(inputs::AbstractInputs)

Return whether subperiods should be looped for thermal constraints.
"""
loop_subperiods_for_thermal_constraints(inputs::AbstractInputs) =
    inputs.collections.configurations.loop_subperiods_for_thermal_constraints ==
    Configurations_ConsiderSubperiodsLoopForThermalConstraints.CONSIDER

"""
    cycle_discount_rate(inputs::AbstractInputs)

Return the cycle discount rate.
"""
cycle_discount_rate(inputs::AbstractInputs) = inputs.collections.configurations.cycle_discount_rate

"""
    period_discount_rate(inputs::AbstractInputs)

Return the discount rate per period.
"""
function period_discount_rate(inputs::AbstractInputs)
    return 1 - ((1 - cycle_discount_rate(inputs))^(1 / periods_per_year(inputs)))
end

"""
    cycle_duration_in_hours(inputs::AbstractInputs)

Return the cycle duration in hours.
"""
cycle_duration_in_hours(inputs::AbstractInputs) =
    inputs.collections.configurations.cycle_duration_in_hours

"""
    aggregate_buses_for_strategic_bidding(inputs::AbstractInputs)

Return whether buses should be aggregated for strategic bidding.
"""
aggregate_buses_for_strategic_bidding(inputs::AbstractInputs) =
    inputs.collections.configurations.aggregate_buses_for_strategic_bidding ==
    Configurations_BusesAggregationForStrategicBidding.AGGREGATE

"""
    parp_max_lags(inputs::AbstractInputs)

Return the maximum number of lags in the PAR(p) model.
"""
parp_max_lags(inputs::AbstractInputs) = inputs.collections.configurations.parp_max_lags

"""
    renewable_scenarios_files(inputs::AbstractInputs)

Return which renewable scenarios files should be read.
"""
renewable_scenarios_files(inputs::AbstractInputs) =
    inputs.collections.configurations.renewable_scenarios_files

"""
    read_ex_ante_renewable_file(inputs::AbstractInputs)

Return whether the ex-ante renewable file should be read.
"""
function read_ex_ante_renewable_file(inputs::AbstractInputs)
    return renewable_scenarios_files(inputs) in [
        Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
        Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    ]
end

"""
    read_ex_post_renewable_file(inputs::AbstractInputs)

Return whether the ex-ante renewable file should be read.
"""
function read_ex_post_renewable_file(inputs::AbstractInputs)
    return renewable_scenarios_files(inputs) in [
        Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
        Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    ]
end

"""
    inflow_scenarios_files(inputs::AbstractInputs)

Return which inflow scenarios files should be read.
"""
inflow_scenarios_files(inputs::AbstractInputs) =
    inputs.collections.configurations.inflow_scenarios_files

"""
    read_ex_ante_inflow_file(inputs::AbstractInputs)

Return whether the ex-ante inflow file should be read.
"""
function read_ex_ante_inflow_file(inputs::AbstractInputs)
    return inflow_scenarios_files(inputs) in [
        Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
        Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    ]
end

"""
    read_ex_post_inflow_file(inputs::AbstractInputs)

Return whether the ex-ante inflow file should be read.
"""
function read_ex_post_inflow_file(inputs::AbstractInputs)
    return inflow_scenarios_files(inputs) in [
        Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
        Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    ]
end

"""
    demand_scenarios_files(inputs::AbstractInputs)

Return which demand scenarios files should be read.
"""
demand_scenarios_files(inputs::AbstractInputs) =
    inputs.collections.configurations.demand_scenarios_files

"""
    read_ex_ante_demand_file(inputs::AbstractInputs)

Return whether the ex-ante demand file should be read.
"""
function read_ex_ante_demand_file(inputs::AbstractInputs)
    return demand_scenarios_files(inputs) in [
        Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
        Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    ]
end

"""
    read_ex_post_demand_file(inputs::AbstractInputs)

Return whether the ex-ante demand file should be read.
"""
function read_ex_post_demand_file(inputs::AbstractInputs)
    return demand_scenarios_files(inputs) in [
        Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
        Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    ]
end

"""
    read_ex_ante_file(files_to_read::Configurations_UncertaintyScenariosFiles.T)

Return whether the ex-ante file should be read.
"""
read_ex_ante_file(files_to_read::Configurations_UncertaintyScenariosFiles.T) =
    files_to_read in [
        Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
        Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    ]

"""
    read_ex_post_file(files_to_read::Configurations_UncertaintyScenariosFiles.T)

Return whether the ex-post file should be read.
"""
read_ex_post_file(files_to_read::Configurations_UncertaintyScenariosFiles.T) =
    files_to_read in [
        Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
        Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    ]

"""
    read_inflow_from_file(inputs::AbstractInputs)

Return whether inflow should be read from a file.
"""
read_inflow_from_file(inputs::AbstractInputs) =
    inputs.collections.configurations.inflow_scenarios_files != Configurations_UncertaintyScenariosFiles.NONE

"""
    read_bids_from_file(inputs::AbstractInputs)

Return whether bids should be read from a file.
"""
function read_bids_from_file(inputs::AbstractInputs)
    no_file_model_types = [
        Configurations_ConstructionType.SKIP,
        Configurations_ConstructionType.COST_BASED,
    ]
    if construction_type_ex_ante_physical(inputs) in no_file_model_types &&
       construction_type_ex_ante_commercial(inputs) in no_file_model_types &&
       construction_type_ex_post_physical(inputs) in no_file_model_types &&
       construction_type_ex_post_commercial(inputs) in no_file_model_types
        return false
    end
    return inputs.collections.configurations.bid_data_source == Configurations_BidDataSource.READ_FROM_FILE
end

"""
    generate_heuristic_bids_for_clearing(inputs::AbstractInputs)

Return whether heuristic bids should be generated for clearing.
"""
function generate_heuristic_bids_for_clearing(inputs::AbstractInputs)
    no_file_model_types = [
        Configurations_ConstructionType.SKIP,
        Configurations_ConstructionType.COST_BASED,
    ]
    if construction_type_ex_ante_physical(inputs) in no_file_model_types &&
       construction_type_ex_ante_commercial(inputs) in no_file_model_types &&
       construction_type_ex_post_physical(inputs) in no_file_model_types &&
       construction_type_ex_post_commercial(inputs) in no_file_model_types
        return false
    end
    return inputs.collections.configurations.bid_data_source == Configurations_BidDataSource.PRICETAKER_HEURISTICS
end

"""
    bid_data_source(inputs::AbstractInputs)

Return the clearing bid source.
"""
bid_data_source(inputs::AbstractInputs) = inputs.collections.configurations.bid_data_source

"""
    clearing_hydro_representation(inputs::AbstractInputs)

Return the clearing hydro representation.
"""
clearing_hydro_representation(inputs::AbstractInputs) =
    inputs.collections.configurations.clearing_hydro_representation

"""
    construction_type_ex_ante_physical(inputs::AbstractInputs)

Return the ex-ante physical clearing model type.
"""
construction_type_ex_ante_physical(inputs::AbstractInputs) =
    inputs.collections.configurations.construction_type_ex_ante_physical

"""
    construction_type_ex_ante_commercial(inputs::AbstractInputs)

Return the ex-ante commercial clearing model type.
"""
construction_type_ex_ante_commercial(inputs::AbstractInputs) =
    inputs.collections.configurations.construction_type_ex_ante_commercial

"""
    construction_type_ex_post_physical(inputs::AbstractInputs)

Return the ex-post physical clearing model type.
"""
construction_type_ex_post_physical(inputs::AbstractInputs) =
    inputs.collections.configurations.construction_type_ex_post_physical

"""
    construction_type_ex_post_commercial(inputs::AbstractInputs)

Return the ex-post commercial clearing model type.
"""
construction_type_ex_post_commercial(inputs::AbstractInputs) =
    inputs.collections.configurations.construction_type_ex_post_commercial

"""
    integer_variable_representation_mincost(inputs::AbstractInputs)

Return the clearing integer variables type for mincost.
"""
integer_variable_representation_mincost(inputs::AbstractInputs) =
    inputs.collections.configurations.integer_variable_representation_mincost

"""
    integer_variable_representation_ex_ante_physical(inputs::AbstractInputs)

Return the clearing integer variables type for ex-ante physical.
"""
integer_variable_representation_ex_ante_physical(inputs::AbstractInputs) =
    inputs.collections.configurations.integer_variable_representation_ex_ante_physical

"""
    integer_variable_representation_ex_ante_commercial(inputs::AbstractInputs)

Return the clearing integer variables type for ex-ante commercial.
"""
integer_variable_representation_ex_ante_commercial(inputs::AbstractInputs) =
    inputs.collections.configurations.integer_variable_representation_ex_ante_commercial

"""
    integer_variable_representation_ex_post_physical(inputs::AbstractInputs)

Return the clearing integer variables type for ex-post physical.
"""
integer_variable_representation_ex_post_physical(inputs::AbstractInputs) =
    inputs.collections.configurations.integer_variable_representation_ex_post_physical

"""
    integer_variable_representation_ex_post_commercial(inputs::AbstractInputs)

Return the clearing integer variables type for ex-post commercial.
"""
integer_variable_representation_ex_post_commercial(inputs::AbstractInputs) =
    inputs.collections.configurations.integer_variable_representation_ex_post_commercial

"""
    network_representation_mincost(inputs::AbstractInputs)

Return the network representation for the mincost model.
"""
network_representation_mincost(inputs::AbstractInputs) =
    inputs.collections.configurations.network_representation_mincost

"""
    network_representation_ex_ante_physical(inputs::AbstractInputs)

Return the network representation for the ex-ante physical model.
"""
network_representation_ex_ante_physical(inputs::AbstractInputs) =
    inputs.collections.configurations.network_representation_ex_ante_physical

"""
    network_representation_ex_ante_commercial(inputs::AbstractInputs)

Return the network representation for the ex-ante commercial model.
"""
network_representation_ex_ante_commercial(inputs::AbstractInputs) =
    inputs.collections.configurations.network_representation_ex_ante_commercial

"""
    network_representation_ex_post_physical(inputs::AbstractInputs)

Return the network representation for the ex-post physical model.
"""
network_representation_ex_post_physical(inputs::AbstractInputs) =
    inputs.collections.configurations.network_representation_ex_post_physical

"""
    network_representation_ex_post_commercial(inputs::AbstractInputs)

Return the network representation for the ex-post commercial model.
"""
network_representation_ex_post_commercial(inputs::AbstractInputs) =
    inputs.collections.configurations.network_representation_ex_post_commercial

"""
    use_fcf_in_clearing(inputs::AbstractInputs)

Return whether the FCF should be used in clearing.
"""
use_fcf_in_clearing(inputs::AbstractInputs) = inputs.collections.configurations.use_fcf_in_clearing

"""
    settlement_type(inputs::AbstractInputs)

Return the settlement type.
"""
settlement_type(inputs::AbstractInputs) = inputs.collections.configurations.settlement_type

"""
    make_whole_payments(inputs::AbstractInputs)

Return the make whole payments type.
"""
make_whole_payments(inputs::AbstractInputs) = inputs.collections.configurations.make_whole_payments

"""
    price_limits(inputs::AbstractInputs)

Return the price cap type.
"""
price_limits(inputs::AbstractInputs) = inputs.collections.configurations.price_limits

"""
    demand_deficit_cost(inputs::AbstractInputs)

Return the deficit cost of demands.
"""
demand_deficit_cost(inputs::AbstractInputs) = inputs.collections.configurations.demand_deficit_cost

"""
    hydro_minimum_outflow_violation_cost(inputs::AbstractInputs)

Return the cost of violating the minimum outflow in hydro units.
"""
hydro_minimum_outflow_violation_cost(inputs::AbstractInputs) =
    inputs.collections.configurations.hydro_minimum_outflow_violation_cost

"""
    hydro_spillage_cost(inputs::AbstractInputs)

Return the cost of spilling water in hydro units.
"""
hydro_spillage_cost(inputs::AbstractInputs) = inputs.collections.configurations.hydro_spillage_cost

"""
    market_clearing_tiebreaker_weight(inputs::AbstractInputs)

Return the market clearing tiebreaker weight applied to physical generation costs.
"""
market_clearing_tiebreaker_weight(inputs::AbstractInputs) =
    inputs.collections.configurations.market_clearing_tiebreaker_weight

"""
    hour_subperiod_map_file(inputs::AbstractInputs)

Return the file with the hour to subperiod map.
"""
hour_subperiod_map_file(inputs::AbstractInputs) = inputs.collections.configurations.hour_subperiod_map_file

"""
    has_hour_subperiod_map(inputs::AbstractInputs)

Return whether the hour to subperiod map file is defined.
"""
has_hour_subperiod_map(inputs::AbstractInputs) = hour_subperiod_map_file(inputs) != ""

"""
    fcf_cuts_file(inputs::AbstractInputs)

Return the file with the FCF cuts.
"""
fcf_cuts_file(inputs::AbstractInputs) = inputs.collections.configurations.fcf_cuts_file

"""
    has_fcf_cuts(inputs::AbstractInputs)

Return whether the FCF cuts file is defined.
"""
has_fcf_cuts_to_read(inputs::AbstractInputs) = fcf_cuts_file(inputs) != ""

"""
    period_season_map_file(inputs::AbstractInputs)

Return the file with the period to season map.
"""
period_season_map_file(inputs::AbstractInputs) = inputs.collections.configurations.period_season_map_file

"""
    has_period_season_map_file(inputs::AbstractInputs)

Return whether the period to season map file is defined.
"""
has_period_season_map_file(inputs::AbstractInputs) = period_season_map_file(inputs) != ""

"""
    hydro_balance_subperiod_resolution(inputs::AbstractInputs)

Return the hydro balance subperiod resolution.
"""
hydro_balance_subperiod_resolution(inputs::AbstractInputs) =
    inputs.collections.configurations.hydro_balance_subperiod_resolution

"""
    vr_curveguide_data_source(inputs)

Return the source of the waveguide points for virtual reservoirs.
"""
vr_curveguide_data_source(inputs) =
    inputs.collections.configurations.vr_curveguide_data_source

"""
    vr_curveguide_data_format(inputs)

Return the source of the user-provided waveguide points.
"""
vr_curveguide_data_format(inputs) =
    inputs.collections.configurations.vr_curveguide_data_format

"""
    virtual_reservoir_correspondence_type(inputs)

Return the type of physical-virtual correspondence for the virtual reservoirs.
"""
virtual_reservoir_correspondence_type(inputs) =
    inputs.collections.configurations.virtual_reservoir_correspondence_type

"""
    integer_variable_representation(inputs::Inputs, run_time_options)

Determine the integer variables representation.
"""
function integer_variable_representation(inputs::AbstractInputs, run_time_options)
    if is_mincost(inputs)
        return integer_variable_representation_mincost(inputs)
    elseif is_ex_ante_problem(run_time_options)
        if is_physical_problem(run_time_options)
            return integer_variable_representation_ex_ante_physical(inputs)
        elseif is_commercial_problem(run_time_options)
            return integer_variable_representation_ex_ante_commercial(inputs)
        end
    elseif is_ex_post_problem(run_time_options)
        if is_physical_problem(run_time_options)
            return integer_variable_representation_ex_post_physical(inputs)
        elseif is_commercial_problem(run_time_options)
            return integer_variable_representation_ex_post_commercial(inputs)
        end
    else
        # TODO review this. This is what is happening in PRICE TAKER and STRATEGIC BID
        return Configurations_IntegerVariableRepresentation.CALCULATE_NORMALLY
    end
end

"""
    network_representation(inputs::Inputs, run_time_options)

Determine the network representation.
"""
function network_representation(inputs::AbstractInputs, run_time_options)
    if is_mincost(inputs)
        return network_representation_mincost(inputs)
    elseif is_ex_ante_problem(run_time_options)
        if is_physical_problem(run_time_options)
            return network_representation_ex_ante_physical(inputs)
        elseif is_commercial_problem(run_time_options)
            return network_representation_ex_ante_commercial(inputs)
        end
    elseif is_ex_post_problem(run_time_options)
        if is_physical_problem(run_time_options)
            return network_representation_ex_post_physical(inputs)
        elseif is_commercial_problem(run_time_options)
            return network_representation_ex_post_commercial(inputs)
        end
    else
        error("Not implemented")
    end
end

"""
    period_season_map(inputs::AbstractInputs)

Return the period to season map.
"""
period_season_map_cache(inputs::AbstractInputs; period::Int, scenario::Int) =
    inputs.collections.configurations.period_season_map[:, scenario, period]
