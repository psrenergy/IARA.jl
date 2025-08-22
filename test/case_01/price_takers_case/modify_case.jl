
#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

db = IARA.load_study(PATH; read_only = false)

IARA.update_configuration!(db;
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
    nash_equilibrium_strategy = IARA.Configurations_NashEquilibriumStrategy.STANDARD_ITERATION,
    max_iteration_nash_equilibrium = 3,
    nash_equilibrium_initialization = IARA.Configurations_NashEquilibriumInitialization.EXTERNAL_BID,
)

IARA.add_asset_owner!(db;
    label = "asset_owner_1",
    price_type = IARA.AssetOwner_PriceType.PRICE_TAKER,
)
IARA.add_asset_owner!(db;
    label = "asset_owner_2",
    price_type = IARA.AssetOwner_PriceType.PRICE_TAKER,
)

IARA.add_bidding_group!(db;
    label = "bg_1",
    assetowner_id = "asset_owner_1",
)
IARA.add_bidding_group!(db;
    label = "bg_2",
    assetowner_id = "asset_owner_2",
)

IARA.update_hydro_unit_relation!(db, "hyd_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_1",
)
IARA.update_thermal_unit_relation!(db, "ter_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_2",
)
IARA.update_renewable_unit_relation!(db, "gnd_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_1",
)

# Modify inflow series
new_inflow = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
for scenario in 1:number_of_scenarios
    new_inflow[:, :, scenario, :] .= inflow[:, :, end, :]
end
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    new_inflow;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hyd_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

# Spot price time series
spot_price = zeros(2, number_of_subperiods, number_of_scenarios, number_of_periods)
for period in 1:number_of_periods, scenario in 1:number_of_scenarios
    spot_price[:, :, scenario, period] .= (scenario + period + 0.5) / 5
end
IARA.write_timeseries_file(
    joinpath(PATH, "load_marginal_cost"),
    spot_price;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["bus_1", "bus_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "\$/MWh",
)

IARA.close_study!(db)
