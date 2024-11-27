# # Base Case - Building

# > The data for this case is available in the folder [`data/case_1`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_1)

# In this tutorial, we will build a simple case containing some basic elements that can help
# us understand some of the functionalities of the IARA package.

# We'll start by importing the necessary packages.

using Dates
using DataFrames
using IARA
; #hide

# We also need to define a directory to store the case.
const PATH_BASE_CASE = joinpath(@__DIR__, "data", "case_1")

# ## Fundamental elements

# ### Parameters indexed in time

# The parameters indexed in time in IARA model are defined by the number of periods and subperiods.

# A period represents a macro time period, such as a week, month, season or year.
# In each period, the model will solve an optimization problem that represents 
# the decisions that need to be made based on available information.

# A subperiod represents a sub time period of the period, such as an hour, a day, or simply a collection of hours.

# A scenario in this context are defined as openings. 
# Each period has a number of openings, and as the process evolves,
# the next period will have a number of openings that grow exponentially
# (e.g., if a period has 3 openings, the next period will have $3^2 = 9$ possibilities).
# These openings represent possible future paths or branches in the decision process.
# For example, a node could represent a dry or wet season, a high or low demand, or a high or low price scenario.

# A Policy Graph is a representation of the decision making process in the model.
# There are two types of policy graphs: linear and cyclic.

# In a linear policy graph, the periods are connected in a linear sequence,
# where the decisions made in one period affect the decisions in the next period.

# In a cyclic policy graph, the periods are connected in a cyclic sequence,
# where the decisions made in the last period affect the decisions in the first period.

# For more details, see the [SDDP.jl documentation](https://sddp.dev/stable/tutorial/first_steps/).

# For this initial case, we will define a cyclic policy graph, with two periods (nodes) that will represent the _Winter_ and _Summer_ seasons
# and an yearly discount rate of 10%.

# Additionally, each period will be consists of a single subperiod, with a duration of 24 hours.

# To illustrate the concept of this cyclic policy graph, we can think of a two-period diagram as follows:

# ```@raw html
# <img src="..\\assets\\simple_cycle_diagram.png"></img>
# ```

# In this case, we will define 4 scenarios.

# Now we can initialize our case, with the defined temporal parameters. 
# The cycle duration in hours is the duration of a subproblem, given by the sum of the subperiod duration vector, times the number of periods.

number_of_periods = 2
number_of_subperiods = 1
number_of_scenarios = 4
subperiod_duration_in_hours = [24.0]
cycle_discount_rate = 0.1
cycle_duration_in_hours = sum(subperiod_duration_in_hours) * number_of_periods
; #hide

# Using [`IARA.create_study!`](@ref) we can create a new study. 
# This function will return a database reference that will store all the information about the case.

db = IARA.create_study!(PATH_BASE_CASE;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    subperiod_duration_in_hours = subperiod_duration_in_hours,
    policy_graph_type = IARA.Configurations_PolicyGraphType.CYCLIC_WITH_FIXED_ROOT,
    number_of_nodes = number_of_periods,
    cycle_discount_rate = cycle_discount_rate,
    cycle_duration_in_hours = cycle_duration_in_hours,
    demand_deficit_cost = 3000.0,
);

# ## Spatial Units

# ### Bus

# A bus is a connection point in a power system where multiple electrical components 
# (such as generators, loads, transformers, or transmission lines) are set.
# Each bus need to be linked to a financial zone, which will be introduced in the next step.

# For this case, we will have a single bus, named "Island", to which all the elements will be connected.
# We can add a bus to the database using the functionalities [`IARA.add_bus!`](@ref).

IARA.add_bus!(db; label = "Island")

# ## Financial elements

# ### Zones

# A zone is a group of buses or a geographical area within a power system, often representing a specific region or subsystem.
# For this case, we will also define a single zone.

# We can add a zone to the database using the method [`IARA.add_zone!`](@ref).

IARA.add_zone!(db; label = "Island Zone")

# Now we can link the bus to the zone, using the function [`IARA.update_bus_relation!`](@ref).

IARA.update_bus_relation!(
    db,
    "Island";
    collection = "Zone",
    relation_type = "id",
    related_label = "Island Zone",
)
; #hide

# ### Asset Owners

# In the bidding format, we need to define the asset owners that will participate in the market. 
# These owners will be responsible for submitting bids for their assets, which will be represented by Bidding Groups.
# Each Bidding Group will be associated with a set of assets that belong to the same owner.

# For now, we will define two asset owners: _Thermal Owner_ and _Price Taker_. 
# The first will assume the role of price maker, while the second will act as a price taker.

# We can add an asset owner to the database using the functionalities [`IARA.add_asset_owner!`](@ref).

IARA.add_asset_owner!(
    db;
    label = "Thermal Owner",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_asset_owner!(
    db;
    label = "Price Taker",
    price_type = IARA.AssetOwner_PriceType.PRICE_TAKER,
)

# ### Bidding Groups

# Now we can define the Bidding Groups related to the asset owners that we have created earlier. 
# Each Asset Owner will have a single Bidding Group, which will be associated with all their assets.

# In each Bidding Group, we have to define the risk factor (mark-up) that will be applied to the cost of the assets. 
# For this example, we will define a risk factor of 50% for both Bidding Groups.

# We can add a Bidding Group to the database using the method [`IARA.add_bidding_group!`](@ref).

# In the `independent_bid_max_segments` we need to set the maximum number of segments that the Bidding Group can have. For this case, we will set it to the number of units that each owner has.

IARA.add_bidding_group!(
    db;
    label = "Thermal Owner",
    assetowner_id = "Thermal Owner",
    risk_factor = [0.5],
    segment_fraction = [1.0],
    independent_bid_max_segments = 2, # number of units
)
IARA.add_bidding_group!(
    db;
    label = "Price Taker",
    assetowner_id = "Price Taker",
    risk_factor = [0.5],
    segment_fraction = [1.0],
    independent_bid_max_segments = 5, # number of units
)

# ## Physical Elements

# ### Demand

# This case will have three demand units.
# We can add them to the database using the function [`IARA.add_demand_unit!`](@ref).
# We can enable or disable the demand unit.
# This can be changed by setting the `existing` attribute to 1 in the `parameters` time series DataFrame.

# The demand over each period, subperiod and scenario will be defined by a time series file. We will define it at the end of this tutorial.

# For this case, the demand will exist from the beginning.

IARA.add_demand_unit!(db;
    label = "Demand1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "Island",
)

IARA.add_demand_unit!(db;
    label = "Demand2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "Island",
)

IARA.add_demand_unit!(db;
    label = "Demand3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "Island",
)

# ### Generation Units

# Our case will have a mix of renewable and thermal units. In the table below, we can see some characteristics of each unit.

# | **Technology** | **Name** |        **Owner**        | **Maximum Generation (MW)** | **Cost (\$/MWh)** |
# |:--------------:|:--------:|:-----------------------:|:----------------------------:|:----------------:|
# |    Renewable   |  Solar1  |     Price Taker         |              80              |                  |
# |     Thermal    | Thermal1 |     Thermal Owner       |              20              |         10       |
# |     Thermal    | Thermal2 |     Price Taker         |              20              |         30       |
# |     Thermal    | Thermal3 |     Thermal Owner       |              20              |        100       |
# |     Thermal    | Thermal4 |     Price Taker         |              20              |        300       |
# |     Thermal    | Thermal5 |     Price Taker         |              50              |        1000      |
# |     Thermal    | Thermal6 |     Price Taker         |              50              |        3000      |

# ### Renewable Units

# We will start by adding a solar unit to the database, using [`IARA.add_renewable_unit!`](@ref).

IARA.add_renewable_unit!(
    db;
    label = "Solar1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [80.0],
        om_cost = [0.0],
        curtailment_cost = [100.0],
    ),
    biddinggroup_id = "Price Taker",
    bus_id = "Island",
)

# The generation of the solar unit requires a time series file. Like the demand, we will define it at the end of this tutorial.

# ### Thermal Units

# Now we can add the thermal units to the database, using [`IARA.add_thermal_unit!`](@ref).

IARA.add_thermal_unit!(
    db;
    label = "Thermal1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [20.0],
        om_cost = [10.0],
    ),
    biddinggroup_id = "Thermal Owner",
    bus_id = "Island",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [20.0],
        om_cost = [30.0],
    ),
    biddinggroup_id = "Price Taker",
    bus_id = "Island",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [20.0],
        om_cost = [100.0],
    ),
    biddinggroup_id = "Thermal Owner",
    bus_id = "Island",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal4",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [20.0],
        om_cost = [300.0],
    ),
    biddinggroup_id = "Price Taker",
    bus_id = "Island",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal5",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [50.0],
        om_cost = [1000.0],
    ),
    biddinggroup_id = "Price Taker",
    bus_id = "Island",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal6",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [50.0],
        om_cost = [3000.0],
    ),
    biddinggroup_id = "Price Taker",
    bus_id = "Island",
)

#  ## Time Series

#md # !!! note "Recap"  
#md #     In the beginning of this tutorial, we defined that there were 4 scenarios, 2 periods and 1 subperiod per period.

# ### Loading time series files

# Using a text editor, we have created the following CSV files containing time series information about the demand and solar generation:
# - `demands.csv`
# - `solar_generation.csv`

# You can find them in the `data/case_1` folder.

# Let's take a quick look at the demand file using [`IARA.time_series_dataframe`](@ref).

IARA.time_series_dataframe(joinpath(PATH_BASE_CASE, "demands.csv"))

# and the solar generation file

IARA.time_series_dataframe(joinpath(PATH_BASE_CASE, "solar_generation.csv"))

# Now, we have to link them to the database.

IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation = "solar_generation",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand = "demands",
)

# ## Closing the database

# Now that we have added all the elements and linked the time series files, we can close the database to run the case with the function [`IARA.close_study!`](@ref).

IARA.close_study!(db)
