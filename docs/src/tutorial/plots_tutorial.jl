# # Plotting
# > The data for this case is available in the folder [`data/plot`](https://github.com/psrenergy/IARA.jl/tree/main/docs/src/tutorial/data/plot)
# We'll start by importing the necessary packages.

using IARA
; #hide
# From other tutorials, we have seen that `IARA.jl` automatically generates some plots for the case results.
# Sometimes, these plots can contain too much information, which can make it hard to understand what is happening.
# Having this in mind, we can use the [`IARA.custom_plot`](@ref) function to generate a custom plot, with only the information we want.
# In this tutorial we will take a look into some examples.
# ## Plot types overview
# The `IARA.custom_plot` function can generate the following types of plots:
# - [`IARA.PlotTimeSeriesAll`](@ref)
# - [`IARA.PlotTimeSeriesStackedMean`](@ref)
# - [`IARA.PlotTimeSeriesQuantiles`](@ref)
# - [`IARA.PlotTechnologyHistogram`](@ref)
# - [`IARA.PlotTechnologyHistogramSubperiod`](@ref)
# - [`IARA.PlotTechnologyHistogramPeriod`](@ref)
# - [`IARA.PlotTechnologyHistogramPeriodSubperiod`](@ref)
# - [`IARA.PlotRelationAll`](@ref)
# ## Creating a custom plot
# Before anything, we need to define the path to the time series that we are going to plot.
path_volume = joinpath(@__DIR__, "data", "plot", "hydro_initial_volume.csv")
path_turbining = joinpath(@__DIR__, "data", "plot", "hydro_turbining.csv")
; #hide
# Let's start by plotting a time series for the volume of some Hydro Units just like the `IARA.jl` default plot.
IARA.custom_plot(path_volume, IARA.PlotTimeSeriesAll)

#
#
#

# The plot above shows the volume of the Hydro Units in all scenarios. As the case contains multiple agents, scenarios, periods and subperiods, the plot can be a bit confusing.
# Let's try to plot just a single scenario.
IARA.custom_plot(path_volume, IARA.PlotTimeSeriesAll; scenario = 1)

#
#
#

# Now, let's try to plot the data only for the agent `FURNAS`.
IARA.custom_plot(path_volume, IARA.PlotTimeSeriesAll; agents = ["FURNAS"])

#
#
#

# Now we can see the volume of the Hydro Unit `FURNAS` in all scenarios. This is a bit more clear, but we can still improve it.
# Let's say that we are only interested in the mean volume of the Hydro Unit `FURNAS` in all scenarios.
# We can use the `IARA.PlotTimeSeriesQuantiles` plot type to generate this plot.
IARA.custom_plot(path_volume, IARA.PlotTimeSeriesQuantiles; agents = ["FURNAS"])

#
#
#

# Now we have a plot with the mean volume of the Hydro Unit `FURNAS` in all scenarios. This is a lot more clear than the default plot.
# We can also specify a range of periods to plot (or even scenarios and subperiods).
# let's try to plot the first 10 periods.
IARA.custom_plot(
    path_volume,
    IARA.PlotTimeSeriesQuantiles;
    agents = ["FURNAS"],
    period = 1:10,
)

#
#
#

# Now we have a plot with the mean volume of the Hydro Unit `FURNAS` in the first 10 periods of all scenarios.
# Let's put a more specific title to the plot.
IARA.custom_plot(
    path_volume,
    IARA.PlotTimeSeriesQuantiles;
    agents = ["FURNAS"],
    period = 1:10,
    title = "Volume of FURNAS in the first 10 periods",
)
