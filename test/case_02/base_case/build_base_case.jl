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
number_of_blocks = 5
block_duration_in_hours = 1.0

# Conversion constants
# --------------------
m3_per_second_to_hm3 = (3600 / 1e6) * block_duration_in_hours
MW_to_GWh = block_duration_in_hours * 1e-3

# Create the database
# -------------------
db = create_study!(PATH;
    number_of_stages = number_of_stages,
    number_of_scenarios = number_of_scenarios,
    number_of_blocks = number_of_blocks,
    initial_date_time = "2020-01-01T00:00:00",
    block_duration_in_hours = [block_duration_in_hours for _ in 1:number_of_blocks],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    use_binary_variables = 1,
    yearly_discount_rate = 0.0,
    yearly_duration_in_hours = 8760.0,
    demand_deficit_cost = 0.5,
)

# Add collection elements
# -----------------------
add_zone!(db; label = "zone_1")
add_bus!(db; label = "bus_1", zone_id = "zone_1")

add_thermal_plant!(db;
    label = "max_uptime_plant",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        startup_cost = [0.0],
        min_generation = [0.0],
        max_generation = [5.0],
        om_cost = [1.0] / 1e3,
    ),
    has_commitment = 1,
    max_uptime = 3.0,
    uptime_initial_condition = 2.0,
    bus_id = "bus_1",
)

add_thermal_plant!(db;
    label = "min_downtime_plant",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        startup_cost = [0.0],
        min_generation = [0.0],
        max_generation = [5.0],
        om_cost = [1.0] / 1e3,
    ),
    has_commitment = 1,
    min_downtime = 3.0,
    downtime_initial_condition = 1.0,
    bus_id = "bus_1",
)

add_thermal_plant!(db;
    label = "unconstrained_plant",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        startup_cost = [0.0],
        min_generation = [0.0],
        max_generation = [15.0],
        om_cost = [3.0] / 1e3,
    ),
    has_commitment = 0,
    bus_id = "bus_1",
)

add_thermal_plant!(db;
    label = "min_uptime_plant",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        startup_cost = [0.0],
        min_generation = [3.0],
        max_generation = [5.0],
        om_cost = [4.0] / 1e3,
    ),
    has_commitment = 1,
    min_uptime = 2.0,
    commitment_initial_condition = 1,
    uptime_initial_condition = 1.0,
    bus_id = "bus_1",
)

add_demand!(db;
    label = "dem_1",
    demand_type = IARA.Demand_DemandType.INELASTIC,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    max_shift_up = 0.0,
    max_shift_down = 0.0,
    curtailment_cost = 0.0,
    max_curtailment = 0.0,
    bus_id = "bus_1",
)

# Create and link CSV files
# -------------------------

demand = zeros(1, number_of_blocks, number_of_scenarios, number_of_stages) .+ 15 * MW_to_GWh
write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["stage", "scenario", "block"],
    labels = ["dem_1"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

link_time_series_to_file(
    db,
    "Demand";
    demand = "demand",
)

close_study!(db)
