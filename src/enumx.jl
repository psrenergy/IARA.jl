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
    FUTURE_COST_FUNCTION = 2
end

"""
    Configurations_ExPostPhysicalHydroRepresentation

  - `SAME_AS_CLEARING`: Same as clearing (0)
  - `FUTURE_COST_FUNCTION`: Future cost function (1)
"""
@enumx Configurations_ExPostPhysicalHydroRepresentation begin
    SAME_AS_CLEARING = 0
    FUTURE_COST_FUNCTION = 1
end

"""
    Configurations_ClearingIntegerVariables

  - `FIX`: Fix (0)
  - `LINEARIZE`: Linearize (1)
"""
@enumx Configurations_ClearingIntegerVariables begin
    FIX = 0
    LINEARIZE = 1
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
    Reserve_ConstraintType

  - `EQUALITY`: Equality constraint (0)
  - `INEQUALITY`: Inequality constraint (1)
"""
@enumx Reserve_ConstraintType begin
    EQUALITY = 0
    INEQUALITY = 1
end

"""
    Reserve_Direction

  - `UP`: Upward direction (0)
  - `DOWN`: Downward direction (1)
"""
@enumx Reserve_Direction begin
    UP = 0
    DOWN = 1
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
    RunTime_ClearingModelType

  - `EX_ANTE_PHYSICAL`: Ex-Ante physical (0)
  - `EX_ANTE_COMMERCIAL`: Ex-Ante commercial (1)
  - `EX_POST_PHYSICAL`: Ex-Post physical (2)
  - `EX_POST_COMMERCIAL`: Ex-Post commercial (3)
"""
@enumx RunTime_ClearingModelType begin
    EX_ANTE_PHYSICAL = 0
    EX_ANTE_COMMERCIAL = 1
    EX_POST_PHYSICAL = 2
    EX_POST_COMMERCIAL = 3
end

export Configurations_PolicyGraphType, Configurations_InflowSource, Configurations_RunMode, Configurations_StageType,
    Configurations_BlockAggregationType, Reserve_ConstraintType, Reserve_Direction, HydroPlant_InitialVolumeType,
    Demand_DemandType, Branch_LineModel, AssetOwner_PriceType, Outputs_PlotScenarios, HydroPlant_OperationType,
    BiddingGroup_BidType, Configurations_ClearingHydroRepresentation, Configurations_ExPostPhysicalHydroRepresentation,
    Configurations_ClearingIntegerVariables, Configurations_ClearingNetworkRepresentation,
    Configurations_SettlementType, Configurations_MakeWholePayments, Configurations_PriceCap, RunTime_ClearingModelType,
    Configurations_ClearingBidSource
