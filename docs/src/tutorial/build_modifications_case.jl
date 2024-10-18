# # Modification Parameters

# > The data for this case is available in the folder [`data/case_7`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_7)

# ## Case overview

# In this tutorial, we will understand an important concept of the IARA package: time series modifications.

# If we take a look at the documentation for the constructor functions such as [`IARA.add_demand!`](@ref), [`IARA.add_thermal_plant!`](@ref), and [`IARA.add_hydro_plant!`](@ref), we can see that they all have a parameter called `parameters`.

# These `parameters` are inputed as `DataFrames` and need to have at least one row, which we can call the registry of the element.
# This registry is used to define the initial state of the element, and it can be modified in time by adding more rows to the `parameters` DataFrame.

# In this tutorial we will present a very simple example of how to use modifications parameters.
# We will create two Thermal Plants: `Thermal1` and `Thermal2`.

# The first will exist from the beginning of the case and will have a maximum generation of 20 MW and an O&M cost of 10 \$/MWh.
# The second will not exist at the beginning of the case, but will be ready for use on the 1st of March 2020, with an O&M cost of 5 \$/MWh and a maximum generation of 30 MW.

# We expect that the first plant will stop operating after the second plant is ready for use.

# However, we will add a modification for the first plant on the 1st of April 2020, where it will have a new O&M cost of 3 \$/MWh and a maximum generation of 20 MW.
# This will make the first plant more competitive and it will start operating again.

# We'll start by importing the necessary packages.
import Pkg #hide
Pkg.activate("../../..") #hide
Pkg.instantiate() #hide
using Dates
using DataFrames
using IARA
; #hide

# We also need to define a directory to store the case.
const PATH_MODIFICATIONS_CASE = joinpath(@__DIR__, "data", "case_7")
; #hide

number_of_stages = 4
number_of_blocks = 1
number_of_scenarios = 1
block_duration_in_hours = [24.0]
yearly_discount_rate = 0.1
; #hide

# Using [`IARA.create_study!`](@ref) we can create a new study. 
# This function will return a database reference that will store all the information about the case.

# We will set the initial date of the case to the 1st of January 2020.

db = IARA.create_study!(PATH_MODIFICATIONS_CASE;
    number_of_stages = number_of_stages,
    number_of_scenarios = number_of_scenarios,
    number_of_blocks = number_of_blocks,
    block_duration_in_hours = block_duration_in_hours,
    policy_graph_type = IARA.Configurations_PolicyGraphType.CYCLIC,
    number_of_nodes = number_of_stages,
    yearly_discount_rate = yearly_discount_rate,
    demand_deficit_cost = 3000.0,
    initial_date_time = "2020-01-01",
);

# ## Zone and Bus

IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")

# ## Demand

IARA.add_demand!(db;
    label = "dem_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "bus_1",
)

# ## Thermal Plants

IARA.add_thermal_plant!(
    db;
    label = "Thermal1",
    parameters = DataFrame(;
        date_time = [DateTime(0), DateTime("2020-04-01")],
        existing = [1, 1],
        max_generation = [20.0, 20.0],
        om_cost = [10.0, 3.0],
    ),
    bus_id = "bus_1",
)

IARA.add_thermal_plant!(
    db;
    label = "Thermal2",
    parameters = DataFrame(;
        date_time = [DateTime(0), DateTime("2020-03-01")],
        existing = [0, 1],
        max_generation = [0.0, 30.0],
        om_cost = [5.0, 5.0],
    ),
    bus_id = "bus_1",
)

# ## Time Series

# Using a text editor, we have created the following CSV files containing time series information about the demand and solar generation:
# - `demand.csv`

# You can find them in the `data/case_7` folder.

# Let's take a quick look at the demand file using [`IARA.time_series_dataframe`](@ref).

IARA.time_series_dataframe(joinpath(PATH_MODIFICATIONS_CASE, "demand.csv"))

# 

IARA.link_time_series_to_file(
    db,
    "Demand";
    demand = "demand",
)
; #hide

# ## Closing the database

# Now that we have added all the elements and linked the time series files, we can close the database to run the case with the function [`IARA.IARA.close_study!`](@ref).

IARA.close_study!(db)

# ## Running

# Before running, let's create a separate folder for execution.

PATH_MODIFICATIONS_CASE_EXECUTION = joinpath(@__DIR__, "case_7_execution")

if !isdir(PATH_MODIFICATIONS_CASE_EXECUTION)
    mkdir(PATH_MODIFICATIONS_CASE_EXECUTION)
end

cp(PATH_MODIFICATIONS_CASE, PATH_MODIFICATIONS_CASE_EXECUTION; force = true);

# Now we cab run the case with [`IARA.main`](@ref).

IARA.main([PATH_MODIFICATIONS_CASE_EXECUTION])

# ## Analyzing the results

# After running the case, the outputs are saved in the `outputs` folder inside the case folder.
# Inside this directory, you will find the raw results and some plots (inside the plots subdirectory).

# ```
# case_folder
#  ├── outputs
#  │    ├── plots
#  │    │   └── ...
#  │    └── ...
#  └── ...
# ```

# Let's take a look at the thermal generation of the plants.

# ```@raw html
# <iframe src="case_7_execution\\outputs\\plots\\thermal_generation_all.html" style="height:500px;width:100%;"></iframe>
# ```

# As we can see, the first plant stops operating after the second plant is ready for use, and starts operating again after the modification on the 1st of April 2020.
