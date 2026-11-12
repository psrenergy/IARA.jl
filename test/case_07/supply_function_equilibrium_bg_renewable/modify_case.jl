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

# Every unit in the other supply function equilibrium cases offers the same energy in every subperiod, so those cases
# cannot tell how the equilibrium result is split back across subperiods. This bidding group adds a renewable unit with
# no energy in subperiod 1 and the most in subperiod 4, cheaper than the flat thermal unit it is grouped with.
IARA.add_asset_owner!(db;
    label = "mixed_asset_owner",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_bidding_group!(db;
    label = "mixed_bg",
    assetowner_id = "mixed_asset_owner",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)
IARA.add_thermal_unit!(
    db;
    label = "mixed_thermal",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.04],
        om_cost = [50.0],
    ),
    biddinggroup_id = "mixed_bg",
    bus_id = "bus_1",
)
IARA.add_renewable_unit!(
    db;
    label = "mixed_renewable",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.08],
        om_cost = [1.0],
        curtailment_cost = [0.1],
    ),
    technology_type = 1,
    biddinggroup_id = "mixed_bg",
    bus_id = "bus_1",
)

renewable_generation = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
for (subperiod, generation) in enumerate([0.0, 0.5, 1.0, 1.5])
    renewable_generation[1, subperiod, :, :] .= generation
end
IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation"),
    renewable_generation;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["mixed_renewable"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020",
    unit = "p.u.",
)
IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation_ex_ante = "renewable_generation",
)

IARA.close_study!(db)
