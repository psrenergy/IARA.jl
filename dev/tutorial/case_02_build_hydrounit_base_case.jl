# # Hydro Base Case - Building

# > The data for this case is available in the folder [`data/case_2`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_2)

using Dates
using DataFrames
using IARA
; #hide

# In this tutorial we will start with the [Case 1](build_base_case.md) elements and build a run of river Hydro Unit.
# This Hydro Unit will be linked to a new Bidding Group `Hydro Owner Group`, which belongs to the `Hydro Owner` owner.

# Before we start, let's recap some information about the original case.

# ## Original Case Recap

# | **Periods** | **Subperiods** | **Scenarios** | **Subperiod duration (hours)** | **Yearly discount rate** |
# |:----------:|:----------:|:-------------:|:--------------------------:|:------------------------:|
# |      2     |      1     |       4       |             24             |            10%           |

# | **Technology** | **Name** |        **Owner**        | **Maximum Generation (MW)** | **Cost (\$/MWh)** |
# |:--------------:|:--------:|:-----------------------:|:----------------------------:|:----------------:|
# |    Renewable   |  Solar1  |     Price Taker         |              80              |                  |
# |     Thermal    | Thermal1 |     Thermal Owner       |              20              |         10       |
# |     Thermal    | Thermal2 |     Price Taker         |              20              |         30       |
# |     Thermal    | Thermal3 |     Thermal Owner       |              20              |        100       |
# |     Thermal    | Thermal4 |     Price Taker         |              20              |        300       |
# |     Thermal    | Thermal5 |     Price Taker         |              50              |        1000      |
# |     Thermal    | Thermal6 |     Price Taker         |              50              |        3000      |

# Also, when defining the time series for the demand and solar generation, we had considered that the demand could be on High or Low levels, and the solar generation could be on High or Low levels as well.

# ### Changes for this tutorial

# As already mentioned, we will add a Hydro Unit to the case. This Hydro Unit will belong to a new a new Asset Owner called `Hydro Owner`.

# Moreover, we will change the number of scenarios to 12, considering that the inflow values for Hydro Unit could be on High, Medium or Low levels.

# ## Loading case

# Now let's copy the base case to a new folder and load it.

const PATH_ORIGINAL = joinpath(@__DIR__, "data", "case_1")

const PATH_HYDRO = joinpath(@__DIR__, "data", "case_2")

if !isdir(PATH_HYDRO)
    mkdir(PATH_HYDRO)
end

cp(
    joinpath(PATH_ORIGINAL, "study.iara"),
    joinpath(PATH_HYDRO, "study.iara");
    force = true,
)

db = IARA.load_study(PATH_HYDRO; read_only = false);
#hide

# ## Changing the number of scenarios

# We will change the number of scenarios to 12, using the [`IARA.update_configuration!`](@ref) function.

IARA.update_configuration!(
    db;
    number_of_scenarios = 12,
)
; #hide

# ## Financial elements

# We will add a new Asset Owner called `Hydro Owner`, using the [`IARA.add_asset_owner!`](@ref) function.

IARA.add_asset_owner!(
    db;
    label = "Hydro Owner",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)

# Now we will add a new Bidding Group called `Hydro Owner Group`, using the [`IARA.add_bidding_group!`](@ref) function.
# For this example, the Bidding Group will have a risk factor of 20%.

IARA.add_bidding_group!(
    db;
    label = "Hydro Owner",
    assetowner_id = "Hydro Owner",
    risk_factor = [0.2],
    segment_fraction = [1.0],
    independent_bid_max_segments = 1, # number of units
)

# ## Physical Elements
# ### Gauging Station

# When adding a Hydro Unit, we need to associate a Gauging Station to it.
# When creating a Hydro Unit, if no Gauging Station is provided, the package will create one automatically.

IARA.add_gauging_station!(db;
    label = "gauging_station",
)

# ### Hydro Unit

# For this example, we will add a Hydro Unit with the following characteristics

# | **Type**        | **Name**  |        **Owner**        | **Maximum Generation (MW)** |
# |:--------------:|:----------:|:-----------------------:|:----------------------------:|
# |   Run of river |  Hydro1   |     Hydro Owner        |              80              |  

#md # !!! note "Note"  
#md #     A Run of river Hydro Unit does not have a reservoir

# To add a hydro unit, we need to use the [`IARA.add_hydro_unit!`](@ref) function.

# We can feed some data about the hydro unit that varies with time, such as maximum and minimum generation. 
# For that, we need to pass a DataFrame in the `parameters` argument.

IARA.add_hydro_unit!(db;
    label = "Hydro1",
    operation_type = IARA.HydroUnit_OperationType.RUN_OF_RIVER,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1], # 1 = true
        production_factor = [1.0], # MW/m³/s
        max_generation = [100.0], # MW
        max_turbining = [100.0], # m³/s
        min_volume = [0.0], # hm³
        max_volume = [0.0], # hm³
        min_outflow = [0.0], # m³/s
        om_cost = [0.0], # $/MWh
    ),
    initial_volume = 0.0, # hm³
    gaugingstation_id = "gauging_station",
    biddinggroup_id = "Hydro Owner",
    bus_id = "Island",
)

# ## Time Series

# Since we have updated the number of scenarios, we will need different time series for the demand and solar generation.
# Just as in the [previous tutorial](case_01_build_base_case.md), we will be loading a CSV file we have created earlier.

# Our CSV files are
# - `demands.csv`: with the demand time series
# - `solar_generation.csv`: with the solar generation time series
# - `inflows.csv`: with the inflow time series

# Let's take a look at the first lines of each file, using the function [`IARA.time_series_dataframe`](@ref).

# ### Demands:

IARA.time_series_dataframe(joinpath(PATH_HYDRO, "demands.csv"))

# ### Solar generation:

IARA.time_series_dataframe(joinpath(PATH_HYDRO, "solar_generation.csv"))

# ### Inflows:

IARA.time_series_dataframe(joinpath(PATH_HYDRO, "inflow.csv"))

# ### Linking the time series

# Now need to link the time series with the function [`IARA.link_time_series_to_file`](@ref).

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand = "demands",
)

IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation = "solar_generation",
)

IARA.link_time_series_to_file(
    db,
    "HydroUnit";
    inflow = "inflow",
)

# ## Closing the database

# Now that we have added all the elements and linked the time series files, we can close the database to run the case, with the function [`IARA.close_study!`](@ref).

IARA.close_study!(db)
