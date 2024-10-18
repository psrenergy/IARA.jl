# # Multi-hour Bid - Building

# > The data for this case is available in the folder [`data/case_3`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_3)

# ## Market Clearing overview

# In the last two tutorials we have built cases with different components, including a hydro plant, and executed them in different run modes.
# In this tutorial, we will focus on one of the three run modes that we have seen earlier: `MARKET_CLEARING`.

# During `MARKET_CLEARING`, we have Asset Owners placing energy offers from their Bidding Groups.
# These bids are selected by the system to meet the demand at the lowest cost possible, considering the possible constraints that the problem might have.

# A possible configuration that a bid can have is to have a multi-hour bid, where the price for the energy is the same for all blocks in the study.
# Additionally, for multi-hour bids, the system is obligated to accept the bid for all blocks in the study.

# For this tutorial we will be building a case with two Bidding Groups, where one of them has a multi-hour bid.

# ## Case overview

# The case will have the following characteristics:

# | **Stages** | **Blocks** | **Scenarios** | **Block duration (hours)** |
# |:----------:|:----------:|:-------------:|:--------------------------:|
# |      1     |      2     |       1      |             1.0             |

# And for the bids we will set the maximum number of bidding segments and profiles to 1.

# We'll start by importing the necessary packages.
import Pkg #hide
Pkg.activate("../../..") #hide
Pkg.instantiate() #hide
using Dates
using Quiver
using DataFrames
using IARA
; #hide

# Defining some constants
number_of_stages = 1
number_of_scenarios = 1
number_of_blocks = 2
maximum_number_of_bidding_segments = 1
maximum_number_of_bidding_profiles = 1
block_duration_in_hours = 1.0
MW_to_GWh = block_duration_in_hours * 1e-3
number_of_bidding_groups = 2
; #hide

# ## Creating the case

# Just as we have done in the previous tutorials, we will start by creating a new case.

const PATH_BASE_CASE = joinpath(@__DIR__, "data", "case_3")

db = IARA.create_study!(PATH_BASE_CASE;
    number_of_stages = number_of_stages,
    number_of_scenarios = number_of_scenarios,
    number_of_blocks = number_of_blocks,
    initial_date_time = "2020-01-01T00:00:00",
    block_duration_in_hours = [
        block_duration_in_hours for _ in 1:number_of_blocks
    ],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    yearly_discount_rate = 0.0,
    yearly_duration_in_hours = 8760.0,
    demand_deficit_cost = 500.0,
    run_mode = IARA.Configurations_RunMode.MARKET_CLEARING,
)
; #hide
# ## Zone and Bus

# In this tutorial we are concerned only with highlighting the specifications of a clearing with multi-hour bids.
# Therefore, we will be simplifying it by using a single zone and a single bus. 
# We can add each of them by using the [`IARA.add_zone!`](@ref) and [`IARA.IARA.add_bus!`](@ref) functions.

IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")

#  ## Demand

# This case will have a single demand, which we can add with the function [`IARA.add_demand!`](@ref).

IARA.add_demand!(db;
    label = "dem_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "bus_1",
)

# We can now link the time series files for the demand to the database. You can find this time series file in the [`data/case_3`]() folder.
# Let's take a quick look at the file.

IARA.time_series_dataframe(joinpath(PATH_BASE_CASE, "demand.csv"))

IARA.link_time_series_to_file(
    db,
    "Demand";
    demand = "demand",
)

# ## Asset Owners and Bidding Groups

# For this case, we will be demonstrating de differences of a multi-hour bid offer and a simple bid offer.
# Thus, we will create two Bidding Groups, one for each type of bid, and link them to the same Asset Owner.

# We can add an Asset Owner with the function [`IARA.add_asset_owner!`](@ref).

IARA.add_asset_owner!(db;
    label = "asset_owner_1",
    price_type = IARA.AssetOwner_PriceType.PRICE_TAKER,
)

# Now we can define its Bidding Groups with [`IARA.add_bidding_group!`](@ref).

IARA.add_bidding_group!(db;
    label = "bg_1",
    assetowner_id = "asset_owner_1",
    multihour_bid_max_profiles = 1,
)

IARA.add_bidding_group!(db;
    label = "bg_2",
    assetowner_id = "asset_owner_1",
    simple_bid_max_segments = 1,
)

# After adding the Bidding Groups, we can link the time series files for the price and quantity offers.
# Let's take a look at each of these files before linking them.

# ### Quantity Offer

IARA.time_series_dataframe(joinpath(PATH_BASE_CASE, "quantity_offer.csv"))

# ### Price Offer

IARA.time_series_dataframe(joinpath(PATH_BASE_CASE, "price_offer.csv"))

#

IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_offer = "quantity_offer",
    price_offer = "price_offer",
)

# We have just added the time series for the simple bidding offers. Now let's check the multi-hour bidding offers and link them to our case.

# ### Quantity Offer

IARA.time_series_dataframe(
    joinpath(PATH_BASE_CASE, "quantity_offer_multihour.csv"),
)

# ### Price Offer

IARA.time_series_dataframe(
    joinpath(PATH_BASE_CASE, "price_offer_multihour.csv"),
)

#

IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_offer_multihour = "quantity_offer_multihour",
    price_offer_multihour = "price_offer_multihour",
)

# ## Plants

IARA.add_thermal_plant!(db;
    label = "ter_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = 1,
        min_generation = 0.0,
        max_generation = 50.0,
        om_cost = 20.0,
    ),
    biddinggroup_id = "bg_1",
    has_commitment = 0,
    bus_id = "bus_1",
)

IARA.add_thermal_plant!(db;
    label = "ter_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = 1,
        min_generation = 0.0,
        max_generation = 20.0,
        om_cost = 10.0,
    ),
    biddinggroup_id = "bg_2",
    has_commitment = 0,
    bus_id = "bus_1",
)

# ## Closing the case

IARA.close_study!(db)
