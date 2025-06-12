#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

available_values_list(enum_type) = vcat(instances(enum_type)...)
function string_of_available_values(enum_type)
    values_list = available_values_list(enum_type)
    str = ""
    for (i, value) in enumerate(values_list)
        str *= "  - $(value) : $(Int(value))"
        if i != length(values_list)
            str *= "\n"
        end
    end
    return str
end
function convert_to_enum(value::Int, enum_type)
#! format: off
    try
        return enum_type(value)
    catch e
        if isa(e, ArgumentError)
            @error(
                """
                Invalid value for enum type $enum_type: $value. The available values are: 
				$(string_of_available_values(enum_type))
                """
            )
        end
        rethrow()
    end
#! format: on
end

"""
    Configurations_PolicyGraphType

  - `CYCLIC_WITH_NULL_ROOT`: Cyclic policy graph starting at node 1 (0)
  - `LINEAR`: Linear policy graph (1)
  - `CYCLIC_WITH_SEASON_ROOT`: Cyclic policy graph with equal chance of starting at any node (2)
"""
@enumx Configurations_PolicyGraphType begin
    CYCLIC_WITH_NULL_ROOT = 0
    LINEAR = 1
    CYCLIC_WITH_SEASON_ROOT = 2
end

"""
    RunMode

  - `TRAIN_MIN_COST`: Centralized operation (0)
  - `PRICE_TAKER_BID`: Price taker bid (1)
  - `STRATEGIC_BID`: Strategic bid (2)
  - `MARKET_CLEARING`: Market clearing (3)
  - `MIN_COST`: Centralized operation simulation (4)
  - `SINGLE_PERIOD_MARKET_CLEARING`: Single period market clearing (5)
  - `SINGLE_PERIOD_HEURISTIC_BID`: Single period heuristic bid (6)
  - `INTERFACE_CALL`: Interface call (7)
"""
@enumx RunMode begin
    TRAIN_MIN_COST = 0
    PRICE_TAKER_BID = 1
    STRATEGIC_BID = 2
    MARKET_CLEARING = 3
    MIN_COST = 4
    SINGLE_PERIOD_MARKET_CLEARING = 5
    SINGLE_PERIOD_HEURISTIC_BID = 6
    INTERFACE_CALL = 7
end

const AVAILABLE_RUN_MODES_MESSAGE = """
    The available run modes are:
    - train-min-cost
    - min-cost
    - price-taker-bid
    - strategic-bid
    - market-clearing
    - single-period-market-clearing
    - single-period-heuristic-bid
    - interface-call
    - single-period-hydro-supply-reference-curve
    """

function parse_run_mode(run_mode::Union{String, Nothing})
    if run_mode == "train-min-cost"
        return RunMode.TRAIN_MIN_COST
    elseif run_mode == "price-taker-bid"
        return RunMode.PRICE_TAKER_BID
    elseif run_mode == "strategic-bid"
        return RunMode.STRATEGIC_BID
    elseif run_mode == "market-clearing"
        return RunMode.MARKET_CLEARING
    elseif run_mode == "min-cost"
        return RunMode.MIN_COST
    elseif run_mode == "single-period-market-clearing"
        return RunMode.SINGLE_PERIOD_MARKET_CLEARING
    elseif run_mode == "single-period-heuristic-bid"
        return RunMode.SINGLE_PERIOD_HEURISTIC_BID
    elseif run_mode == "interface-call"
        return RunMode.INTERFACE_CALL
    else
        error(
            """
            Run mode not implemented: \"$run_mode\".

            $AVAILABLE_RUN_MODES_MESSAGE
            """,
        )
    end
end

"""
    Configurations_TimeSeriesStep

  - `ONE_MONTH_PER_PERIOD`: Monthly period (0)
"""
@enumx Configurations_TimeSeriesStep begin
    ONE_MONTH_PER_PERIOD = 0
end

@enumx Configurations_HydroBalanceSubperiodResolution begin
    CHRONOLOGICAL_SUBPERIODS = 0
    AGGREGATED_SUBPERIODS = 1
end

# TODO review this implementation in favour of something more generic
function period_type_string(time_series_step::Configurations_TimeSeriesStep.T)
    if time_series_step == Configurations_TimeSeriesStep.ONE_MONTH_PER_PERIOD
        return "monthly"
    else
        error("Time series step not implemented")
    end
end

"""
    Configurations_VariableAggregationType

  - `SUM`: Sum (0)
  - `AVERAGE`: Average (1)
  - `LAST_VALUE`: Last value (2)
"""
@enumx Configurations_VariableAggregationType begin
    SUM = 0
    AVERAGE = 1
    LAST_VALUE = 2
end

"""
  Configurations_BidDataSource

  - `READ_FROM_FILE`: Read from file (0)
  - `PRICETAKER_HEURISTICS`: Run the heuristic bids module concurrently with clearing, one period at a time (1)
"""
@enumx Configurations_BidDataSource begin
    READ_FROM_FILE = 0
    PRICETAKER_HEURISTICS = 1
end

"""
    Configurations_ClearingHydroRepresentation

  - `PURE_BIDS`: Pure bids (0)
  - `VIRTUAL_RESERVOIRS`: Virtual reservoirs (1)
  - `FUTURE_COST_FUNCTION`: Future cost function (2)
"""
@enumx Configurations_ClearingHydroRepresentation begin
    PURE_BIDS = 0
    VIRTUAL_RESERVOIRS = 1
end

"""
    Configurations_IntegerVariableRepresentation

  - `CALCULATE_NORMALLY`: Fixed (0)
  - `FROM_EX_ANTE_PHYSICAL`: Fixed from previous step (1)
  - `LINEARIZE`: Linearize (2)
"""
@enumx Configurations_IntegerVariableRepresentation begin
    CALCULATE_NORMALLY = 0
    FROM_EX_ANTE_PHYSICAL = 1
    LINEARIZE = 2
end

"""
    Configurations_ConstructionType

  - `SKIP`: Skip (-1)
  - `COST_BASED`: Cost based (0)
  - `BID_BASED`: Bid based (1)
  - `HYBRID`: Hybrid (2)
"""
@enumx Configurations_ConstructionType begin
    SKIP = -1
    COST_BASED = 0
    BID_BASED = 1
    HYBRID = 2
end

"""
    Configurations_UncertaintyScenariosFiles

  - `NONE`: None (0)
  - `ONLY_EX_ANTE`: Only ex-ante (1)
  - `ONLY_EX_POST`: Only ex-post (2)
  - `EX_ANTE_AND_EX_POST`: Ex-ante and ex-post (3)
"""
@enumx Configurations_UncertaintyScenariosFiles begin
    NONE = 0
    ONLY_EX_ANTE = 1
    ONLY_EX_POST = 2
    EX_ANTE_AND_EX_POST = 3
end

"""
    Configurations_SettlementType

  - `NONE`: None (-1)
  - `EX_ANTE`: Ex-ante (0)
  - `EX_POST`: Ex-post (1)
  - `DOUBLE`: Double (2)
"""
@enumx Configurations_SettlementType begin
    NONE = -1
    EX_ANTE = 0
    EX_POST = 1
    DOUBLE = 2
end

"""
    Configurations_MakeWholePayments

  - `CONSTRAINED_ON_AND_OFF_PER_SUBPERIOD`: Constrained on and off per subperiod (0)
  - `CONSTRAINED_ON_PER_SUBPERIOD`: Constrained on per subperiod (1)
  - `CONSTRAINED_ON_PERIOD_AGGREGATE`: Constrained on daily aggregate (2)
  - `IGNORE`: Ignore (3)
"""
@enumx Configurations_MakeWholePayments begin
    CONSTRAINED_ON_AND_OFF_PER_SUBPERIOD = 0
    CONSTRAINED_ON_PER_SUBPERIOD = 1
    CONSTRAINED_ON_PERIOD_AGGREGATE = 2
    IGNORE = 3
end

"""
    Configurations_PriceLimits

  - `REPRESENT`: Represent (0)
  - `IGNORE`: Ignore (1)
"""
@enumx Configurations_PriceLimits begin
    REPRESENT = 0
    IGNORE = 1
end

"""
    Configurations_ConsiderSubperiodsLoopForThermalConstraints

  - `CONSIDER`: Consider subperiods loop for thermal constraints (1)
  - `DO_NOT_CONSIDER`: Do not consider subperiods loop for thermal constraints (0)
"""
@enumx Configurations_ConsiderSubperiodsLoopForThermalConstraints begin
    CONSIDER = 1
    DO_NOT_CONSIDER = 0
end

"""
    Configurations_BusesAggregationForStrategicBidding

  - `AGGREGATE`: Aggregate buses for strategic bidding (1)
  - `DO_NOT_AGGREGATE`: Do not aggregate buses for strategic bidding (0)
  """
@enumx Configurations_BusesAggregationForStrategicBidding begin
    AGGREGATE = 1
    DO_NOT_AGGREGATE = 0
end

""" 
    Configurations_NetworkRepresentation

  - `NODAL`: Nodal representation (0)
  - `ZONAL`: Zonal representation (1)
"""
@enumx Configurations_NetworkRepresentation begin
    NODAL = 0
    ZONAL = 1
end

"""
    HydroUnit_InitialVolumeType

  - `PER_UNIT`: Initial volume in per unit (0)
  - `VOLUME`: Initial volume in hm³ (2)
"""
@enumx HydroUnit_InitialVolumeType begin
    PER_UNIT = 0
    VOLUME = 2
end

"""
    HydroUnit_OperationType

  - `RESERVOIR`: Reservoir operation (0)
  - `RUN_OF_RIVER`: Run of river operation (1)
"""
@enumx HydroUnit_OperationType begin
    RESERVOIR = 0
    RUN_OF_RIVER = 1
end

"""
    DemandUnit_DemandType

  - `INELASTIC`: Inelastic demand (0)
  - `ELASTIC`: Elastic demand (1)
  - `FLEXIBLE`: Flexible demand (2)
"""
@enumx DemandUnit_DemandType begin
    INELASTIC = 0
    ELASTIC = 1
    FLEXIBLE = 2
end

"""
    Branch_LineModel

  - `AC`: AC line model (0)
  - `DC`: DC line model (1)
"""
@enumx Branch_LineModel begin
    AC = 0
    DC = 1
end

"""
    AssetOwner_PriceType

  - `PRICE_MAKER`: Price maker (1)
  - `PRICE_TAKER`: Price taker (0)
"""
@enumx AssetOwner_PriceType begin
    PRICE_MAKER = 1
    PRICE_TAKER = 0
end

"""
    RunTime_ClearingSubproblem

  - `EX_ANTE_PHYSICAL`: Ex-Ante physical (0)
  - `EX_ANTE_COMMERCIAL`: Ex-Ante commercial (1)
  - `EX_POST_PHYSICAL`: Ex-Post physical (2)
  - `EX_POST_COMMERCIAL`: Ex-Post commercial (3)
"""
@enumx RunTime_ClearingSubproblem begin
    EX_ANTE_PHYSICAL = 0
    EX_ANTE_COMMERCIAL = 1
    EX_POST_PHYSICAL = 2
    EX_POST_COMMERCIAL = 3
end

"""
  BatteryUnit_Existence

  - `EXISTS`: Battery Unit exists (1)
  - `DOES_NOT_EXIST`: Battery Unit does not exist (0)
"""
@enumx BatteryUnit_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  Branch_Existence

  - `EXISTS`: Branch exists (1)
  - `DOES_NOT_EXIST`: Branch does not exist (0)
"""
@enumx Branch_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  Interconnection_Existence

  - `EXISTS`: Interconnection exists (1)
  - `DOES_NOT_EXIST`: Interconnection does not exist (0)
"""
@enumx Interconnection_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  DCLine_Existence

  - `EXISTS`: DC Line exists (1)
  - `DOES_NOT_EXIST`: DC Line does not exist (0)
"""
@enumx DCLine_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  DemandUnit_Existence

  - `EXISTS`: Demand exists (1)
  - `DOES_NOT_EXIST`: Demand does not exist (0)
"""
@enumx DemandUnit_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  HydroUnit_Existence

  - `EXISTS`: Hydro Unit exists (1)
  - `DOES_NOT_EXIST`: Hydro Unit does not exist (0)
"""
@enumx HydroUnit_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  RenewableUnit_Existence

  - `EXISTS`: Renewable Unit exists (1)
  - `DOES_NOT_EXIST`: Renewable Unit does not exist (0)
"""
@enumx RenewableUnit_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  ThermalUnit_Existence

  - `EXISTS`: Thermal Unit exists (1)
  - `DOES_NOT_EXIST`: Thermal Unit does not exist (0)
"""
@enumx ThermalUnit_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  HydroUnit_HasCommitment

  - `HAS_COMMITMENT`: Hydro Unit has commitment (1)
  - `NO_COMMITMENT`: Hydro Unit has no commitment (0)
"""
@enumx HydroUnit_HasCommitment begin
    HAS_COMMITMENT = 1
    NO_COMMITMENT = 0
end

"""
  ThermalUnit_HasCommitment

  - `HAS_COMMITMENT`: Thermal Unit has commitment (1)
  - `NO_COMMITMENT`: Thermal Unit has no commitment (0)
"""
@enumx ThermalUnit_HasCommitment begin
    HAS_COMMITMENT = 1
    NO_COMMITMENT = 0
end

"""
  ThermalUnit_CommitmentInitialCondition

  - `ON`: Initial condition is ON (1)
  - `OFF`: Initial condition is OFF (0)
"""
@enumx ThermalUnit_CommitmentInitialCondition begin
    ON = 1
    OFF = 0
    UNDEFINED = 2
end

"""
  Configurations_VRCurveguideDataSource

  - `READ_FROM_FILE`: User provided (0)
  - `UNIFORM_ACROSS_RESERVOIRS`: Uniform volume percentage (1)
"""
@enumx Configurations_VRCurveguideDataSource begin
    READ_FROM_FILE = 0
    UNIFORM_ACROSS_RESERVOIRS = 1
end

"""
  Configurations_VRCurveguideDataFormat

  - `CSV_FILE`: CSV file (0)
  - `FORMATTED_DATA`: Existing data (1)
"""
@enumx Configurations_VRCurveguideDataFormat begin
    CSV_FILE = 0
    FORMATTED_DATA = 1
end

@enumx Configurations_VirtualReservoirCorrespondenceType begin
    IGNORE = 0
    STANDARD_CORRESPONDENCE_CONSTRAINT = 1
    DELTA_CORRESPONDENCE_CONSTRAINT = 2
end

@enumx Configurations_VirtualReservoirInitialEnergyAccount begin
    CALCULATED_USING_INFLOW_SHARES = 0
    CALCULATED_USING_ENERGY_ACCOUNT_SHARES = 1
end

@enumx Configurations_BiddingGroupBidValidation begin
    DO_NOT_VALIDATE = 0
    VALIDATE = 1
end
