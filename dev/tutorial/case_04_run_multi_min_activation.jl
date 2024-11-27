# # Min activation Bid - Running

# > The data for this case is available in the folder [`data/case_4`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_4)

using Dates
using DataFrames
using IARA
; #hide

# ## Case recap

# In the [previous section](case_04_build_multi_min_activation.md), we started from the [Case 3](build_profile_base_case.md) elements and created a case with a minimum activation level for a Bidding Group.

# Let's create a folder to store the output of the `MARKET_CLEARING` mode and define the path to the original case.

const PATH_EXECUTION = joinpath(@__DIR__, "case_4_execution")

if !isdir(PATH_EXECUTION)
    mkdir(PATH_EXECUTION)
end

const PATH_ORIGINAL = joinpath(@__DIR__, "data", "case_4")

cp(PATH_ORIGINAL, PATH_EXECUTION; force = true);
#hide

# Before running, let's load the case and update the run mode to `MARKET_CLEARING`.
db = IARA.load_study(PATH_EXECUTION; read_only = false)

IARA.update_configuration!(
    db;
    clearing_model_type_ex_ante_physical = IARA.Configurations_ClearingModelType.HYBRID,
    clearing_model_type_ex_ante_commercial = IARA.Configurations_ClearingModelType.HYBRID,
    clearing_model_type_ex_post_physical = IARA.Configurations_ClearingModelType.HYBRID,
    clearing_model_type_ex_post_commercial = IARA.Configurations_ClearingModelType.HYBRID,
)

IARA.close_study!(db)
; #hide

# Now we are able to run the case with [`IARA.market_clearing`](@ref).

IARA.market_clearing(PATH_EXECUTION)

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

# ```@raw html
# <iframe src="case_4_execution\\outputs\\plots\\bidding_group_generation_ex_ante_commercial_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ```@raw html
# <iframe src="case_4_execution\\outputs\\plots\\bidding_group_generation_profile_ex_ante_commercial_all.html" style="height:500px;width:100%;"></iframe>
# ```
