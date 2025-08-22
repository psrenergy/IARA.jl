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
  - `MARKET_CLEARING`: Market clearing (1)
  - `MIN_COST`: Centralized operation simulation (2)
  - `SINGLE_PERIOD_MARKET_CLEARING`: Single period market clearing (3)
  - `SINGLE_PERIOD_HEURISTIC_BID`: Single period heuristic bid (4)
  - `INTERFACE_CALL`: Interface call (5)
"""
@enumx RunMode begin
    TRAIN_MIN_COST = 0
    MARKET_CLEARING = 1
    MIN_COST = 2
    SINGLE_PERIOD_MARKET_CLEARING = 3
    SINGLE_PERIOD_HEURISTIC_BID = 4
    INTERFACE_CALL = 5
end

const AVAILABLE_RUN_MODES_MESSAGE = """
    The available run modes are:
    - train-min-cost
    - min-cost
    - market-clearing
    - single-period-market-clearing
    - single-period-heuristic-bid
    - interface-call
    - single-period-hydro-supply-reference-curve
    """

function parse_run_mode(run_mode::Union{String, Nothing})
    if run_mode == "train-min-cost"
        return RunMode.TRAIN_MIN_COST
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

@enumx Configurations_HydroBalanceSubperiodRepresentation begin
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
    Configurations_NashEquilibriumInitialization

    - `MIN_COST_HEURISTIC`: Min cost initialization (0)
    - `EXTERNAL_BID`: External bid initialization (1)
"""
@enumx Configurations_NashEquilibriumInitialization begin
    MIN_COST_HEURISTIC = 0
    EXTERNAL_BID = 1
end

"""
    Configurations_NashEquilibriumStrategy

    - `DO_NOT_ITERATE`: Do not iterate (0)
    - `SINGLE_PERIOD_ITERATE`: Single period iterate (1)
    - `STANDARD_ITERATION`: Standard iteration (2)
    - `ITERATION_WITH_AGGREGATE_BUSES`: Iteration with aggregate buses (3)
"""
@enumx Configurations_NashEquilibriumStrategy begin
    DO_NOT_ITERATE = 0
    SINGLE_PERIOD_ITERATE = 1
    STANDARD_ITERATION = 2
    ITERATION_WITH_AGGREGATE_BUSES = 3
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
  Configurations_BiddingGroupBidProcessing

  - `EXTERNAL_UNVALIDATED_BID`: Read from file (0)
  - `EXTERNAL_VALIDATED_BID`: Read from file and validated (1)
  - `HEURISTIC_UNVALIDATED_BID`: Run the heuristic bids module concurrently with clearing, one period at a time (2)
  - `HEURISTIC_VALIDATED_BID`: Run the heuristic bids module concurrently with clearing, one period at a time and validated (3)
"""
@enumx Configurations_BiddingGroupBidProcessing begin
    EXTERNAL_UNVALIDATED_BID = 0
    EXTERNAL_VALIDATED_BID = 1
    HEURISTIC_UNVALIDATED_BID = 2
    HEURISTIC_VALIDATED_BID = 3
end

"""
    Configurations_VirtualReservoirBidProcessing

  - `IGNORE_VIRTUAL_RESERVOIRS`: Pure bids (0)
  - `HEURISTIC_BID_FROM_WATER_VALUES`: Virtual reservoirs (1)
  - `HEURISTIC_BID_FROM_HYDRO_REFERENCE_CURVE`: Virtual reservoirs with hydro reference curve (2)
"""
@enumx Configurations_VirtualReservoirBidProcessing begin
    IGNORE_VIRTUAL_RESERVOIRS = 0
    HEURISTIC_BID_FROM_WATER_VALUES = 1
    HEURISTIC_BID_FROM_HYDRO_REFERENCE_CURVE = 2
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

  - `FIT_PARP_MODEL_FROM_DATA`: Fit PAR(p) model from data (0)
  - `ONLY_EX_ANTE`: Only ex-ante (1)
  - `ONLY_EX_POST`: Only ex-post (2)
  - `EX_ANTE_AND_EX_POST`: Ex-ante and ex-post (3)
  - `READ_PARP_COEFFICIENTS`: Read PAR(p) coefficients (4)
"""
@enumx Configurations_UncertaintyScenariosFiles begin
    FIT_PARP_MODEL_FROM_DATA = 0
    ONLY_EX_ANTE = 1
    ONLY_EX_POST = 2
    EX_ANTE_AND_EX_POST = 3
    READ_PARP_COEFFICIENTS = 4
end

"""
   Configurations_FinancialSettlementType

  - `NONE`: None (-1)
  - `EX_ANTE`: Ex-ante (0)
  - `EX_POST`: Ex-post (1)
  - `TWO_SETTLEMENT`: Double (2)
"""
@enumx Configurations_FinancialSettlementType begin
    NONE = -1
    EX_ANTE = 0
    EX_POST = 1
    TWO_SETTLEMENT = 2
end

"""
    Configurations_MakeWholePayments

  - `IGNORE`: Ignore (0)
"""
@enumx Configurations_MakeWholePayments begin
    IGNORE = 0
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
    Configurations_ThermalUnitIntraPeriodOperation

  - `CYCLIC_WITH_FLEXIBLE_START`: Consider subperiods loop for thermal constraints (1)
  - `FLEXIBLE_START_FLEXIBLE_END`: Do not consider subperiods loop for thermal constraints (0)
"""
@enumx Configurations_ThermalUnitIntraPeriodOperation begin
    CYCLIC_WITH_FLEXIBLE_START = 1
    FLEXIBLE_START_FLEXIBLE_END = 0
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
    HydroUnit_InitialVolumeDataType

  - `FRACTION_OF_USEFUL_VOLUME`: Initial volume in per unit (0)
  - `ABSOLUTE_VOLUME_IN_HM3`: Initial volume in hm³ (2)
"""
@enumx HydroUnit_InitialVolumeDataType begin
    FRACTION_OF_USEFUL_VOLUME = 0
    ABSOLUTE_VOLUME_IN_HM3 = 2
end

"""
    HydroUnit_IntraPeriodOperation

  - `STATE_VARIABLE`: Reservoir operation (0)
  - `CYCLIC_WITH_FLEXIBLE_START`: Run of river operation (1)
"""
@enumx HydroUnit_IntraPeriodOperation begin
    STATE_VARIABLE = 0
    CYCLIC_WITH_FLEXIBLE_START = 1
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
  - `SUPPLY_SECURITY_AGENT`: Supply security agent (2)
"""
@enumx AssetOwner_PriceType begin
    PRICE_MAKER = 1
    PRICE_TAKER = 0
    SUPPLY_SECURITY_AGENT = 2
end

"""
    BiddingGroup_ExPostAdjustMode

    - `NO_ADJUSTMENT`: No adjustment (0)
    - `PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_GENERATION`: Adjust to ex-post availability (1)
    - `PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID`: Adjust to ex-ante bid (2)
"""
@enumx BiddingGroup_ExPostAdjustMode begin
    NO_ADJUSTMENT = 0
    PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_GENERATION = 1
    PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID = 2
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

  - `EXTERNAL_UNVALIDATED_BID`: User provided (0)
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

@enumx Configurations_ConsiderPurchaseBidsForVirtualReservoirHeuristicBid begin
    DO_NOT_CONSIDER = 0
    CONSIDER = 1
end

@enumx BiddingGroup_BidPriceLimitSource begin
    DEFAULT_LIMIT = 0
    READ_FROM_FILE = 1
end
