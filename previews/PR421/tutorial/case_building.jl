# # Editing physical data

# In this tutorial, it is described how to edit the physical configuration of an existing case in IARA - for example, data related to generation units 
# or network elements. For that, we will use as a starting point the example case `boto_base_01`, analyzed in the [first steps](first_execution.md) tutorial, and 
# manipulate it, aiming to illustrate the incorporation of modifications to its dataset. 

# If you have already gone through the previous tutorial, this case was built in the `case_path` defined. In order to manipulate its inputs, we will now load the 
# `boto_base_01` example case, with the [`IARA.load_study`](@ref) function, and store it in a variable named `case_edit_unit`. Note that we need to include the 
# `read_only = false` argument to indicate that we wish to write modifications to the case.

using IARA # hide
const case_path = joinpath(@__DIR__, "data", "ExampleCase_boto_base_01") # hide
; # hide

case_name = "boto_base_01"
IARA.ExampleCases.build_example_case(case_path, case_name) # hide
case_edit_unit = IARA.load_study(case_path; read_only = false);
#hide

# Now, we can modify any case characteristic, from general characteristics (such as number of periods or number of scenarios) to market clearing aspects. 
# In the present tutorial, we will focus on editing physical elements, which can be added, removed or have their parameters modified.
# To illustrate this functionality, we can, for example, add a new thermal generator to our example case, using the function [`IARA.add_thermal_unit!`](@ref), as shown below.
# Note that the functions related to other physical elements of the system are analogous to the one used in this example - for instance, [`IARA.add_renewable_unit!`](@ref) 
# adds a new renewable generator and [`IARA.add_bus!`](@ref) adds a new bus.

# Regardless of the element type, additions require the definition of a set of parameters. In the case of thermal units, as shown below, the information needed comprises: 
# (i) the case that is being modified (see above that we have store our example case in a variable named `case_edit_unit`), (ii) the `label`, which corresponds to the plant's name, 
# (iii) technical characteristics, such as the generation capacity (`max_generation`), (iv) variable costs (`om_cost`), (v) the bus to which it is connected (`bus_id`), 
# and the bidding group to which it is assigned (`biddinggroup_id`) - for more information on Bidding groups, read about the model's [key features](../key_features.md).

# Note that [`IARA.add_thermal_unit!`](@ref) uses the functions `DataFrame` and `DateTime`, which belong to the `DataFrames` and `Dates` packages, respectively, which must be 
# installed. Then, we just need to import them before calling [`IARA.add_thermal_unit!`](@ref), as shown below.

using DataFrames
using Dates
; #hide

IARA.add_thermal_unit!(
    case_edit_unit;
    label = "Geothermal",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [20.0],
        om_cost = [3.0],
    ),
    biddinggroup_id = "ThermalA_01",
    bus_id = "Eastern",
)
; #hide

# As mentioned, other general or physical modifications can be carried out, using functions similar to the ones presented above. For now, let's move 
# forward with the example case incorporating the addition presented in this tutorial. The final step is to close the study, using the [`IARA.close_study!`](@ref) function, 
# assign a new folder for the model to write execution outputs and re-execute it, using the function [`IARA.market_clearing`](@ref).

IARA.close_study!(case_edit_unit)
path02_edit_unit = joinpath(case_path, "02_edit_unit")
IARA.market_clearing(
    case_path;
    output_path = path02_edit_unit,
    delete_output_folder_before_execution = true,
);
#hide

# After successfully re-executing IARA, the outputh path will be filled with files containing the model's results, including automatically generated plots.
# When analyzing the new marginal costs obtained, using the function [`IARA.custom_plot`](@ref) (which uses the output file `load_marginal_cost_ex_post_physical.csv`), 
# we can see that they present differences in comparison with the ones observed in the previous execution, prior to the addition of the new thermal plant. 
# In particular, since we have added to the Eastern bus a new low-cost generation asset, it is visible the consequent reduction in the marginal costs in this bus.

cmg_name2 = "load_marginal_cost_ex_post_physical.csv"
cmg_path2 = joinpath(path02_edit_unit, cmg_name2)
IARA.custom_plot(cmg_path2, IARA.PlotTimeSeriesQuantiles)

# Moving forward with the sequence of tutorial, click [here](clearing_executions.md) to understand how to modify market clearing configurations in an existing case.
