# # Multi-hour Bid - Running

# > The data for this case is available in the folder [`data/case_3`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_3)

import Pkg #hide
Pkg.activate("../../..") #hide
Pkg.instantiate() #hide
using Dates
using DataFrames
using IARA
; #hide

# ## Case recap

# In the [previous section](build_multi_hour_base_case.md), we have built a case containing two Bidding Groups, where one of them has a multi-hour bid.
# Now we will run this case using the `MARKET_CLEARING` mode.

# Let's create a folder to store the output of the `MARKET_CLEARING` mode and define the path to the original case.

const PATH_EXECUTION = joinpath(@__DIR__, "case_3_execution")

if !isdir(PATH_EXECUTION)
    mkdir(PATH_EXECUTION)
end

const PATH_ORIGINAL = joinpath(@__DIR__, "data", "case_3")

cp(PATH_ORIGINAL, PATH_EXECUTION; force = true);
#hide

# Before running, let's load the case and update the run mode to `MARKET_CLEARING`.
db = IARA.load_study(PATH_EXECUTION; read_only = false)

IARA.update_configuration!(
    db;
    run_mode = IARA.Configurations_RunMode.MARKET_CLEARING,
)

IARA.close_study!(db)
; #hide

# Now we are able to run the case with [`IARA.main`](@ref).

IARA.main([PATH_EXECUTION])

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
# <iframe src="case_3_execution\\outputs\\plots\\bidding_group_generation_ex_ante_commercial_all.html" style="height:500px;width:100%;"></iframe>
# ```

# ```@raw html
# <iframe src="case_3_execution\\outputs\\plots\\bidding_group_generation_multihour_ex_ante_commercial_all.html" style="height:500px;width:100%;"></iframe>
# ```
