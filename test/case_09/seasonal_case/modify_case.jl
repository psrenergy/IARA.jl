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

number_of_hydro_scenarios = 3
number_of_demand_scenarios = 2
number_of_renewable_scenarios = 2
number_of_scenarios = number_of_hydro_scenarios * number_of_demand_scenarios * number_of_renewable_scenarios

number_of_seasons = 2
number_of_periods = 6
number_of_subscenarios = 1
number_of_subperiods = 3

IARA.update_configuration!(db;
    number_of_scenarios = number_of_scenarios,
    number_of_subscenarios = number_of_subscenarios,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
)

aux_seasons = zeros(Int, 1, number_of_scenarios, number_of_periods)
aux_seasons[1,:,:] = 
[
    1 2 2 2 1 1;
    1 2 2 2 1 1;
    1 2 2 2 1 1;
    1 1 2 2 2 1;
    1 1 2 2 2 1;
    1 1 2 2 2 1;
    1 1 1 2 2 2;
    1 1 1 2 2 2;
    1 1 1 2 2 2;
    1 2 2 1 1 2;
    1 2 2 1 1 2;
    1 2 2 1 1 2;
]

IARA.write_timeseries_file(
    joinpath(PATH, "season_ids"),
    aux_seasons;
    dimensions = ["period", "scenario"],
    labels = ["season"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios],
    initial_date = "2020",
    unit = " ",
)

IARA.link_time_series_to_file(
    db,
    "Configuration";
    period_season_map = "season_ids",
)

###########################################
# Time series
###########################################

r_labels = ["Solar"]
d_labels = ["Demand 1", "Demand 2", "Demand 3"]
h_labels = ["Hydro Upstream", "Hydro Downstream"]

n_agents_r = size(r_labels, 1)
n_agents_d = size(d_labels, 1)
n_agents_h = size(h_labels, 1)

h = zeros(n_agents_h, number_of_subperiods, number_of_scenarios, number_of_seasons)
r = zeros(n_agents_r, number_of_subperiods, number_of_scenarios, number_of_seasons)
d = zeros(n_agents_d, number_of_subperiods, number_of_scenarios, number_of_seasons)

r_pu_multiplier = 1 / 80.0
d_pu_multiplier = 1 ./ [90.0, 40.0, 20.0]

d_summer = [60.0 60.0 75.0; 40.0 40.0 55.0]
d_winter = [45.0 90.0 90.0; 25.0 70.0 70.0]
r_summer = [5.0 80.0 5.0; 5.0 50.0 5.0]
r_winter = [0.0 60.0 0.0; 0.0 30.0 0.0]
h_summer = [140.0, 60.0, 10.0]
h_winter = [10.0, 10.0, 10.0]

fixed_demands = Dict("d2" => 32.0, "d3" => 15.0)

d[2, :, :, :] .= fixed_demands["d2"] * d_pu_multiplier[2]
d[3, :, :, :] .= fixed_demands["d3"] * d_pu_multiplier[3]

for i_d in 1:number_of_demand_scenarios
    for i_r in 1:number_of_renewable_scenarios
        for i_h in 1:number_of_hydro_scenarios
            i_scenario = number_of_hydro_scenarios * ((number_of_renewable_scenarios * (i_d - 1) + i_r) - 1) + i_h
            
            # Summer
            r[1, :, i_scenario, 1] = r_summer[i_r, :] * r_pu_multiplier
            d[1, :, i_scenario, 1] = d_summer[i_d, :] * d_pu_multiplier[1]
            h[1, :, i_scenario, 1] = [h_summer[i_h] for i in 1:number_of_subperiods]

            # Winter
            r[1, :, i_scenario, 2] = r_winter[i_r, :] * r_pu_multiplier
            d[1, :, i_scenario, 2] = d_winter[i_d, :] * d_pu_multiplier[1]
            h[1, :, i_scenario, 2] = [h_winter[i_h] for i in 1:number_of_subperiods]
        end
    end
end

IARA.write_timeseries_file(
    joinpath(PATH, "h"),
    h;
    dimensions = ["season", "scenario", "subperiod"],
    labels = h_labels,
    time_dimension = "season",
    dimension_size = [number_of_seasons, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

IARA.write_timeseries_file(
    joinpath(PATH, "r"),
    r;
    dimensions = ["season", "scenario", "subperiod"],
    labels = r_labels,
    time_dimension = "season",
    dimension_size = [number_of_seasons, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

IARA.write_timeseries_file(
    joinpath(PATH, "d"),
    d;
    dimensions = ["season", "scenario", "subperiod"],
    labels = d_labels,
    time_dimension = "season",
    dimension_size = [number_of_seasons, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation_ex_ante = "r",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "d",
)

IARA.link_time_series_to_file(
    db,
    "HydroUnit";
    inflow_ex_ante = "h",
)

IARA.close_study!(db)
