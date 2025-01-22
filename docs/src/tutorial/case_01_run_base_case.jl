# # Base Case - Running

# > The data for this case is available in the folder [`data/case_1`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_1)

using Dates
using DataFrames
using IARA
; #hide

# In the last [tutorial](case_01_build_base_case.md), we built a simple case with the following characteristics:

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

# Now, we will run this case in two different run modes: `TRAIN_MIN_COST` and `MARKET_CLEARING`.

# First, let's create separate folders inside a `case_1_execution` folder for each case and copy the base case to the `centralized` and `market_clearing` folders. 

const PATH_ORIGINAL = joinpath(@__DIR__, "data", "case_1")

const PATH_EXECUTION = joinpath(@__DIR__, "case_1_execution")
if !isdir(PATH_EXECUTION)
    mkdir(PATH_EXECUTION)
end

const PATH_CENTRALIZED = joinpath(PATH_EXECUTION, "centralized")
const PATH_MARKET_CLEARING = joinpath(PATH_EXECUTION, "market_clearing")

if !isdir(PATH_CENTRALIZED)
    mkdir(PATH_CENTRALIZED)
end
if !isdir(PATH_MARKET_CLEARING)
    mkdir(PATH_MARKET_CLEARING)
end

cp(PATH_ORIGINAL, PATH_CENTRALIZED; force = true);
cp(PATH_ORIGINAL, PATH_MARKET_CLEARING; force = true);

# ## Centralized Operation

# Now we are able to run the case with [`IARA.train_min_cost`](@ref).

IARA.train_min_cost(PATH_CENTRALIZED)

# ### Analyzing the results

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

# Having access to all the outputs, we can visualize the data as we would like. 
# However, `IARA` already plots some of the outputs for us and saves it inside the `plots` folder.

# Let's take a look into some of the plots generated automatically.

# ```@raw html
# <iframe src="case_1_execution\\centralized\\outputs\\plots\\load_marginal_cost_all.html" style="height:500px;width:100%;"></iframe>
# ```
# ```@raw html
# <iframe src="case_1_execution\\centralized\\outputs\\plots\\renewable_generation_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ```@raw html
# <iframe src="case_1_execution\\centralized\\outputs\\plots\\thermal_generation_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ## Market Clearing

# Let's load the case with [`IARA.load_study`](@ref). As we are updating the run mode, we need to open it using `read_only = false`.

db = IARA.load_study(PATH_MARKET_CLEARING; read_only = false);
#hide

# In order to run the case in `Market Clearing`, we need to set the run mode and the clearing bid source (where the bid quantity and price offers will come from).
# For this example we will be using the `PRICETAKER_HEURISTICS` as the clearing bid source. This setting will automatically generate bids for each Bidding Group.
# We can set these two parameters in the configurations, with [`IARA.update_configuration!`](@ref).

IARA.update_configuration!(
    db;
    bid_data_source = IARA.Configurations_BidDataSource.PRICETAKER_HEURISTICS,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
)
IARA.close_study!(db)

# Now we are able to run the case with [`IARA.market_clearing`](@ref).

IARA.market_clearing(
    PATH_MARKET_CLEARING;
    delete_output_folder_before_execution = true,
)

# Let's take a look into some of the plots generated automatically.

# ```@raw html
# <iframe src="case_1_execution\\market_clearing\\outputs\\plots\\bidding_group_price_offer_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ```@raw html
# <iframe src="case_1_execution\\market_clearing\\outputs\\plots\\bidding_group_energy_offer_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ```@raw html
# <iframe src="case_1_execution\\market_clearing\\outputs\\plots\\bidding_group_generation_ex_ante_commercial_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ```@raw html
# <iframe src="case_1_execution\\market_clearing\\outputs\\plots\\bidding_group_generation_ex_post_commercial_all.html" style="height:500px;width:100%;"></iframe>
# ```
