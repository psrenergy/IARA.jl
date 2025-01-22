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

# Store information from the base case
number_of_scenarios_base_case = number_of_scenarios

# Group periods into seasons
months_per_period = 3

# If this is 0, the first season has months [1, 2, 3]
# If this is 1, the first season has months [2, 3, 4]
# If this is -1, the first season has months [12, 1, 2]
# And so on...
season_start_delta = 0

# Update configurations
number_of_periods = 4
number_of_scenarios *= months_per_period
subperiod_duration_in_hours = 90.0

IARA.update_configuration!(db;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
)

# =====================================================
# Modify CSV files
# =====================================================

seasonal_inflow = zeros(number_of_hydro_units, number_of_subperiods, number_of_scenarios, number_of_periods)
seasonal_demand = zeros(number_of_buses, number_of_subperiods, number_of_scenarios, number_of_periods)

for monthly_scenario in 1:number_of_scenarios_base_case
    seasonal_scenario = (monthly_scenario - 1) * months_per_period + 1
    seasonal_scenarios = seasonal_scenario:(seasonal_scenario+months_per_period-1)
    for seasonal_period in 1:number_of_periods
        monthly_period = mod1((seasonal_period - 1) * months_per_period + 1 + season_start_delta, 12)
        monthly_periods = mod1.(monthly_period:(monthly_period+months_per_period-1), 12)
        for month in 1:months_per_period
            seasonal_inflow[:, :, seasonal_scenarios[month], seasonal_period] =
                inflow[:, :, monthly_scenario, monthly_periods[month]]
            seasonal_demand[:, :, seasonal_scenarios[month], seasonal_period] =
                demand[:, :, monthly_scenario, monthly_periods[month]]
        end
    end
end

# Write to file
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    seasonal_inflow;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hyd_$(bus_labels[h])" for h in 1:number_of_hydro_units],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

# Write to file
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    seasonal_demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_$label" for label in bus_labels],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

IARA.close_study!(db)
