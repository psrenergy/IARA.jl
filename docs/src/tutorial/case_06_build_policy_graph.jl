# # Policy Graphs - Building

# > The data for this case is available in the folder [`data/case_6`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_6)

# The goal is to understand the differences between linear and cyclic policy graphs by running simulations
# with different numbers of periods. For this tutorial, we will:

# - Compare linear and cyclic policy graphs.
# - Vary the number of periods (2 and 10).
# - Link the case to inflow and demand time series files that match the number of periods.
# - Analyze the results to determine how the optimal solution changes depending on the policy graph type and the number of periods.

# We'll start by importing the necessary packages.
import Pkg #hide
Pkg.activate("../../..") #hide
Pkg.instantiate() #hide
using Dates
using DataFrames
using IARA
; #hide

# We also need to define a directory to store the case.
const PATH_CASE = joinpath(@__DIR__, "data", "case_6")

# Define conversion factors and key parameters for the study.

## Define basic parameters
number_of_periods = 2
number_of_subperiods = 1
number_of_scenarios = 3
subperiod_duration_in_hours = [24.0]
expected_repeats = 5
cycle_discount_rate = 1 / (expected_repeats - 1)
; #hide

## Let's define a few conversion factors that we will use later.
MW_to_GWh = subperiod_duration_in_hours * 1e-3
m3_per_second_to_hm3_per_hour = 3600.0 / 1e6
; #hide

# Using [`IARA.create_study!`](@ref) we can create a new study. 

db = IARA.create_study!(PATH_CASE;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    subperiod_duration_in_hours = subperiod_duration_in_hours,
    number_of_nodes = number_of_periods,
    cycle_discount_rate = cycle_discount_rate,
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    demand_deficit_cost = 3000.0,
);

# ## Zone and Bus

IARA.add_zone!(db; label = "Zone1")
IARA.add_bus!(db; label = "Bus1", zone_id = "Zone1")

# ## Demand

IARA.add_demand_unit!(db;
    label = "Demand1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "Bus1",
)

# ## Physical Elements

# ### Thermal Unit

IARA.add_thermal_unit!(
    db;
    label = "Thermal1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [25.0],
        om_cost = [10.0],
    ),
    bus_id = "Bus1",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [50.0],
        om_cost = [20.0],
    ),
    bus_id = "Bus1",
)

# ### Gauging Station

IARA.add_gauging_station!(db;
    label = "gauging_station",
)

# ### Hydro Unit

IARA.add_hydro_unit!(db;
    label = "Hydro1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1], # 1 = true
        production_factor = [1.0], # MW/m³/s
        max_generation = [150.0], # MW
        max_turbining = [150.0], # m³/s
        min_volume = [0.0], # hm³
        max_volume = [100.0], # hm³
        min_outflow = [0.0], # m³/s
        om_cost = [0.0], # $/MWh
    ),
    initial_volume = 100.0 *
                     m3_per_second_to_hm3_per_hour *
                     subperiod_duration_in_hours[1],  # If it is full, it can generate for the whole year # hm³
    gaugingstation_id = "gauging_station",
    bus_id = "Bus1",
)

#  ## Time Series

# ### Loading time series files

# Using a text editor, we have created the following CSV files containing time series information about the demand and solar generation:
# - `demands.csv`
# - `inflow.csv`

# Let's take a look at the first lines of each file, using the function [`IARA.time_series_dataframe`](@ref).

# ### Demand:

IARA.time_series_dataframe(joinpath(PATH_CASE, "demands.csv"))

# ### Inflow:

IARA.time_series_dataframe(joinpath(PATH_CASE, "inflow.csv"))

# ### Linking the time series

# Now we need to link the time series with the function [`IARA.link_time_series_to_file`](@ref).

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand = "demands",
)

IARA.link_time_series_to_file(
    db,
    "HydroUnit";
    inflow = "inflow",
)
;

# ## Closing the database

# Now that we have added all the elements and linked the time series files, we can close the database to run the case, with the function [`IARA.close_study!`](@ref).

IARA.close_study!(db)
