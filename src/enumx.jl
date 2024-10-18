#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

"""
    Configurations_PolicyGraphType

  - `CYCLIC`: Cyclic policy graph (0)
  - `LINEAR`: Linear policy graph (1)
"""
@enumx Configurations_PolicyGraphType begin
    CYCLIC = 0
    LINEAR = 1
end

"""
    Configurations_InflowSource

  - `SIMULATE_WITH_PARP`: Simulate inflow with PAR(p) (0)
  - `READ_FROM_FILE`: Read inflow from file (1)
"""
@enumx Configurations_InflowSource begin
    SIMULATE_WITH_PARP = 0
    READ_FROM_FILE = 1
end

"""
    Configurations_RunMode

  - `CENTRALIZED_OPERATION`: Centralized operation (0)
  - `PRICE_TAKER_BID`: Price taker bid (1)
  - `STRATEGIC_BID`: Strategic bid (2)
  - `MARKET_CLEARING`: Market clearing (3)
  - `CENTRALIZED_OPERATION_SIMULATION`: Centralized operation simulation (4)
  - `HEURISTIC_BID`: Heuristic bid (5)
"""
@enumx Configurations_RunMode begin
    CENTRALIZED_OPERATION = 0
    PRICE_TAKER_BID = 1
    STRATEGIC_BID = 2
    MARKET_CLEARING = 3
    CENTRALIZED_OPERATION_SIMULATION = 4
    HEURISTIC_BID = 5
end

"""
    Configurations_StageType

  - `MONTHLY`: Monthly stage (0)
"""
@enumx Configurations_StageType begin
    MONTHLY = 0
end

@enumx Configurations_HydroBalanceBlockResolution begin
    CHRONOLOGICAL_BLOCKS = 0
    AGGREGATED_BLOCKS = 1
end

# TODO review this implementation in favour of something more generic
function stage_type_string(stage_type::Configurations_StageType.T)
    if stage_type == Configurations_StageType.MONTHLY
        return "monthly"
    else
        error("Stage type not implemented")
    end
end

"""
    Configurations_BlockAggregationType

  - `SUM`: Sum (0)
  - `AVERAGE`: Average (1)
  - `LAST_VALUE`: Last value (2)
"""
@enumx Configurations_BlockAggregationType begin
    SUM = 0
    AVERAGE = 1
    LAST_VALUE = 2
end

"""
  Configurations_ClearingBidSource

  - `READ_FROM_FILE`: Read from file (0)
  - `HEURISTIC_BIDS`: Run the heuristic bids module concurrently with clearing, one stage at a time (1)
"""
@enumx Configurations_ClearingBidSource begin
    READ_FROM_FILE = 0
    HEURISTIC_BIDS = 1
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
    Configurations_ClearingIntegerVariables

  - `FIXED`: Fixed (0)
  - `FIXED_FROM_PREVIOUS_STEP`: Fixed from previous step (1)
  - `LINEARIZED`: Linearize (2)
"""
@enumx Configurations_ClearingIntegerVariables begin
    FIXED = 0
    FIXED_FROM_PREVIOUS_STEP = 1
    LINEARIZED = 2
end

"""
    Configurations_ClearingModelType

  - `NOT_DEFINED`: Not defined (-1)
  - `COST_BASED`: Cost based (0)
  - `BID_BASED`: Bid based (1)
  - `HYBRID`: Hybrid (2)
"""
@enumx Configurations_ClearingModelType begin
    NOT_DEFINED = -1
    COST_BASED = 0
    BID_BASED = 1
    HYBRID = 2
end

"""
    Configurations_ClearingNetworkRepresentation

  - `NODAL_NODAL`: Nodal-nodal (0)
  - `ZONAL_ZONAL`: Zonal-zonal (1)
  - `NODAL_ZONAL`: Nodal-zonal (2)
"""
@enumx Configurations_ClearingNetworkRepresentation begin
    NODAL_NODAL = 0
    ZONAL_ZONAL = 1
    NODAL_ZONAL = 2
end

"""
    Configurations_SettlementType

  - `EX_ANTE`: Ex-ante (0)
  - `EX_POST`: Ex-post (1)
  - `DUAL`: Dual (2)
"""
@enumx Configurations_SettlementType begin
    EX_ANTE = 0
    EX_POST = 1
    DUAL = 2
end

"""
    Configurations_MakeWholePayments

  - `CONSTRAINED_ON_AND_OFF_INSTANT`: Constrained on and off instant (0)
  - `CONSTRAINED_ON_INSTANT`: Constrained on instant (1)
  - `CONSTRAINED_ON_DAILY_AGGREGATE`: Constrained on daily aggregate (2)
"""
@enumx Configurations_MakeWholePayments begin
    CONSTRAINED_ON_AND_OFF_INSTANT = 0
    CONSTRAINED_ON_INSTANT = 1
    CONSTRAINED_ON_DAILY_AGGREGATE = 2
end

"""
    Configurations_PriceCap

  - `REPRESENT`: Represent (0)
  - `IGNORE`: Ignore (1)
"""
@enumx Configurations_PriceCap begin
    REPRESENT = 0
    IGNORE = 1
end

"""
  Configurations_BinaryVariableUsage

  - `USE`: Use binary variables (1)
  - `DO_NOT_USE`: Do not use binary variables (0)
"""
@enumx Configurations_BinaryVariableUsage begin
    USE = 1
    DO_NOT_USE = 0
end

"""
    Configurations_ConsiderBlocksLoopForThermalConstraints

  - `CONSIDER`: Consider blocks loop for thermal constraints (1)
  - `DO_NOT_CONSIDER`: Do not consider blocks loop for thermal constraints (0)
"""
@enumx Configurations_ConsiderBlocksLoopForThermalConstraints begin
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
    HydroPlant_InitialVolumeType

  - `PER_UNIT`: Initial volume in per unit (0)
  - `VOLUME`: Initial volume in hm³ (2)
"""
@enumx HydroPlant_InitialVolumeType begin
    PER_UNIT = 0
    VOLUME = 2
end

"""
    HydroPlant_OperationType

  - `RESERVOIR`: Reservoir operation (0)
  - `RUN_OF_RIVER`: Run of river operation (1)
"""
@enumx HydroPlant_OperationType begin
    RESERVOIR = 0
    RUN_OF_RIVER = 1
end

"""
    Demand_DemandType

  - `INELASTIC`: Inelastic demand (0)
  - `ELASTIC`: Elastic demand (1)
  - `FLEXIBLE`: Flexible demand (2)
"""
@enumx Demand_DemandType begin
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
    BiddingGroup_BidType

  - `MARKUP_HEURISTIC`: Markup heuristic (0)
  - `OPTIMIZE`: Optimize (1)
"""
@enumx BiddingGroup_BidType begin
    MARKUP_HEURISTIC = 0
    OPTIMIZE = 1
end

"""
    RunTime_ClearingProcedure

  - `EX_ANTE_PHYSICAL`: Ex-Ante physical (0)
  - `EX_ANTE_COMMERCIAL`: Ex-Ante commercial (1)
  - `EX_POST_PHYSICAL`: Ex-Post physical (2)
  - `EX_POST_COMMERCIAL`: Ex-Post commercial (3)
"""
@enumx RunTime_ClearingProcedure begin
    EX_ANTE_PHYSICAL = 0
    EX_ANTE_COMMERCIAL = 1
    EX_POST_PHYSICAL = 2
    EX_POST_COMMERCIAL = 3
end

"""
  Battery_Existence

  - `EXISTS`: Battery exists (1)
  - `DOES_NOT_EXIST`: Battery does not exist (0)
"""
@enumx Battery_Existence begin
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
  DCLine_Existence

  - `EXISTS`: DC Line exists (1)
  - `DOES_NOT_EXIST`: DC Line does not exist (0)
"""
@enumx DCLine_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  Demand_Existence

  - `EXISTS`: Demand exists (1)
  - `DOES_NOT_EXIST`: Demand does not exist (0)
"""
@enumx Demand_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  HydroPlant_Existence

  - `EXISTS`: Hydro Plant exists (1)
  - `DOES_NOT_EXIST`: Hydro Plant does not exist (0)
"""
@enumx HydroPlant_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  RenewablePlant_Existence

  - `EXISTS`: Renewable Plant exists (1)
  - `DOES_NOT_EXIST`: Renewable Plant does not exist (0)
"""
@enumx RenewablePlant_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  ThermalPlant_Existence

  - `EXISTS`: Thermal Plant exists (1)
  - `DOES_NOT_EXIST`: Thermal Plant does not exist (0)
"""
@enumx ThermalPlant_Existence begin
    EXISTS = 1
    DOES_NOT_EXIST = 0
end

"""
  HydroPlant_HasCommitment

  - `HAS_COMMITMENT`: Hydro Plant has commitment (1)
  - `NO_COMMITMENT`: Hydro Plant has no commitment (0)
"""
@enumx HydroPlant_HasCommitment begin
    HAS_COMMITMENT = 1
    NO_COMMITMENT = 0
end

"""
  ThermalPlant_HasCommitment

  - `HAS_COMMITMENT`: Thermal Plant has commitment (1)
  - `NO_COMMITMENT`: Thermal Plant has no commitment (0)
"""
@enumx ThermalPlant_HasCommitment begin
    HAS_COMMITMENT = 1
    NO_COMMITMENT = 0
end

"""
  ThermalPlant_CommitmentInitialCondition

  - `ON`: Initial condition is ON (1)
  - `OFF`: Initial condition is OFF (0)
"""
@enumx ThermalPlant_CommitmentInitialCondition begin
    ON = 1
    OFF = 0
    UNDEFINED = 2
end
