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

number_of_solar_units = 2
number_of_elastic_demand_units = 2
solar_max_generation = 50.0

# With half of the thermal capacity removed, the system has 310 MW of thermal
# capacity plus up to 80 MW of solar, so the base case demand of 400 MW would
# always run into deficit. The inelastic demand is resized so that it can always
# be met, leaving the elastic demand to compete for the remaining capacity
inelastic_max_demand = 250.0
elastic_max_demand = 50.0
elastic_demand_price = 140.0

# Demand and solar take two levels each, combined into four subscenarios. Both
# demands are perfectly correlated, while solar is uncorrelated with them. The
# subscenarios are ordered by increasing net demand (demand minus solar)
demand_factor = [0.5, 0.5, 1.0, 1.0]
solar_factor = [0.8, 0.2, 0.8, 0.2]

# The base case supplies only ex-post demand scenarios; do the same for the
# renewable generation scenarios added below
IARA.update_configuration!(
    db;
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
    number_of_subscenarios = length(demand_factor),
    bid_price_limit_low_reference = 100.0,
)
number_of_subscenarios = length(demand_factor)

# Remove the third and fourth agent of each thermal type, along with their assets
# ------------------------------------------------------------------------------
for i in 3:4
    IARA.delete_element!(db, "ThermalUnit", "Termica $i")
    IARA.delete_element!(db, "BiddingGroup", "Termico $i")
    IARA.delete_asset_owner!(db, "Agente Termico $i")

    IARA.delete_element!(db, "ThermalUnit", "Peaker $i")
    IARA.delete_element!(db, "BiddingGroup", "Peaker $i")
    IARA.delete_asset_owner!(db, "Agente Peaker $i")
end

# Add two identical solar agents, with a bidding group and a renewable unit each
# -----------------------------------------------------------------------------
for i in 1:number_of_solar_units
    IARA.add_asset_owner!(db; label = "Agente Solar $i", purchase_discount_rate = [0.1])
    IARA.add_bidding_group!(
        db;
        label = "Solar $i",
        assetowner_id = "Agente Solar $i",
        risk_factor = [0.0],
        segment_fraction = [1.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_renewable_unit!(
        db;
        label = "Solar $i",
        parameters = DataFrame(;
            date_time = [DateTime(0)],
            existing = [Int(IARA.RenewableUnit_Existence.EXISTS)],
            max_generation = [solar_max_generation],
            om_cost = [3.0],
            curtailment_cost = [0.0],
        ),
        biddinggroup_id = "Solar $i",
        bus_id = "Sistema",
    )
end

# Add two identical elastic demand agents, with a bidding group and an elastic
# demand unit each
# ----------------------------------------------------------------------------
for i in 1:number_of_elastic_demand_units
    IARA.add_asset_owner!(db; label = "Agente Demanda Elastica $i", purchase_discount_rate = [0.1])
    IARA.add_bidding_group!(
        db;
        label = "Demanda Elastica $i",
        assetowner_id = "Agente Demanda Elastica $i",
        risk_factor = [0.0],
        segment_fraction = [1.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_GENERATION,
    )
    IARA.add_demand_unit!(
        db;
        label = "Demanda Elastica $i",
        demand_unit_type = IARA.DemandUnit_DemandType.ELASTIC,
        max_demand = elastic_max_demand,
        parameters = DataFrame(;
            date_time = [DateTime(0)],
            existing = [Int(IARA.DemandUnit_Existence.EXISTS)],
        ),
        bus_id = "Sistema",
        biddinggroup_id = "Demanda Elastica $i",
    )
end

IARA.update_demand_unit!(db, "Demanda"; max_demand = inelastic_max_demand)

# The bidding group labels changed, so the bid files written by the base case
# must be rewritten for the new set of bidding groups
# --------------------------------------------------------------------------
bidding_group_labels = [
    "Termico 1",
    "Termico 2",
    "Peaker 1",
    "Peaker 2",
    "Solar 1",
    "Solar 2",
    "Demanda Elastica 1",
    "Demanda Elastica 2",
]

bg_quantity_bid = zeros(
    length(bidding_group_labels),
    number_of_buses,
    number_of_bg_segments,
    number_of_subperiods,
    number_of_scenarios,
    number_of_periods,
)

IARA.write_bids_time_series_file(
    joinpath(PATH, "bidding_group_energy_bid"),
    bg_quantity_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = bidding_group_labels,
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        number_of_bg_segments,
    ],
    initial_date = "2025-01-01",
    unit = "MWh",
)

bg_price_bid = zeros(
    length(bidding_group_labels),
    number_of_buses,
    number_of_bg_segments,
    number_of_subperiods,
    number_of_scenarios,
    number_of_periods,
)

IARA.write_bids_time_series_file(
    joinpath(PATH, "bidding_group_price_bid"),
    bg_price_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = bidding_group_labels,
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        number_of_bg_segments,
    ],
    initial_date = "2025-01-01",
    unit = "\$/MWh",
)

justifications = []
for period in 1:number_of_periods
    period_justification = Dict(
        "period" => period,
        "justifications" => Dict(label => "foo bar baz" for label in bidding_group_labels),
    )
    push!(justifications, period_justification)
end

open(joinpath(PATH, "bid_justifications.json"), "w") do file
    return write(file, IARA.JSON.json(justifications))
end

# Solar generation time series
# ----------------------------
renewable_generation_ex_post = zeros(
    number_of_solar_units,
    number_of_subperiods,
    number_of_subscenarios,
    number_of_scenarios,
    number_of_periods,
)
for subscenario in 1:number_of_subscenarios
    renewable_generation_ex_post[:, :, subscenario, :, :] .= solar_factor[subscenario]
end

IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation_ex_post"),
    renewable_generation_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["Solar $i" for i in 1:number_of_solar_units],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subscenarios,
        number_of_subperiods,
    ],
    initial_date = "2025-01-01T00:00:00",
    unit = "p.u.",
)

IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation_ex_post = "renewable_generation_ex_post",
)

# Demand time series
# ------------------
# The inelastic and elastic demands share the same factor in every subscenario
demand_unit_labels = ["Demanda"; ["Demanda Elastica $i" for i in 1:number_of_elastic_demand_units]]

demand_factor_ex_post = zeros(
    length(demand_unit_labels),
    number_of_subperiods,
    number_of_subscenarios,
    number_of_scenarios,
    number_of_periods,
)
for subscenario in 1:number_of_subscenarios
    demand_factor_ex_post[:, :, subscenario, :, :] .= demand_factor[subscenario]
end

IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_post"),
    demand_factor_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = demand_unit_labels,
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subscenarios,
        number_of_subperiods,
    ],
    initial_date = "2025-01-01T00:00:00",
    unit = "p.u.",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_post = "demand_ex_post",
)

# Elastic demand price, used by the heuristic bids and the min cost model
# ----------------------------------------------------------------------
elastic_demand_price_series =
    fill(
        elastic_demand_price,
        number_of_elastic_demand_units,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )

IARA.write_timeseries_file(
    joinpath(PATH, "elastic_demand_price"),
    elastic_demand_price_series;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["Demanda Elastica $i" for i in 1:number_of_elastic_demand_units],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2025-01-01T00:00:00",
    unit = "\$/MWh",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    elastic_demand_price = "elastic_demand_price",
)

IARA.close_study!(db)
