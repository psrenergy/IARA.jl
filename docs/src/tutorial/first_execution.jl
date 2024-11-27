# # My first execution

# In this tutorial, we will load an example case, analyze its input data, execute the model and assess the results obtained.
# This case contains some basic elements that can help understand some of the functionalities of the IARA package.

# ## First steps

# We'll start by indicating we are using the IARA package - assuming it is already installed (otherwise, see the [Installation Guide](index.md)).
using IARA
; #hide

# In addition, we also need to define a directory to store the case and indicate the name of the example case we wish to load (which will be done next).
case_path = joinpath(@__DIR__, "data", "ExampleCase_FirstExecution")
case_name = "boto_base_01"

# To load the example case, we can use the function [`ExampleCases.build_example_case`](@ref), indicating the path in which the files must be stored (defined above),
# as well as the name of the example case to be loaded (defined above).
IARA.ExampleCases.build_example_case(case_path, case_name)

# Besides loading existing cases, it is also possible to build and/or edit a case's physical data, manipulating its input data - this is shown in detail further in 
# the present documentation. For now, let's stick to this example case as it is defined.

# ## Analyzing input data

# After loading (or creating or editing) a case, it is possible to analyze the input data using the [`IARA.summarize`](@ref) function.
# This function describes briefly the case's key characteristics, as shown below.

IARA.summarize(case_path)

# ## Execution

# Since this example case already contains all the basic data required to execute the IARA model in its `MARKET_CLEARING` mode, the execution is quite straightforward.
# First, we must define the folder in which the output files will be stored.

path01_first_execution = joinpath(case_path, "output01_first_execution")

# Then, the execution can be carried out using the [`IARA.market_clearing`](@ref) function, indicating the case path and the output path defined, as follows:

IARA.market_clearing(case_path, output_path = path01_first_execution)

# `MARKET_CLEARING` executions are also explored further in this documentation, in a dedicated pages.

# ## Assessing outputs

# After executing the model, the output path defined will be automatically filled with several output files, organized in a standard structure of folders, presented below.

# ```
# case_path
#  ├── output01_first_execution
#  │    ├── plots
#  │    │   └── ...
#  │    └── ...
#  └── ...
# ```

# The `case_path` folder contains, besides the output folder (in our example, named `output01_first_execution`), the case's input files.
# The `output01_first_execution` folder contains, besides the `plots` folder, raw outputs of the model execution, in ".csv" and ".toml" formats.
# The `plots` folder contains several ".html" files, which lead to graphic visualizations (dashboards) of the outputs.

# As an example, we can take a look at the marginal cost plot. This visualization, presented below, presents the load marginal cost in each node of the system
# (this example case comprises 2 nodes) in each period/subperiod - illustrating the average and upper/lower quantiles of the scenarios represented.

# ```@raw html
# <img src="..\\assets\\output1_CMgDem.png"></img>
# ```

# Specific pages of this tutorial are dedicated to exploring in detail the outputs and dashboards of the IARA model.
