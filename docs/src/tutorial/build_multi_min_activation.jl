# # Min activation Bid - Building

# > The data for this case is available in the folder [`data/case_4`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_4)

# We'll start by importing the necessary packages.
import Pkg #hide
Pkg.activate("../../..") #hide
Pkg.instantiate() #hide
using Dates
using Quiver
using DataFrames
using IARA
; #hide

# In this tutorial, we will start with the [Case 3](build_multi_hour_base_case.md) elements and create a case with a minimum activation level for a Bidding Group.

# ## Original Case Recap

# In the original case we had two Bidding Groups, one with a multi-hour bid and the other with an independent bid.
# Runnin the `MARKET_CLEARING` mode, we analyzed the effect of the multi-hour bid in the market.

# ### Changes for this tutorial

# In this tutorial, we will add a minimum activation level for the Bidding Group with the multi-hour bid.

# ## Loading case

# Now let's copy the base case to a new folder and load it.

const PATH_ORIGINAL = joinpath(@__DIR__, "data", "case_3")

const PATH_MIN_ACTIVATION = joinpath(@__DIR__, "data", "case_4")

if !isdir(PATH_MIN_ACTIVATION)
    mkdir(PATH_MIN_ACTIVATION)
end

@show readdir(PATH_ORIGINAL)

#

cp(
    joinpath(PATH_ORIGINAL, "study.iara"),
    joinpath(PATH_MIN_ACTIVATION, "study.iara");
    force = true,
)

db = IARA.load_study(PATH_MIN_ACTIVATION; read_only = false);
#hide

# ## Minimum Activation Level Time series

# In the [`data/case_4`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_4) folder, we have a time series files for the minimum activation level for the Bidding Group with the multi-hour bid.
# Let's take a quick look at the file and load it into the database.

IARA.time_series_dataframe(
    joinpath(PATH_MIN_ACTIVATION, "minimum_activation_level_multihour.csv"),
)

# 

IARA.time_series_dataframe(
    joinpath(PATH_MIN_ACTIVATION, "parent_profile_multihour.csv"),
)

# 

IARA.time_series_dataframe(
    joinpath(PATH_MIN_ACTIVATION, "complementary_grouping_multihour.csv"),
)

# 

IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    minimum_activation_level_multihour = "minimum_activation_level_multihour",
    parent_profile_multihour = "parent_profile_multihour",
    complementary_grouping_multihour = "complementary_grouping_multihour",
)
; #hide

# ## Closing the case

IARA.close_study!(db)
; #hide
