# # Hydro Base Case - Running

# > The data for this case is available in the folder [`data/case_2`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_2)

using Dates
using DataFrames
using IARA
; #hide

# In the [previous section](case_02_build_hydrounit_base_case.md), we have loaded the base case and added a Hydro Unit to it. Now, we will run this case in two different run modes:
# - `TRAIN_MIN_COST`
# - `MARKET_CLEARING`

# Let's create a folder to store each run mode output and define the path to the original case.

const PATH_EXECUTION = joinpath(@__DIR__, "case_2_execution")
if !isdir(PATH_EXECUTION)
    mkdir(PATH_EXECUTION)
end

const PATH_ORIGINAL = joinpath(@__DIR__, "data", "case_2")
; #hide

#md # !!! note "Note"
#md #     As we have a Hydro Unit in this case, running the `TRAIN_MIN_COST` mode before the `MARKET_CLEARING` mode is necessary, as it will help us generate the hydro offers.

# So, before running our case, let's review some information about it.

# ## Case Recap

# | **Periods** | **Subperiods** | **Scenarios** | **Subperiod duration (hours)** | **Yearly discount rate** |
# |:----------:|:----------:|:-------------:|:--------------------------:|:------------------------:|
# |      2     |      1     |      12       |             24             |            10%           |

# | **Technology** | **Name** |        **Owner**        | **Maximum Generation (MW)** | **Cost (\$/MWh)** |
# |:--------------:|:--------:|:-----------------------:|:----------------------------:|:----------------:|
# |    Renewable   |  Solar1  |     Price Taker         |              80              |                  |
# |     Thermal    | Thermal1 |     Thermal Owner       |              20              |         10       |
# |     Thermal    | Thermal2 |     Price Taker         |              20              |         30       |
# |     Thermal    | Thermal3 |     Thermal Owner       |              20              |        100       |
# |     Thermal    | Thermal4 |     Price Taker         |              20              |        300       |
# |     Thermal    | Thermal5 |     Price Taker         |              50              |        1000      |
# |     Thermal    | Thermal6 |     Price Taker         |              50              |        3000      |
# |       Hydro    |  Hydro1  |     Hydro Owner         |              80              |                  |

# ## Centralized Operation

# First let's copy the original case to a new folder.

const PATH_CENTRALIZED = joinpath(PATH_EXECUTION, "centralized")

if !isdir(PATH_CENTRALIZED)
    mkdir(PATH_CENTRALIZED)
end

cp(PATH_ORIGINAL, PATH_CENTRALIZED; force = true);
#hide

# Now, let's run the case with [`IARA.train_min_cost`](@ref).

IARA.train_min_cost(
    PATH_CENTRALIZED;
    delete_output_folder_before_execution = true,
)

# ### Analyzing the results

# The results are stored inside the case folder, in the `outputs` directory.

# ```
# case_folder
#  ├── outputs
#  │    ├── plots
#  │    │   └── ...
#  │    └── ...
#  └── ...
# ```

# As we have seen before, IARA provides a set of plots to help us analyze the results. Let's take a look at some of them.

# Let's take a look into some of the plots generated automatically.

# ```@raw html
# <iframe src="case_2_execution\\centralized\\outputs\\plots\\load_marginal_cost_all.html" style="height:500px;width:100%;"></iframe>
# ```
# ```@raw html
# <iframe src="case_2_execution\\centralized\\outputs\\plots\\renewable_generation_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ```@raw html
# <iframe src="case_2_execution\\centralized\\outputs\\plots\\thermal_generation_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ```@raw html
# <iframe src="case_2_execution\\centralized\\outputs\\plots\\hydro_generation_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ## Market Clearing

# Now that we have the hydro offers from the `TRAIN_MIN_COST` mode, we can run the `MARKET_CLEARING` mode.

# Let's copy the data from the `TRAIN_MIN_COST` mode to a new folder. 
# The hydro offers are in the `outputs` folder inside the `centralized` folder. For our case, we need to move this files to the root of the case folder.

const PATH_MARKET_CLEARING = joinpath(PATH_EXECUTION, "market_clearing")

if !isdir(PATH_MARKET_CLEARING)
    mkdir(PATH_MARKET_CLEARING)
end

cp(PATH_CENTRALIZED, PATH_MARKET_CLEARING; force = true)
cp(
    joinpath(PATH_MARKET_CLEARING, "outputs", "hydro_generation.csv"),
    joinpath(PATH_MARKET_CLEARING, "hydro_generation.csv");
    force = true,
)
cp(
    joinpath(PATH_MARKET_CLEARING, "outputs", "hydro_generation.toml"),
    joinpath(PATH_MARKET_CLEARING, "hydro_generation.toml");
    force = true,
)

cp(
    joinpath(PATH_MARKET_CLEARING, "outputs", "hydro_opportunity_cost.csv"),
    joinpath(PATH_MARKET_CLEARING, "hydro_opportunity_cost.csv");
    force = true,
)
cp(
    joinpath(PATH_MARKET_CLEARING, "outputs", "hydro_opportunity_cost.toml"),
    joinpath(PATH_MARKET_CLEARING, "hydro_opportunity_cost.toml");
    force = true,
)
; #hide

# Before running, we need to load the case and set the run mode to `MARKET_CLEARING` and the clearing bid source to `PRICETAKER_HEURISTICS`.

db = IARA.load_study(PATH_MARKET_CLEARING; read_only = false)

IARA.update_configuration!(
    db;
    bid_data_source = IARA.Configurations_BidDataSource.PRICETAKER_HEURISTICS,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
)
; #hide

IARA.close_study!(db)

# Now, let's run the case with [`IARA.market_clearing`](@ref).

IARA.market_clearing(
    PATH_MARKET_CLEARING;
    delete_output_folder_before_execution = true,
)

# Let's take a look into some of the plots generated automatically.

# ```@raw html
# <iframe src="case_2_execution\\market_clearing\\outputs\\plots\\bidding_group_price_offer_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ```@raw html
# <iframe src="case_2_execution\\market_clearing\\outputs\\plots\\bidding_group_energy_offer_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ```@raw html
# <iframe src="case_2_execution\\market_clearing\\outputs\\plots\\bidding_group_generation_ex_ante_commercial_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ```@raw html
# <iframe src="case_2_execution\\market_clearing\\outputs\\plots\\bidding_group_generation_ex_post_commercial_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ```@raw html
# <iframe src="case_2_execution\\market_clearing\\outputs\\plots\\hydro_generation_ex_post_physical_all.html" style="height:500px;width:100%;"></iframe>
# ```
