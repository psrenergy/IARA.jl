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

# The generation time series is in p.u., so each unit's factor is scaled by its
# installed capacity to get MW
installed_capacity = zeros(number_of_renewable_units)
installed_capacity[wind_indexes] .= wind_max_generation
installed_capacity[solar_indexes] .= solar_max_generation

max_demand = 400.0
low_demand = 200.0
medium_demand = 300.0
high_demand = 400.0

# Correlation patterns between wind, solar and demand
# ---------------------------------------------------
# Each period pairs the six subscenarios differently, so that the case covers a
# range of correlation structures. Every series always takes each level (low,
# medium, high) exactly twice; only the pairing between them changes.
#
# Periods 1 and 2 keep the original pattern of the case, and periods 3 to 6 use
# pseudo-random pairings, chosen so that no two series are strongly correlated
# and no obvious rule relates them. The combination of high demand with both low
# solar and low wind is not allowed, and none of the patterns below contains it.
const LOW = 1
const MEDIUM = 2
const HIGH = 3

renewable_levels = [low_values, medium_values, high_values]
demand_levels = [low_demand, medium_demand, high_demand]

# Each entry is (wind, solar, demand) levels over the six subscenarios
correlation_patterns = [
    # Original pattern of the case
    (
        [LOW, LOW, MEDIUM, MEDIUM, HIGH, HIGH],
        [MEDIUM, HIGH, LOW, HIGH, LOW, MEDIUM],
        [MEDIUM, LOW, HIGH, MEDIUM, HIGH, LOW],
    ),
    (
        [HIGH, MEDIUM, HIGH, LOW, LOW, MEDIUM],
        [LOW, HIGH, MEDIUM, HIGH, MEDIUM, LOW],
        [MEDIUM, LOW, HIGH, MEDIUM, HIGH, LOW],
    ),
    (
        [HIGH, MEDIUM, HIGH, LOW, LOW, MEDIUM],
        [LOW, HIGH, MEDIUM, LOW, MEDIUM, HIGH],
        [MEDIUM, LOW, HIGH, MEDIUM, HIGH, LOW],
    ),
    (
        [HIGH, LOW, HIGH, LOW, MEDIUM, MEDIUM],
        [HIGH, MEDIUM, MEDIUM, LOW, HIGH, LOW],
        [MEDIUM, LOW, HIGH, MEDIUM, HIGH, LOW],
    ),
    (
        [HIGH, HIGH, MEDIUM, LOW, MEDIUM, LOW],
        [LOW, MEDIUM, HIGH, HIGH, MEDIUM, LOW],
        [MEDIUM, LOW, HIGH, MEDIUM, HIGH, LOW],
    ),
]

# Periods 1 and 2 share the original pattern; the remaining periods take one each
period_to_pattern = [1, 1, 2, 3, 4, 5]

wind_scenarios = zeros(number_of_subscenarios, number_of_periods)
solar_scenarios = zeros(number_of_subscenarios, number_of_periods)
demand_ex_post = zeros(number_of_subscenarios, number_of_periods)

for period in 1:number_of_periods
    wind_levels, solar_levels, demand_pattern = correlation_patterns[period_to_pattern[period]]

    period_wind = renewable_levels[wind_levels]
    period_solar = renewable_levels[solar_levels]
    period_demand = demand_levels[demand_pattern]

    # Sort the subscenarios by increasing net demand, so that every period is
    # written in the same, monotonic order. This only permutes the subscenario
    # slots, so the correlation defined by the pattern is preserved. The ex-ante
    # renewable generation is an average over subscenarios, hence constant, so
    # it does not affect the ordering
    renewable_generation_per_subscenario =
        period_wind * sum(installed_capacity[wind_indexes]) +
        period_solar * sum(installed_capacity[solar_indexes])
    subscenario_order = sortperm(period_demand .- renewable_generation_per_subscenario)

    wind_scenarios[:, period] = period_wind[subscenario_order]
    solar_scenarios[:, period] = period_solar[subscenario_order]
    demand_ex_post[:, period] = period_demand[subscenario_order]
end

for period in 1:number_of_periods, subscenario in 1:number_of_subscenarios
    renewable_generation_ex_post[wind_indexes, :, subscenario, :, period] .=
        wind_scenarios[subscenario, period]
    renewable_generation_ex_post[solar_indexes, :, subscenario, :, period] .=
        solar_scenarios[subscenario, period]
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
for period in 1:number_of_periods, subscenario in 1:number_of_subscenarios
    demand_factor_ex_post[:, :, subscenario, :, period] .=
        demand_ex_post[subscenario, period] / max_demand
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

# Correlation table
# -----------------
# For each period and subscenario, show the level taken by each series along
# with the resulting renewable generation and net demand
level_name(value, levels) = ["low", "medium", "high"][findfirst(==(value), levels)]

wind_capacity = sum(installed_capacity[wind_indexes])
solar_capacity = sum(installed_capacity[solar_indexes])

println("Correlation between wind, solar and demand per period:")
println(
    rpad("Period", 8),
    rpad("Subscen.", 10),
    rpad("Wind", 9),
    rpad("Solar", 9),
    rpad("Demand", 9),
    lpad("Renew. (MW)", 13),
    lpad("Net dem. (MW)", 15),
)
for period in 1:number_of_periods
    # The ex-ante generation is the average over the subscenarios of the period
    renewable_generation_ex_ante =
        sum(
            wind_scenarios[subscenario, period] * wind_capacity +
            solar_scenarios[subscenario, period] * solar_capacity for
            subscenario in 1:number_of_subscenarios
        ) / number_of_subscenarios

    for subscenario in 1:number_of_subscenarios
        renewable_generation =
            wind_scenarios[subscenario, period] * wind_capacity +
            solar_scenarios[subscenario, period] * solar_capacity
        net_demand =
            demand_ex_post[subscenario, period] + renewable_generation_ex_ante -
            renewable_generation

        println(
            rpad(period, 8),
            rpad(subscenario, 10),
            rpad(level_name(wind_scenarios[subscenario, period], renewable_levels), 9),
            rpad(level_name(solar_scenarios[subscenario, period], renewable_levels), 9),
            rpad(level_name(demand_ex_post[subscenario, period], demand_levels), 9),
            lpad(renewable_generation, 13),
            lpad(net_demand, 15),
        )
    end
    println("    Ex-ante renewable generation: $renewable_generation_ex_ante MW")
end

IARA.close_study!(db)
