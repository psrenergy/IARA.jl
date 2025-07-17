#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
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

number_of_periods = 6
number_of_scenarios = 3
number_of_subscenarios = 4
number_of_subperiods = 3

db = IARA.create_study!(PATH;
    number_of_periods,
    number_of_scenarios,
    number_of_subperiods,
    number_of_subscenarios = number_of_subscenarios,
    subperiod_duration_in_hours = [8.0, 8.0, 8.0],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    cycle_discount_rate = 0.25,
    cycle_duration_in_hours = 144.0,
    demand_deficit_cost = 100000.0,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.COST_BASED,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.SKIP,
    bid_data_source = IARA.Configurations_BidDataSource.PRICETAKER_HEURISTICS,
    settlement_type = IARA.Configurations_SettlementType.EX_POST,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
);

try
    IARA.add_zone!(db; label = "Island")

    IARA.add_bus!(db; label = "Eastern", zone_id = "Island")
    IARA.add_bus!(db; label = "Western", zone_id = "Island")

    IARA.add_dc_line!(db;
        label = "East-West Link",
        parameters = DataFrame(;
            date_time = [DateTime(0)],
            existing = [Int(IARA.DCLine_Existence.EXISTS)],
            capacity_to = [100.0],
            capacity_from = [100.0],
        ),
        bus_from = "Eastern",
        bus_to = "Western",
    )

    IARA.add_asset_owner!(db; label = "Thermal Agent", price_type = IARA.AssetOwner_PriceType.PRICE_MAKER)
    IARA.add_asset_owner!(db; label = "Portfolio Agent", price_type = IARA.AssetOwner_PriceType.PRICE_MAKER)
    IARA.add_asset_owner!(db; label = "Pricetaker Agent")
    IARA.add_asset_owner!(db; label = "Selfproducer Agent")
    IARA.add_asset_owner!(db; label = "Hydro upstream Agent")
    IARA.add_asset_owner!(db; label = "Hydro downstream Agent")

    IARA.add_bidding_group!(db;
        label = "ThermalA_01",
        assetowner_id = "Thermal Agent",
        segment_fraction = [1.0],
        risk_factor = [0.0],
    )
    IARA.add_bidding_group!(db;
        label = "PortfolioA_01",
        assetowner_id = "Portfolio Agent",
        segment_fraction = [1.0],
        risk_factor = [0.0],
    )
    IARA.add_bidding_group!(db;
        label = "PortfolioA_02",
        assetowner_id = "Portfolio Agent",
        segment_fraction = [1.0],
        risk_factor = [0.0],
    )
    IARA.add_bidding_group!(db; label = "PricetakerA_01", assetowner_id = "Pricetaker Agent")
    IARA.add_bidding_group!(db; label = "SelfproducerA_01", assetowner_id = "Selfproducer Agent")
    IARA.add_bidding_group!(db; label = "UpstreamA_01", assetowner_id = "Hydro upstream Agent")
    IARA.add_bidding_group!(db; label = "DownstreamA_01", assetowner_id = "Hydro downstream Agent")

    IARA.add_renewable_unit!(db;
        label = "Solar",
        parameters = DataFrame(;
            date_time = [DateTime(0)],
            existing = [1],
            max_generation = [80.0],
            om_cost = [0.0],
            curtailment_cost = [0.0],
        ),
        bus_id = "Western",
        biddinggroup_id = "PortfolioA_02",
    )

    #Run of river for now: max_volume = 20.0 works well
    IARA.add_hydro_unit!(db;
        label = "Hydro Upstream",
        parameters = DataFrame(;
            date_time = [DateTime(0)],
            existing = [Int(IARA.HydroUnit_Existence.EXISTS)],
            production_factor = [0.125],
            max_generation = [10.0],
            max_turbining = [80.0],
            min_volume = [0.0],
            max_volume = [20.0],
            om_cost = [0.0],
        ),
        initial_volume = 0.0,
        bus_id = "Eastern",
        biddinggroup_id = "UpstreamA_01",
        intra_period_operation = IARA.HydroUnit_IntraPeriodOperation.CYCLIC_WITH_FLEXIBLE_START,
    )

    IARA.add_hydro_unit!(db;
        label = "Hydro Downstream",
        parameters = DataFrame(;
            date_time = [DateTime(0)],
            existing = [Int(IARA.HydroUnit_Existence.EXISTS)],
            production_factor = [0.875],
            max_generation = [70.0],
            max_turbining = [80.0],
            min_volume = [0.0],
            max_volume = [0.0],
            om_cost = [0.0],
        ),
        initial_volume = 0.0,
        bus_id = "Eastern",
        biddinggroup_id = "DownstreamA_01",
        intra_period_operation = IARA.HydroUnit_IntraPeriodOperation.CYCLIC_WITH_FLEXIBLE_START,
    )

    IARA.set_hydro_turbine_to!(db, "Hydro Upstream", "Hydro Downstream")
    IARA.set_hydro_spill_to!(db, "Hydro Upstream", "Hydro Downstream")

    demands = [
        Dict(
            "name" => "Demand 1",
            "bus" => "Western",
            "cap" => 90.0,
            "price" => 30000.0,
        ),
        Dict(
            "name" => "Demand 2",
            "bus" => "Western",
            "cap" => 40.0,
            "price" => 30000.0,
        ),
        Dict(
            "name" => "Demand 3",
            "bus" => "Eastern",
            "cap" => 20.0,
            "price" => 10000.0,
        ),
    ]

    thermals = [
        Dict(
            "name" => "Thermal 1",
            "bg" => "ThermalA_01",
            "bus" => "Eastern",
            "cap" => 25.0,
            "price" => 10.0,
        ),
        Dict(
            "name" => "Thermal 2",
            "bg" => "SelfproducerA_01",
            "bus" => "Eastern",
            "cap" => 25.0,
            "price" => 50.0,
        ),
        Dict(
            "name" => "Thermal 3",
            "bg" => "ThermalA_01",
            "bus" => "Eastern",
            "cap" => 25.0,
            "price" => 100.0,
        ),
        Dict(
            "name" => "Thermal 4",
            "bg" => "PortfolioA_01",
            "bus" => "Eastern",
            "cap" => 25.0,
            "price" => 200.0,
        ),
        Dict(
            "name" => "Thermal 5",
            "bg" => "PricetakerA_01",
            "bus" => "Western",
            "cap" => 50.0,
            "price" => 300.0,
        ),
        Dict(
            "name" => "Thermal 6",
            "bg" => "PricetakerA_01",
            "bus" => "Western",
            "cap" => 50.0,
            "price" => 500.0,
        ),
    ]

    for d in demands
        aux = DataFrame(;
            date_time = [DateTime(0)],
            existing = Int(IARA.DemandUnit_Existence.EXISTS),
        )

        IARA.add_demand_unit!(db;
            label = d["name"],
            parameters = aux,
            bus_id = d["bus"],
            max_demand = d["cap"],
        )
    end

    for t in thermals
        aux = DataFrame(;
            date_time = [DateTime(0)],
            existing = Int(IARA.ThermalUnit_Existence.EXISTS),
            max_generation = t["cap"],
            om_cost = t["price"],
        )

        IARA.add_thermal_unit!(db;
            label = t["name"],
            parameters = aux,
            bus_id = t["bus"],
            biddinggroup_id = t["bg"],
        )
    end

    ###########################################
    # Time series
    ###########################################

    r_labels = ["Solar"]
    d_labels = ["Demand 1", "Demand 2", "Demand 3"]
    h_labels = ["Hydro Upstream", "Hydro Downstream"]

    n_agents_r = size(r_labels, 1)
    n_agents_d = size(d_labels, 1)
    n_agents_h = size(h_labels, 1)
    n_scenarios_d = 2
    n_scenarios_r = 2

    @assert(n_scenarios_d * n_scenarios_r == number_of_subscenarios)

    ex_ante_r = zeros(n_agents_r, number_of_subperiods, 1, number_of_periods)
    ex_ante_d = zeros(n_agents_d, number_of_subperiods, 1, number_of_periods)
    ex_ante_h = zeros(n_agents_h, number_of_subperiods, number_of_scenarios, number_of_periods)

    ex_post_r = zeros(n_agents_r, number_of_subperiods, number_of_subscenarios, 1, number_of_periods)
    ex_post_d = zeros(n_agents_d, number_of_subperiods, number_of_subscenarios, 1, number_of_periods)

    r_pu_multiplier = 1 / 80.0
    h_exante_summer = [140.0, 60.0, 10.0]

    d_expost_summer = [60.0 60.0 75.0; 40.0 40.0 55.0]
    d_expost_winter = [45.0 90.0 90.0; 25.0 70.0 70.0]
    r_expost_summer = [5.0 80.0  5.0; 5.0 50.0  5.0]
    r_expost_winter = [0.0 60.0  0.0; 0.0 30.0 0.0]

    d_exante_summer = sum(d_expost_summer; dims = 1) / size(d_expost_summer, 1)
    d_exante_winter = sum(d_expost_winter; dims = 1) / size(d_expost_winter, 1)
    r_exante_summer = sum(r_expost_summer; dims = 1) / size(r_expost_summer, 1)
    r_exante_winter = sum(r_expost_winter; dims = 1) / size(r_expost_winter, 1)

    aux = Dict("h_winter" => 10.0, "d2" => 32.0, "d3" => 15.0)

    ex_ante_h[2, :, :, :] .= 0.0
    ex_ante_d[2, :, :, :] .= aux["d2"] / demands[2]["cap"]
    ex_ante_d[3, :, :, :] .= aux["d3"] / demands[3]["cap"]
    ex_post_d[2, :, :, :, :] .= aux["d2"] / demands[2]["cap"]
    ex_post_d[3, :, :, :, :] .= aux["d3"] / demands[3]["cap"]

    is_summer = [true, false, false, false, true, true]

    # ex ante scenarios
    for i_h in 1:number_of_scenarios
        for i_stage in 1:number_of_periods
            if is_summer[i_stage]
                ex_ante_r[1, :, 1, i_stage] = r_exante_summer[:] * r_pu_multiplier
                ex_ante_d[1, :, 1, i_stage] = d_exante_summer[:] / demands[1]["cap"]
                ex_ante_h[1, :, i_h, i_stage] = [h_exante_summer[i_h] for i in 1:number_of_subperiods]
            else
                ex_ante_r[1, :, 1, i_stage] = r_exante_winter[:] * r_pu_multiplier
                ex_ante_d[1, :, 1, i_stage] = d_exante_winter[:] / demands[1]["cap"]
                ex_ante_h[1, :, i_h, i_stage] = [aux["h_winter"] for i in 1:number_of_subperiods]
            end
        end
    end

    # ex post scenarios
    for i_d in 1:n_scenarios_d
        for i_r in 1:n_scenarios_r
            i_subscenario = n_scenarios_r * (i_d - 1) + i_r

            for i_s in 1:number_of_scenarios
                for i_stage in 1:number_of_periods
                    if is_summer[i_stage]
                        ex_post_r[1, :, i_subscenario, 1, i_stage] = r_expost_summer[i_r, :] * r_pu_multiplier
                        ex_post_d[1, :, i_subscenario, 1, i_stage] =
                            d_expost_summer[i_d, :] / demands[1]["cap"]
                    else
                        ex_post_r[1, :, i_subscenario, 1, i_stage] = r_expost_winter[i_r, :] * r_pu_multiplier
                        ex_post_d[1, :, i_subscenario, 1, i_stage] =
                            d_expost_winter[i_d, :] / demands[1]["cap"]
                    end
                end
            end
        end
    end

    IARA.write_timeseries_file(
        joinpath(PATH, "r_ex_ante"),
        ex_ante_r;
        dimensions = ["period", "scenario", "subperiod"],
        labels = r_labels,
        time_dimension = "period",
        dimension_size = [number_of_periods, 1, number_of_subperiods], #NOTE: renewable and demand don't vary per scenario, only per subscenario
        initial_date = "2020",
        unit = "p.u.",
    )

    IARA.write_timeseries_file(
        joinpath(PATH, "d_ex_ante"),
        ex_ante_d;
        dimensions = ["period", "scenario", "subperiod"],
        labels = d_labels,
        time_dimension = "period",
        dimension_size = [number_of_periods, 1, number_of_subperiods], #NOTE: renewable and demand don't vary per scenario, only per subscenario
        initial_date = "2020-01-01T00:00:00",
        unit = "p.u.",
    )

    IARA.write_timeseries_file(
        joinpath(PATH, "h"),
        ex_ante_h;
        dimensions = ["period", "scenario", "subperiod"],
        labels = h_labels,
        time_dimension = "period",
        dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
        initial_date = "2020-01-01T00:00:00",
        unit = "m3/s",
    )

    IARA.write_timeseries_file(
        joinpath(PATH, "r_ex_post"),
        ex_post_r;
        dimensions = ["period", "scenario", "subscenario", "subperiod"],
        labels = r_labels,
        time_dimension = "period",
        dimension_size = [number_of_periods, 1, number_of_subscenarios, number_of_subperiods], #NOTE: renewable and demand don't vary per scenario, only per subscenario
        initial_date = "2020-01-01T00:00:00",
        unit = "p.u.",
    )

    IARA.write_timeseries_file(
        joinpath(PATH, "d_ex_post"),
        ex_post_d;
        dimensions = ["period", "scenario", "subscenario", "subperiod"],
        labels = d_labels,
        time_dimension = "period",
        dimension_size = [number_of_periods, 1, number_of_subscenarios, number_of_subperiods], #NOTE: renewable and demand don't vary per scenario, only per subscenario
        initial_date = "2020-01-01T00:00:00",
        unit = "p.u.",
    )

    IARA.link_time_series_to_file(
        db,
        "RenewableUnit";
        generation_ex_ante = "r_ex_ante",
        generation_ex_post = "r_ex_post",
    )

    IARA.link_time_series_to_file(
        db,
        "DemandUnit";
        demand_ex_ante = "d_ex_ante",
        demand_ex_post = "d_ex_post",
    )

    IARA.link_time_series_to_file(
        db,
        "HydroUnit";
        inflow_ex_ante = "h",
    )

finally
    IARA.close_study!(db)
end
