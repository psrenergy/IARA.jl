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

number_of_periods = 6
number_of_renewable_units = 4
number_of_subscenarios = 6
wind_max_generation = 80.0
solar_max_generation = 50.0

# The base case supplies only ex-post demand scenarios; do the same for the
# renewable generation scenarios added below
IARA.update_configuration!(
    db;
    number_of_periods = number_of_periods,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
    number_of_subscenarios = number_of_subscenarios,
    bid_price_limit_low_reference = 100.0,
)

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

# Add two wind agents and two solar agents, with a bidding group and a
# renewable unit each
# --------------------------------------------------------------------
for i in 1:2
    IARA.add_asset_owner!(db; label = "Agente Eolico $i", purchase_discount_rate = [0.1])
    IARA.add_bidding_group!(
        db;
        label = "Eolico $i",
        assetowner_id = "Agente Eolico $i",
        risk_factor = [0.0],
        segment_fraction = [1.0],
        ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
    )
    IARA.add_renewable_unit!(
        db;
        label = "Eolica $i",
        parameters = DataFrame(;
            date_time = [DateTime(0)],
            existing = [Int(IARA.RenewableUnit_Existence.EXISTS)],
            max_generation = [wind_max_generation],
            om_cost = [10.0],
            curtailment_cost = [0.0],
        ),
        biddinggroup_id = "Eolico $i",
        bus_id = "Sistema",
    )
end

for i in 1:2
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

# The bidding group labels changed, so the bid files written by the base case
# must be rewritten for the new set of bidding groups
# --------------------------------------------------------------------------
bidding_group_labels = [
    "Termico 1",
    "Termico 2",
    "Peaker 1",
    "Peaker 2",
    "Eolico 1",
    "Solar 1",
    "Eolico 2",
    "Solar 2",
]

bg_quantity_bid = fill(
    999.0,
    number_of_bidding_groups,
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

bg_price_bid = fill(
    999.0,
    number_of_bidding_groups,
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

# Renewable generation time series
# --------------------------------
renewable_generation_ex_post = zeros(
    number_of_renewable_units,
    number_of_subperiods,
    number_of_subscenarios,
    number_of_scenarios,
    number_of_periods,
)

wind_indexes = [1, 3]
solar_indexes = [2, 4]
low_values = 0.2
medium_values = 0.6
high_values = 1.0
wind_scenarios = [
    low_values,
    low_values,
    medium_values,
    medium_values,
    high_values,
    high_values,
]
solar_scenarios = [
    medium_values,
    high_values,
    low_values,
    high_values,
    low_values,
    medium_values,
]

# The generation time series is in p.u., so each unit's factor is scaled by its
# installed capacity to get MW
installed_capacity = zeros(number_of_renewable_units)
installed_capacity[wind_indexes] .= wind_max_generation
installed_capacity[solar_indexes] .= solar_max_generation

max_demand = 400.0
demand_ex_post = [300.0, 200.0, 400.0, 300.0, 400.0, 200.0]

# Sort the subscenarios by increasing net demand, so that all time series are
# written in the same, monotonic order. The ex-ante renewable generation is the
# average over subscenarios, hence constant, so it does not affect the ordering
renewable_generation_per_subscenario = [
    wind_scenarios[subscenario] * sum(installed_capacity[wind_indexes]) +
    solar_scenarios[subscenario] * sum(installed_capacity[solar_indexes])
    for subscenario in 1:number_of_subscenarios
]
subscenario_order = sortperm(demand_ex_post .- renewable_generation_per_subscenario)
wind_scenarios = wind_scenarios[subscenario_order]
solar_scenarios = solar_scenarios[subscenario_order]
demand_ex_post = demand_ex_post[subscenario_order]

for subscenario in 1:number_of_subscenarios
    renewable_generation_ex_post[wind_indexes, :, subscenario, :, :] .= wind_scenarios[subscenario]
    renewable_generation_ex_post[solar_indexes, :, subscenario, :, :] .= solar_scenarios[subscenario]
end

IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation_ex_post"),
    renewable_generation_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["Eolica 1", "Solar 1", "Eolica 2", "Solar 2"],
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
# The base case wrote the ex-post demand for 4 subscenarios, so it must be
# rewritten for the new subscenario count
demand_factor_ex_post = zeros(
    number_of_buses,
    number_of_subperiods,
    number_of_subscenarios,
    number_of_scenarios,
    number_of_periods,
)
for subscenario in 1:number_of_subscenarios
    demand_factor_ex_post[:, :, subscenario, :, :] .= demand_ex_post[subscenario] / max_demand
end

IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_post"),
    demand_factor_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["Demanda"],
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

# Total renewable generation per subscenario
# -----------------------------------------
println("Total renewable generation per subscenario:")
renewable_generation_ex_ante = 0.0
for idx in 1:4
    global renewable_generation_ex_ante +=
        sum(renewable_generation_ex_post[idx, 1, :, 1, 1] * installed_capacity[idx]) / number_of_subscenarios
end
for subscenario in 1:number_of_subscenarios
    generation_per_unit =
        renewable_generation_ex_post[:, 1, subscenario, 1, 1] .* installed_capacity
    net_demand = demand_ex_post[subscenario] + renewable_generation_ex_ante - sum(generation_per_unit)
    println("    Subscenario $subscenario:")
    println("        Renewable generation: $(sum(generation_per_unit)) MW")
    println("        Net demand: $net_demand MW")
end
println("    Ex-ante : $renewable_generation_ex_ante MW")

IARA.close_study!(db)
