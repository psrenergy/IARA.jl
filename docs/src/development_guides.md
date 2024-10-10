# Development guides

This section contains guides for developers who want to contribute to the development of the project.

## How to add a new collection

The database definition of IARA.jl is based on the standards described in the [PSRDatabaseSQLite documentation page](https://psrenergy.github.io/PSRClassesInterface.jl/dev/psrdatabasesqlite/rules).

The first step to add a new collection is to define the tables, attributes and relationships as a migration in the database/migrations folder.

After defining the new collection in the migration file the next step is to create a new collection type in the src/collections folder. The new collection should be a subtype of the `AbstractCollection` type and should implement at least the following functions:

```julia
initialize!(my_new_collection::MyNewCollection, inputs::AbstractInputs)
add_my_new_collection!(db::DatabaseSQLite; kwargs...)
update_my_new_collection!(db::DatabaseSQLite, label::String; kwargs...)
validate(my_new_collection::MyNewCollection, inputs::AbstractInputs)
validate_relations(my_new_collection::MyNewCollection, inputs::AbstractInputs)
```

The last step is to add the new collection to the [`IARA.Collections`](@ref) type.

## How to add a new time series from external file

Whenever a time series varies with time and scenario we advise it to be loaded into the inputs using the [`IARA.ViewFromExternalFile`](@ref) abstraction. 

The first step to create a new time series from external file is to define a time series file in the schema, developers can follow the [PSRDatabaseSQLite documentation page](https://psrenergy.github.io/PSRClassesInterface.jl/dev/psrdatabasesqlite/rules) to define the time series file.

Once the time series file is defined in the schema and read into a collection developers should add a new field to the [`IARA.TimeSeriesViewsFromExternalFiles`](@ref) struct. The new field should be a subtype of the [`IARA.ViewFromExternalFile`](@ref) and could be an existing subtype or a new subtype.

After adding the new field developers should initialize it in the [`IARA.initialize_time_series_from_external_files`](@ref) function. When making this implementation developers should always pass the expected unit and labels of the time series.

## How to add a new mathematical model element

Mathematical model elements are the building blocks of the different possible optimization problems. They are defined in the `src/model_variables` or `src/model_constraints` folders. To add a new mathematical model element, developers should create a new file in the respective folder and define at least the following functions:

```julia
my_new_model_element!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)

my_new_model_element!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)

my_new_model_element!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)

my_new_model_element!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
```

Each one of these functions performs an action that is specific to the phase of the execution that it is executing at the time. The documentation for each action is available here:
 * [`IARA.SubproblemBuild`](@ref).
 * [`IARA.SubproblemUpdate`](@ref).
 * [`IARA.InitializeOutput`](@ref).
 * [`IARA.WriteOutput`](@ref).

After defining the new model element, developers should add the varags function of the new model element to the respective optimization problem action function defined in the `src/mathematical_model.jl` file.
 
## How to add a new post-processing function

All post-processing functions are defined in the `src/post_processing` folder. To add a new post-processing function, developers should create a new file in the `src/post_processing` folder and add the new function in the scope of [`IARA.post_processing`](@ref).

## How to add a new plot

All plots are defined in the `src/plots` folder. To add a new plot, developers should add a new [`IARA.PlotConfig`](@ref) in the [`IARA.build_plots`](@ref) function. 

If a developer wants to implement a new plot type, they should create a new file in the `src/plots` folder and define the new plot type. The new plot type should be a concrete subtype of the [`IARA.PlotType`](@ref) abstracion and should implement the [`IARA.plot_data`](@ref) function for the corresponding new plot type.

example:

```julia
plot_data(
    ::Type{MyNewPlotType},
    data::Array{T, N},
    agent_names::Vector{String},
    dimensions::Vector{String};
    title::String = "",
    unit::String = "",
    file_path::String,
) where {T <: AbstractFloat, N}
```