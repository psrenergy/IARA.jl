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

# Case dimensions
# ---------------
number_of_stages = 3
number_of_scenarios = 4
number_of_blocks = 2
block_duration_in_hours = 1.0

# Conversion constants
# --------------------
m3_per_second_to_hm3 = (3600 / 1e6) * block_duration_in_hours
MW_to_GWh = block_duration_in_hours * 1e-3

# Create the database
# -------------------
db = nothing
GC.gc()
GC.gc()

db = IARA.create_study!(PATH;
    number_of_stages = number_of_stages,
    number_of_scenarios = number_of_scenarios,
    number_of_blocks = number_of_blocks,
    initial_date_time = "2020-01-01T00:00:00",
    block_duration_in_hours = [block_duration_in_hours for _ in 1:number_of_blocks],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    yearly_discount_rate = 0.0,
    yearly_duration_in_hours = 8760.0,
    demand_deficit_cost = 500.0,
    hydro_spillage_cost = 1.0,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")
IARA.add_bus!(db; label = "bus_2", zone_id = "zone_1")

IARA.add_renewable_plant!(db;
    label = "gnd_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [4.0],
        om_cost = [0.0],
        curtailment_cost = [0.1],
    ),
    technology_type = 1,
    bus_id = "bus_2",
)

IARA.add_hydro_plant!(db;
    label = "hyd_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.HydroPlant_Existence.EXISTS)],
        production_factor = [1.0],
        min_generation = [0.0],
        max_generation = [3.5],
        max_turbining = [3.5],
        min_volume = [0.0],
        max_volume = [30.0 * m3_per_second_to_hm3],
        min_outflow = [0.0],
        om_cost = [0.0],
    ),
    initial_volume = 12.0 * m3_per_second_to_hm3,
    bus_id = "bus_2",
)

IARA.add_thermal_plant!(db;
    label = "ter_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalPlant_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 5.0,
        om_cost = 1.0,
    ),
    has_commitment = 0,
    bus_id = "bus_1",
)

IARA.add_dc_line!(db;
    label = "dc_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DCLine_Existence.EXISTS)],
        capacity_to = [5.5],
        capacity_from = [5.5],
    ),
    bus_from = "bus_1",
    bus_to = "bus_2",
)

IARA.add_demand!(db;
    label = "dem_1",
    demand_type = IARA.Demand_DemandType.INELASTIC,
    max_shift_up = 0.0,
    max_shift_down = 0.0,
    curtailment_cost = 0.0,
    max_curtailment = 0.0,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.Demand_Existence.EXISTS),
    ),
    bus_id = "bus_1",
)

# Create and link CSV files
# -------------------------

renewable_generation = zeros(1, number_of_blocks, number_of_scenarios, number_of_stages)
for scen in 1:number_of_scenarios
    renewable_generation[:, :, scen, :] .+= (5 - scen) / 4
end
IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation"),
    renewable_generation;
    dimensions = ["stage", "scenario", "block"],
    labels = ["gnd_1"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

inflow = zeros(1, number_of_blocks, number_of_scenarios, number_of_stages)
for scen in 1:number_of_scenarios
    inflow[:, :, scen, :] .+= (scen - 1) / 2
end
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    inflow;
    dimensions = ["stage", "scenario", "block"],
    labels = ["hyd_1_gauging_station"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

demand = zeros(1, number_of_blocks, number_of_scenarios, number_of_stages) .+ 10 * MW_to_GWh
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["stage", "scenario", "block"],
    labels = ["dem_1"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

IARA.link_time_series_to_file(
    db,
    "RenewablePlant";
    generation = "renewable_generation",
)

IARA.link_time_series_to_file(
    db,
    "HydroPlant";
    inflow = "inflow",
)

IARA.link_time_series_to_file(
    db,
    "Demand";
    demand = "demand",
)

IARA.close_study!(db)
