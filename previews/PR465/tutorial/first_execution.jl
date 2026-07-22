# # My first execution

# In this tutorial, we will load an example case, analyze its input data, execute the model and assess the results obtained.
# This case contains some basic elements that can help understand some of the functionalities of the IARA package.

# ## First steps

# We'll start by indicating we are using the IARA package - assuming it is already installed (otherwise, see the [Installation Guide](../index.md)) - and 
# defining a directory to store the example case we will analyze.
using IARA
const case_path = joinpath(@__DIR__, "data", "ExampleCase_boto_base_01")
; #hide

# IARA has a number of pre-defined example cases that can be used to explore the model's functionalities. These example cases have standardized names 
# and, for this example, we will use the one named `boto_base_01` - which means that we are representing a fictional physical system named `boto` in a variant named `base` 
# and a subvariant `01`.

# To load this example case, we can use the function [`IARA.ExampleCases.build_example_case`](@ref), indicating the path in which the files must be stored 
# (the `case_path` defined), as well as the name of the example case to be loaded (as mentioned above, this is an internal name used in IARA).

case_name = "boto_base_01"
IARA.ExampleCases.build_example_case(case_path, case_name)
; #hide

# Besides using example cases in their default configurations, it is also possible to [edit a case's physical data](case_building.md), 
# or even [build a case from scratch](../build_a_case_from_scratch.md). For now, let's stick to this example case as it is defined.

# ## Analyzing input data

# After loading (or creating or editing) a case, it is possible to analyze the input data using the [`IARA.summarize`](@ref) function.
# This function describes briefly the case's key characteristics, as shown below.

# The first block indicates the execution options considered in the study.
# IARA is inherently multistage stochastic, and the output below indicates that the execution will be run for 6 periods, using 3 scenarios and 4 subscenarios.
# The following block, Collections, indicates the number of elements of each type in the database. In particular, Units 
# (RenewableUnit, HydroUnit, ThermalUnit and DemandUnit) can either be represented directly, with an explicit modelling of their physical characteristics 
# (under a cost-based representation), or represented as BiddingGroups, in which case their modelling will depend on an AssetOwner's preferred strategy 
# (under a bid-based representation). Finally, the summary also lists the external files considered, which contatin stochastic data that will be taken into 
# account when building the market clearing problem.

IARA.summarize(case_path)

# ## Execution

# Since this example case already contains all the basic data required, we can now run the market clearing in the IARA model.
# For that, we must first define the folder in which the output files will be stored. This will be created as subfolder of the `case_path` folder defined above.

path01_first_execution = joinpath(case_path, "01_first_execution")
; #hide

# Then, the execution can be carried out using the [`IARA.market_clearing`](@ref) function, indicating the case path and the output path defined, as follows:

IARA.market_clearing(case_path; output_path = path01_first_execution);
#hide

# After successfully executing the model, the output path will be filled with several output files, including a subfolder containing automatically 
# generated plots. The final folder structure is as presented below.

# The `case_path` folder contains, besides the output folder (in our example, named `output01_first_execution`), the case's input files.
# The `output01_first_execution` folder contains, besides the `plots` folder, raw outputs of the model execution, in _.csv_ and _.tomlL formats.
# The `plots` folder contains several _.html_ files, which lead to graphic visualizations (dashboards) of the outputs.

# ```
# case_path
#  ├── output01_first_execution
#  │    ├── plots
#  │    └── ...
#  └── ...
# ```

# ## Assessing outputs

# Now, we can examine the outputs obtained in the execution. As an example, we can take a look at the marginal cost results. 
# You can either open this plot directly from the plot subfolder (the file should be named `load_marginal_cost_ex_post_physical_avg.html`) or run 
# the [`IARA.custom_plot`](@ref) function referring to the output file `load_marginal_cost_ex_post_physical.csv`, as shown below.
# More information about this functionality can be found in the [plots tutorial](plots_tutorial.md).

cmg_name = "load_marginal_cost_ex_post_physical.csv"
cmg_path = joinpath(path01_first_execution, cmg_name)
IARA.custom_plot(cmg_path, IARA.PlotTimeSeriesQuantiles)

# Because the `boto_base_01` example case has 2 buses, there are 2 sets of marginal costs data represented, corresponding respectively to the Eastern and Western buses.
# On the horizontal axis, we have 6 periods represented sequentially (summer, winter, winter, winter, summer, summer), with each period broken down into 3 subperiods 
# (morning, afternoon, evening). There is variation of marginal costs within each period and subperiod, due to the presence of scenarios and subscenarios, which result 
# in the bands shown in the image. Note that all 3 periods corresponding to summer have the same underlying probability distribution, and the same is true for the 3 
# periods corresponding to winter.

# The marginal cost result is an output of the market clearing optimization problem, which dispatches the available units under a least cost criterion, taking into account 
# stochastic resource availability. It can be seen that the winter periods typically present higher marginal costs than summer periods and that so does the Western bus 
# in comparison with the Eastern bus.

# ## Next steps

# In addition to this initial page, there are other `Getting started` guides, which aim to provide an initial overview of the main functionalities of the IARA model.
# You can access the following pages to continue this tutorial:

# - [Editing physical data](case_building.md) describes the procedure to edit a case's physical input data, such as system elements; 
# - [Editing clearing options](clearing_executions.md) addresses details of different clearing configurations that can be considered; 
# - Heuristic bid pre-processing details the procedure applied to generate the agents' bids in the bid-based representation; 
# - SDDP pre-processing presents the pre-execution treatment that must be given to cases that include hydro reservoirs.

# If you are already familiar with these procedures, you can look into more general practical use guides:

# - [Building a case from scratch](../build_a_case_from_scratch.md) shows how to build completely new cases, initializing the study, defining execution options and adding elements; 
# - [Manipulating bid data](../bidding_formats.md) describes how to manually define agents' bids in the model, rather than using the ones bids built by the model itself; 
# - [Manipulating the case's temporal structure](../intro_policy_graph.md) details how periods and subperiods relate temporally in the model's framework; 
# - [Exploring custom plots](plots_tutorial.md) illustrates how to generate customized visualizations of the results.

# Alternatively, you can delve into more conceptual descriptions:

# - [Key features](../key_features.md) of the IARA model, from physical data to clearing options; 
# - [Market clearing structure](../clearing_procedure.md), including the market iterations comprised in the model and the execution modes available; 
# - [Aspects of hydro systems](../hydro_challenges.md) that were taken into account when designing conceptual IARA features; 
# - [Conceptual mathematical formulation](../conceptual_formulation.md) of the different problem representations supported by IARA.
