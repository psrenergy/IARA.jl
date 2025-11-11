#  Copyright (c) 2025: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

using Dates
using DataFrames
using CSV

# Case dimensions
# ---------------
number_of_periods = 50
number_of_seasons = 4
number_of_scenarios = 20
number_of_subscenarios = 5
number_of_subperiods = 24
season_number_of_repeats = 5.0
subperiod_duration_in_hours = 8760.0 / number_of_seasons / season_number_of_repeats / number_of_subperiods
cycle_discount_rate = 0.10
reference_curve_number_of_segments = 10
demand_deficit_cost = 8327.76
train_mincost_iteration_limit = 125
train_mincost_time_limit_sec = 10000 # ~ 2.5h
initial_date_time = "2024-01-01"

db = IARA.create_study!(PATH;
    number_of_periods,
    number_of_scenarios,
    number_of_subperiods,
    number_of_subscenarios,
    number_of_nodes = number_of_seasons,
    subperiod_duration_in_hours = fill(subperiod_duration_in_hours, number_of_subperiods),
    initial_date_time,
    policy_graph_type = IARA.Configurations_PolicyGraphType.CYCLIC_WITH_SEASON_ROOT,
    cycle_discount_rate,
    expected_number_of_repeats_per_node = fill(season_number_of_repeats, number_of_seasons),
    cycle_duration_in_hours = season_number_of_repeats * number_of_seasons * sum(subperiod_duration_in_hours),
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.SKIP,
    time_series_step = IARA.Configurations_TimeSeriesStep.FROZEN_TIME,
    bid_processing = IARA.Configurations_BidProcessing.PARAMETERIZED_HEURISTIC_BIDS,
    reference_curve_number_of_segments,
    demand_deficit_cost,
    settlement_type = IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
    train_mincost_iteration_limit,
    train_mincost_time_limit_sec,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    inflow_model = IARA.Configurations_InflowModel.READ_INFLOW_FROM_FILE,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
    virtual_reservoir_residual_revenue_split_type = IARA.Configurations_VirtualReservoirResidualRevenueSplitType.BY_ENERGY_ACCOUNT_SHARES,
);

try
    # Zones
    IARA.add_zone!(db; label = "S-SE")
    IARA.add_zone!(db; label = "N-NE")

    # Buses
    IARA.add_bus!(db; label = "Southeast_1", zone_id = "S-SE")
    IARA.add_bus!(db; label = "South_1", zone_id = "S-SE")
    IARA.add_bus!(db; label = "Northeast_1", zone_id = "N-NE")
    IARA.add_bus!(db; label = "North_1", zone_id = "N-NE")
    IARA.add_bus!(db; label = "Imperatriz_1", zone_id = "N-NE")

    # DCLines
    df_dcline = CSV.read(joinpath(PATH, "dclines.csv"), DataFrame)
    for row in eachrow(df_dcline)
        IARA.add_dc_line!(db;
            label = String(row.label),
            bus_from = String(row.bus_from),
            bus_to = String(row.bus_to),
            parameters = DataFrame(;
                date_time = [DateTime(0)],
                existing = [Int(IARA.DCLine_Existence.EXISTS)],
                capacity_to = [row.capacity_to],
                capacity_from = [row.capacity_from],
            ),
        )
    end

    # Asset owners
    IARA.add_asset_owner!(db;
        label = "Agent_1",
        price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
        purchase_discount_rate = [0.05],
    )
    IARA.add_asset_owner!(db;
        label = "Agent_2",
        price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
        purchase_discount_rate = [0.05],
    )
    IARA.add_asset_owner!(db;
        label = "Agent_3",
        price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
        purchase_discount_rate = [0.05],
    )
    IARA.add_asset_owner!(db;
        label = "Agent_4",
        price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
        purchase_discount_rate = [0.05],
    )
    IARA.add_asset_owner!(db;
        label = "Agent_5",
        price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
        purchase_discount_rate = [0.05],
    )
    IARA.add_asset_owner!(db;
        label = "Agent_6",
        price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
        purchase_discount_rate = [0.05],
    )
    IARA.add_asset_owner!(db;
        label = "Agent_7",
        price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
        purchase_discount_rate = [0.05],
    )
    IARA.add_asset_owner!(db;
        label = "Agent_8",
        price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
        purchase_discount_rate = [0.05],
    )

    # Bidding groups
    IARA.add_bidding_group!(db;
        label = "Agent_2_Other",
        assetowner_id = "Agent_2",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_3_Other",
        assetowner_id = "Agent_3",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_4_Other",
        assetowner_id = "Agent_4",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_6_Other",
        assetowner_id = "Agent_6",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_7_Other",
        assetowner_id = "Agent_7",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_8_Other",
        assetowner_id = "Agent_8",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_1_Thermal",
        assetowner_id = "Agent_1",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_3_Thermal",
        assetowner_id = "Agent_3",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_4_Thermal",
        assetowner_id = "Agent_4",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_5_Thermal",
        assetowner_id = "Agent_5",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_1_HydroMRE",
        assetowner_id = "Agent_1",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_2_HydroMRE",
        assetowner_id = "Agent_2",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_3_HydroMRE",
        assetowner_id = "Agent_3",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_4_HydroMRE",
        assetowner_id = "Agent_4",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_5_HydroMRE",
        assetowner_id = "Agent_5",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_bidding_group!(db;
        label = "Agent_6_HydroMRE",
        assetowner_id = "Agent_6",
        segment_fraction = [1.0],
        risk_factor = [0.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )

    # demands
    df_demands = CSV.read(joinpath(PATH, "demands.csv"), DataFrame)
    for row in eachrow(df_demands)
        IARA.add_demand_unit!(db;
            label = String(row.label),
            bus_id = String(row.bus_id),
            max_demand = row.max_capacity_pu,
            curtailment_cost_flexible_demand = row.cost,
            parameters = DataFrame(;
                date_time = [DateTime(0)],
                existing = [Int(IARA.DemandUnit_Existence.EXISTS)],
            ),
        )
    end

    # Thermals
    df_thermals = CSV.read(joinpath(PATH, "thermals.csv"), DataFrame)
    for row in eachrow(df_thermals)
        IARA.add_thermal_unit!(db;
            label = String(row.label),
            bus_id = String(row.bus_id),
            biddinggroup_id = String(row.biddinggroup_id),
            has_commitment = 0,
            generation_initial_condition = 0.0,
            max_ramp_up = row.ramp_up,
            max_ramp_down = row.ramp_down,
            parameters = DataFrame(;
                date_time = [DateTime(0)],
                existing = [Int(IARA.ThermalUnit_Existence.EXISTS)],
                om_cost = [row.om_cost],
                max_generation = [row.capacity],
            ),
        )
    end

    # Renewables
    df_renewables = CSV.read(joinpath(PATH, "renewables.csv"), DataFrame)
    for row in eachrow(df_renewables)
        IARA.add_renewable_unit!(db;
            label = String(row.label),
            bus_id = String(row.bus_id),
            biddinggroup_id = String(row.biddinggroup_id),
            parameters = DataFrame(;
                date_time = [DateTime(0)],
                existing = [Int(IARA.RenewableUnit_Existence.EXISTS)],
                max_generation = [row.capacity],
                om_cost = [row.cost],
                curtailment_cost = [0.5],
            ),
        )
    end

    # Hydros
    df_hydros = CSV.read(joinpath(PATH, "hydros.csv"), DataFrame)
    for row in eachrow(df_hydros)
        IARA.add_gauging_station!(db;
            label = String(row.label),
            inflow_initial_state_variation_type = IARA.GaugingStation_InflowInitialStateVariationType.BY_SCENARIO,
        )
        parameters = DataFrame(;
            date_time = [DateTime(0)],
            existing = Int(IARA.HydroUnit_Existence.EXISTS),
            max_generation = row.capacity,
            om_cost = row.cost,
            min_outflow = row.min_outflow,
            production_factor = row.production_factor,
            min_volume = row.min_volume_hm3,
            max_volume = row.max_volume_hm3,
        )
        op_type = if row.min_volume_hm3 == row.max_volume_hm3
            IARA.HydroUnit_IntraPeriodOperation.CYCLIC_WITH_FLEXIBLE_START
        else
            IARA.HydroUnit_IntraPeriodOperation.STATE_VARIABLE
        end
        IARA.add_hydro_unit!(db;
            label = String(row.label),
            bus_id = String(row.bus_id),
            biddinggroup_id = String(row.biddinggroup_id),
            gaugingstation_id = String(row.label),
            initial_volume_variation_type = IARA.HydroUnit_InitialVolumeVariationType.BY_SCENARIO,
            initial_volume_type = IARA.HydroUnit_InitialVolumeDataType.ABSOLUTE_VOLUME_IN_HM3,
            minimum_outflow_violation_cost = Float64(row.minimum_outflow_violation_cost),
            intra_period_operation = op_type,
            parameters,
        )
    end

    for row in eachrow(df_hydros)
        if !ismissing(row.spill_to)
            IARA.set_hydro_spill_to!(db, String(row.label), String(row.spill_to))
        end
        if !ismissing(row.turbine_to)
            IARA.set_hydro_turbine_to!(db, String(row.label), String(row.turbine_to))
        end
    end

    # Virtual reservoirs
    df_virtual_reservoirs = CSV.read(joinpath(PATH, "virtual_reservoirs.csv"), DataFrame)
    vr_labels = unique(df_virtual_reservoirs.label)
    for label in vr_labels
        hydro_labels = df_hydros.label[findall(isequal(label), df_hydros.virtual_reservoir_id)]
        owner_labels = df_virtual_reservoirs.assetowner_id[findall(isequal(label), df_virtual_reservoirs.label)]
        inflow_share = df_virtual_reservoirs.inflow_share[findall(isequal(label), df_virtual_reservoirs.label)]
        start_vol_share = df_virtual_reservoirs.start_vol_share[findall(isequal(label), df_virtual_reservoirs.label)]

        IARA.add_virtual_reservoir!(db;
            label = String(label),
            assetowner_id = String.(owner_labels),
            hydrounit_id = String.(hydro_labels),
            inflow_allocation = inflow_share,
            initial_energy_account_share = start_vol_share,
        )
    end

    # Link time series
    IARA.link_time_series_to_file(
        db,
        "RenewableUnit";
        generation_ex_post = "r_ex_post",
    )

    IARA.link_time_series_to_file(
        db,
        "DemandUnit";
        demand_ex_post = "d_ex_post",
        elastic_demand_price = "demand_price",
    )

    IARA.link_time_series_to_file(
        db,
        "HydroUnit";
        inflow_ex_ante = "inflow_ex_ante",
    )

    IARA.link_time_series_to_file(
        db,
        "Configuration";
        fcf_cuts = "cuts.json",
    )

    IARA.link_time_series_to_file(
        db,
        "HydroUnit";
        initial_volume_by_scenario = "initial_volume_by_scenario",
    )

finally
    IARA.close_study!(db)
end
