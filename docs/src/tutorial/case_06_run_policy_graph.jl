# # Policy Graphs - Running

# > The data for this case is available in the folder [`data/case_6`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_6)

# ## Recap
# In this tutorial, we explore the differences between two types of policy graphs, linear and cyclic, using a simple model with varying numbers of periods.
# The model contains one zone, one bus, one demand point, one hydro unit, and one thermal unit.
# We will analyze how changes in policy graph types affect the decision-making process in centralized operations,
# focusing on the impact of different configurations of periods.

# We'll start by importing the necessary packages.

using Dates
using DataFrames
using IARA
; #hide

# First, let's create a folder that will contain the execution for each iteration.

const PATH_ORIGINAL = joinpath(@__DIR__, "data", "case_6")

const PATH_EXECUTION = joinpath(@__DIR__, "case_6_execution")
if !isdir(PATH_EXECUTION)
    mkdir(PATH_EXECUTION)
end

# ## Running the Case: Linear Policy Graph with 2 Stages

# Let's create a copy of the original case.

const PATH_LINEAR_2 = joinpath(PATH_EXECUTION, "linear_2")
if !isdir(PATH_LINEAR_2)
    mkdir(PATH_LINEAR_2)
end

cp(PATH_ORIGINAL, PATH_LINEAR_2; force = true);

# In the [previous section](case_06_build_policy_graph.md) we created a case with 2 periods and a linear policy graph.
# Therefore, we do not need to update the number of periods or the policy graph type.

# Let's begin by running the case with a linear policy graph and 2 periods.
# This scenario simulates a situation where decision-making happens over two periods with no cyclic behavior.

IARA.train_min_cost(PATH_LINEAR_2)

# ### Analyzing the results

# Here's the graph of the final volume at each period

hydro_final_volume_all =
    joinpath(PATH_LINEAR_2, "outputs", "hydro_final_volume.csv") # hide
IARA.custom_plot(
    hydro_final_volume_all,
    IARA.PlotTimeSeriesMean;
    title = "Reservoir Final Volume",
    agents = ["Hydro1"],
    period = 1:2,
)

# For this case, the optimal strategy for the hydro unit is to release water in the last period.
# This happens because there are no future costs associated with the last period, encouraging full use of available resources.

# ## Running the Case: Linear Policy Graph with 10 Stages

# Next, we increase the number of periods to 10 while keeping the policy graph linear.
# This allows us to see how a longer planning horizon influences the decision-making process.

const PATH_LINEAR_10 = joinpath(PATH_EXECUTION, "linear_10")

if !isdir(PATH_LINEAR_10)
    mkdir(PATH_LINEAR_10)
end

cp(PATH_ORIGINAL, PATH_LINEAR_10; force = true);

# Now we need to update the number of periods to 10.

db = IARA.load_study(PATH_LINEAR_10; read_only = false)

IARA.update_configuration!(
    db;
    number_of_periods = 10,
)

# We will also update the inflow and demand time series files to have 10 periods.

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "demands_10_periods",
)

IARA.link_time_series_to_file(
    db,
    "HydroUnit";
    inflow_ex_ante = "inflow_10_periods",
)

IARA.close_study!(db)

# Let's run the case.

IARA.train_min_cost(PATH_LINEAR_10)

# ### Analyzing the results

# Here's the graph of the final volume at each period

hydro_final_volume_all =
    joinpath(PATH_LINEAR_10, "outputs", "hydro_final_volume.csv") # hide
IARA.custom_plot(
    hydro_final_volume_all,
    IARA.PlotTimeSeriesMean;
    title = "Reservoir Final Volume",
    agents = ["Hydro1"],
    period = 1:2,
)

# With 10 periods, the model accounts for a longer planning horizon, influencing the decision to release water more conservatively in earlier periods.
# The hydro unit no longer empties the reservoir in a single burst but instead manages water levels more carefully over time, anticipating future periods.

IARA.custom_plot(
    hydro_final_volume_all,
    IARA.PlotTimeSeriesMean;
    title = "Reservoir Final Volume",
    agents = ["Hydro1"],
    period = 3:10,
)

# As the planning horizon progresses, the model becomes more aggressive in its approach,
# depleting the reservoir by the end of the fourth year.

# ## Running the Case: Cyclic Policy Graph with 2 Stages

# Now, we will switch the policy graph to cyclic, which assumes that the decision-making process repeats over time.

const PATH_CYCLIC_2 = joinpath(PATH_EXECUTION, "cyclic_2")

if !isdir(PATH_CYCLIC_2)
    mkdir(PATH_CYCLIC_2)
end

cp(PATH_ORIGINAL, PATH_CYCLIC_2; force = true);

# Now we need to update the policy graph type to `CYCLIC_WITH_NULL_ROOT`.

db = IARA.load_study(PATH_CYCLIC_2; read_only = false)

IARA.update_configuration!(
    db;
    number_of_periods = 2,
    policy_graph_type = IARA.Configurations_PolicyGraphType.CYCLIC_WITH_NULL_ROOT,
)

# We will also update the inflow and demand time series files to have 2 periods.

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "demands",
)

IARA.link_time_series_to_file(
    db,
    "HydroUnit";
    inflow_ex_ante = "inflow",
)
;

IARA.close_study!(db)
; #hide

# Let's run the case.

IARA.train_min_cost(PATH_CYCLIC_2)

# ### Analyzing the results

# Here's the graph of the final volume at each period

hydro_final_volume_all =
    joinpath(PATH_CYCLIC_2, "outputs", "hydro_final_volume.csv") # hide
IARA.custom_plot(
    hydro_final_volume_all,
    IARA.PlotTimeSeriesMean;
    title = "Reservoir Final Volume",
    agents = ["Hydro1"],
    period = 1:2,
)

# With a cyclic policy graph, the decision-making process becomes more dynamic.
# The hydro unit is now planning with the expectation that the periods will repeat, creating an incentive
# to maintain a certain level of water in the reservoir.

# ## Conclusion

# Through these simulations, we observe significant differences between linear and cyclic policy graphs.
# In the 2-period linear setup, the model chooses an aggressive strategy at the end of the first year,
# since there is no incentive to conserve water for future periods.
# This short-term focus leads to a rapid depletion of the reservoir.

# With 10 periods in the linear policy graph, the model's approach becomes more conservative, water
# levels are managed more carefully during the early years, reflecting a longer-term outlook.
# However, the reservoir is still emptied by the end of the fourth year,
# indicating a gradual shift toward resource depletion as the planning horizon progresses.

# In contrast, the cyclic policy graph with 2 periods adds a dynamic element to the decision-making process.
# Here, the hydro unit balances the immediate need for power generation with the understanding that the
# periods will repeat, encouraging more sustainable water management across cycles.
