# # Virtual Reservoir - Building

# > The data for this case is available in the folder [`data/case_5`](https://github.com/psrenergy/IARA.jl/tree/main/docs/src/tutorial/data/case_5)

# ## Virtual Reservoir overview

# Before getting into the details of the case, let's understand the concept of a virtual reservoir.

# A virtual reservoir is a mechanism to aggregate multiple hydro units into a single entity. 
# More than one Asset Owner can be linked into the same Virtual Reservoir

# Each Asset Owner has an inflow allocation, which is the percentage of inflow that each Asset Owner has in the Virtual Reservoir.
# This percentage is also used to compute the initial energy in the Virtual Reservoir for each Asset Owner.

# ## Case overview

# In this case, we will have two Hydro Units and two Asset Owners linked to a single Virtual Reservoir.
# The inflow allocation for the first Asset Owner is 40%, and for the second Asset Owner is 60%.

# The second Asset Owner will place higher bids than the first Asset Owner.
# So what we expect is that the first Asset Owner will be generating more energy in the beginning and, as the energy of the first Asset Owner decreases, the second Asset Owner will start generating more energy.

# Also, the hydro units will be in a cascade relationship, where the first hydro unit will be able to turbine and spill water to the second hydro unit.

# It is necessary to associate each hydro unit with a bidding group. In this case, we will use the same bidding group for both hydro units.

# ## Creating the case

# We'll start by importing the necessary packages.

using Dates
using DataFrames
using IARA
; #hide

# The case will have the following characteristics

number_of_periods = 3
number_of_scenarios = 1
number_of_subperiods = 4
subperiod_duration_in_hours = 1000.0 / number_of_subperiods
cycle_duration_in_hours =
    subperiod_duration_in_hours * number_of_subperiods * number_of_periods
; #hide

# Let's define a few conversion factors that we will use later.
m3_per_second_to_hm3_per_hour = 3600.0 / 1e6
; #hide

# As we have done in the previous tutorials, we will start by creating a new case.

const PATH_CASE = joinpath(@__DIR__, "data", "case_5")

db = IARA.create_study!(PATH_CASE;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    initial_date_time = "2020",
    subperiod_duration_in_hours = [
        subperiod_duration_in_hours for _ in 1:number_of_subperiods
    ],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    cycle_discount_rate = 0.0,
    cycle_duration_in_hours = cycle_duration_in_hours,
    demand_deficit_cost = 500.0,
    hydro_minimum_outflow_violation_cost = 600.0,
    clearing_hydro_representation = IARA.Configurations_VirtualReservoirBidProcessing.HEURISTIC_BID_FROM_WATER_VALUES,
    bid_data_source = IARA.Configurations_BiddingGroupBidProcessing.EXTERNAL_UNVALIDATED_BID,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
)
; #hide

# ## Zone and Bus

# Let's add a zone and a bus to our case. This case will have a single zone and a single bus for simplicity.

IARA.add_zone!(db; label = "zone_1")

IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")

# ## Hydro Unit

# Now we can add our hydro units that will be linked to the virtual reservoir.

IARA.add_hydro_unit!(db;
    label = "hydro_1",
    initial_volume = 100.0,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = 1,
        production_factor = 1000.0 * m3_per_second_to_hm3_per_hour,
        max_generation = 400.0,
        min_volume = 0.0,
        max_turbining = 400.0 / m3_per_second_to_hm3_per_hour, # maybe it is 0.4 instead of 400
        max_volume = 2000.0,
        min_outflow = 0.3 / m3_per_second_to_hm3_per_hour,
        om_cost = 10.0,
    ),
)

IARA.add_hydro_unit!(db;
    label = "hydro_2",
    initial_volume = 0.0,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = 1,
        production_factor = 1000.0 * m3_per_second_to_hm3_per_hour,
        max_generation = 400.0,
        max_turbining = 400.0 / m3_per_second_to_hm3_per_hour,
        min_volume = 0.0,
        max_volume = 0.0,
        min_outflow = 0.0,
        om_cost = 100.0,
    ),
)

# ### Setting Hydro Unit relations

IARA.set_hydro_turbine_to!(db, "hydro_1", "hydro_2")
IARA.set_hydro_spill_to!(db, "hydro_1", "hydro_2")

# ## Asset Owner

# Let's add two asset owners to our case. Both of them will be price makers.

IARA.add_asset_owner!(db; label = "asset_owner_1")

IARA.add_asset_owner!(db; label = "asset_owner_2")

# ## Virtual Reservoir

# Now we can add the virtual reservoir to our case. Notice that we are setting the inflow allocation and linking the asset owners and hydro units.

IARA.add_virtual_reservoir!(db;
    label = "reservoir_1",
    assetowner_id = ["asset_owner_1", "asset_owner_2"],
    inflow_allocation = [0.4, 0.6],
    hydrounit_id = ["hydro_1", "hydro_2"],
)

# ## Bidding Group

# Let's add a bidding group to our case. Both hydro units will be linked to this bidding group.

IARA.add_bidding_group!(db;
    label = "bidding_group_1",
    assetowner_id = "asset_owner_1",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)

IARA.update_hydro_unit_relation!(db,
    "hydro_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bidding_group_1",
)

IARA.update_hydro_unit_relation!(db,
    "hydro_2";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bidding_group_1",
)

# ## Demand

# This case will have a single demand, which we can add with the function [`IARA.add_demand_unit!`](@ref).

IARA.add_demand_unit!(db;
    label = "dem_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "bus_1",
    max_demand = 5.0,
)

# ## Time Series

# For this case, we have added time series files for the 
# - Demand
# - Inflow 
# - Virtual Reservoir Energy Offer
# - Virtual Reservoir Price Offer
# They are available in the folder [`data/case_5`](https://github.com/psrenergy/IARA.jl/tree/main/docs/src/tutorial/data/case_5)

# Let's take a look into each of these files before linking them.

IARA.time_series_dataframe(
    joinpath(PATH_CASE, "demand.csv"),
)

#

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "demand",
)

# To simplify our case, we are setting the inflow to zero, so we are only working with the initial volume of the first Hydro Unit.

IARA.time_series_dataframe(
    joinpath(PATH_CASE, "inflow.csv"),
)

#

IARA.link_time_series_to_file(
    db,
    "HydroUnit";
    inflow_ex_ante = "inflow",
)

#

IARA.time_series_dataframe(
    joinpath(PATH_CASE, "virtual_reservoir_energy_offer.csv"),
)

IARA.time_series_dataframe(
    joinpath(PATH_CASE, "virtual_reservoir_price_offer.csv"),
)

#

IARA.link_time_series_to_file(
    db,
    "VirtualReservoir";
    quantity_offer = "virtual_reservoir_energy_offer",
    price_offer = "virtual_reservoir_price_offer",
)

# ## Closing the study

IARA.close_study!(db)
