#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

# ---------------------------------------------------------------------
# Collection definition
# ---------------------------------------------------------------------
"""
    HydroPlant

Hydro plants are high-level data structures that represent hydro electricity generation.
"""
@collection @kwdef mutable struct HydroPlant <: AbstractCollection
    label::Vector{String} = []
    existing::Vector{HydroPlant_Existence.T} = []
    max_generation::Vector{Float64} = []
    production_factor::Vector{Float64} = []
    max_turbining::Vector{Float64} = []
    min_volume::Vector{Float64} = []
    max_volume::Vector{Float64} = []
    initial_volume::Vector{Float64} = []
    initial_volume_type::Vector{HydroPlant_InitialVolumeType.T} = []
    min_outflow::Vector{Float64} = []
    om_cost::Vector{Float64} = []
    has_commitment::Vector{HydroPlant_HasCommitment.T} = []
    operation_type::Vector{HydroPlant_OperationType.T} = []
    min_generation::Vector{Float64} = []
    # index of the bus to which the hydro plant belongs in the collection Bus
    bus_index::Vector{Int} = []
    # index of the bidding group to which the hydro plant belongs in the collection BiddingGroup
    bidding_group_index::Vector{Int} = []
    # index of the gauging station from which the hydro plant receives its inflow in the collection GaugingStation
    gauging_station_index::Vector{Int} = []
    # index of the downstream turbining hydro Plant in the collection HydroPlant
    turbine_to::Vector{Int} = []
    # index of the downstream spillage hydro Plant in the collection HydroPlant
    spill_to::Vector{Int} = []
    inflow_file::String = ""

    # caches
    is_associated_with_some_virtual_reservoir::Vector{Bool} = []
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(hydro_plant::HydroPlant, inputs)

Initialize the Hydro Plant collection from the database.
"""
function initialize!(hydro_plant::HydroPlant, inputs::AbstractInputs)
    num_hydro_plants = PSRI.max_elements(inputs.db, "HydroPlant")
    if num_hydro_plants == 0
        return nothing
    end

    hydro_plant.label = PSRI.get_parms(inputs.db, "HydroPlant", "label")
    hydro_plant.initial_volume = PSRI.get_parms(inputs.db, "HydroPlant", "initial_volume")
    hydro_plant.initial_volume_type =
        PSRI.get_parms(inputs.db, "HydroPlant", "initial_volume_type") .|> HydroPlant_InitialVolumeType.T
    hydro_plant.operation_type =
        PSRI.get_parms(inputs.db, "HydroPlant", "operation_type") .|> HydroPlant_OperationType.T
    hydro_plant.has_commitment =
        PSRI.get_parms(inputs.db, "HydroPlant", "has_commitment") .|> HydroPlant_HasCommitment.T
    hydro_plant.bus_index = PSRI.get_map(inputs.db, "HydroPlant", "Bus", "id")
    hydro_plant.bidding_group_index = PSRI.get_map(inputs.db, "HydroPlant", "BiddingGroup", "id")
    hydro_plant.gauging_station_index = PSRI.get_map(inputs.db, "HydroPlant", "GaugingStation", "id")
    hydro_plant.turbine_to = PSRI.get_map(inputs.db, "HydroPlant", "HydroPlant", "turbine_to")
    hydro_plant.spill_to = PSRI.get_map(inputs.db, "HydroPlant", "HydroPlant", "spill_to")

    # Load time series files
    hydro_plant.inflow_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "HydroPlant", "inflow")

    hydro_plant.is_associated_with_some_virtual_reservoir = zeros(Bool, num_hydro_plants)

    update_time_series_from_db!(hydro_plant, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(hydro_plant::HydroPlant, db::DatabaseSQLite, stage_date_time::DateTime)

Update the Hydro Plant time series from the database.
"""
function update_time_series_from_db!(
    hydro_plant::HydroPlant,
    db::DatabaseSQLite,
    stage_date_time::DateTime,
)
    hydro_plant.existing =
        PSRDatabaseSQLite.read_time_series_row(
            db,
            "HydroPlant",
            "existing";
            date_time = stage_date_time,
        ) .|> HydroPlant_Existence.T
    hydro_plant.production_factor = PSRDatabaseSQLite.read_time_series_row(
        db,
        "HydroPlant",
        "production_factor";
        date_time = stage_date_time,
    )
    hydro_plant.min_generation = PSRDatabaseSQLite.read_time_series_row(
        db,
        "HydroPlant",
        "min_generation";
        date_time = stage_date_time,
    )
    hydro_plant.max_generation = PSRDatabaseSQLite.read_time_series_row(
        db,
        "HydroPlant",
        "max_generation";
        date_time = stage_date_time,
    )
    hydro_plant.max_turbining = PSRDatabaseSQLite.read_time_series_row(
        db,
        "HydroPlant",
        "max_turbining";
        date_time = stage_date_time,
    )
    hydro_plant.min_volume = PSRDatabaseSQLite.read_time_series_row(
        db,
        "HydroPlant",
        "min_volume";
        date_time = stage_date_time,
    )
    hydro_plant.max_volume = PSRDatabaseSQLite.read_time_series_row(
        db,
        "HydroPlant",
        "max_volume";
        date_time = stage_date_time,
    )
    hydro_plant.min_outflow = PSRDatabaseSQLite.read_time_series_row(
        db,
        "HydroPlant",
        "min_outflow";
        date_time = stage_date_time,
    )
    hydro_plant.om_cost = PSRDatabaseSQLite.read_time_series_row(
        db,
        "HydroPlant",
        "om_cost";
        date_time = stage_date_time,
    )

    return nothing
end

"""
    add_hydro_plant!(db::DatabaseSQLite; kwargs...)
    
Add a Hydro Plant to the database.
    
Required arguments:
    
  - `label::String`: Hydro Plant label.
  - `bus_id::String`: Bus label of the Hydro Plant (only if the bus already exists).
  - `parameters::DataFrames.DataFrame`: A dataframe containing time series attributes (described below).
  - `gaugingstation_id::String`: Gauging station of the hydro plant (only if the gauging station already exists).
  - `biddinggroup_id::String`: Bidding Group label (only if the BiddingGroup already exists)
    - _Required if_ [`IARA.Configurations_RunMode`](@ref) _is not set to_ `CENTRALIZED_OPERATION`
  - `operation_type::HydroPlant_OperationType.T`: Operation type of the Hydro Plant ([`IARA.HydroPlant_OperationType`](@ref)).

Optional arguments:
  
  - `initial_volume::Float64`: Initial volume of the Hydro Plant.
  - `initial_volume_type::HydroPlant_InitialVolumeType.T`: Initial volume type of the Hydro Plant ([`IARA.HydroPlant_InitialVolumeType`](@ref)).
    - _Default is_ `HydroPlant_InitialVolumeType.VOLUME`.
  - `has_commitment::Int`: Whether the Hydro Plant has commitment (0 -> false, 1 -> true).
    - _Default is_ `0`.
  - `hydroplant_turbine_to::String`: Downstream plant for turbining (only if the Hydro Plant already exists).
  - `hydroplant_spill_to::String`: Downstream plant for spillage (only if the Hydro Plant already exists).

---

**Time Series Parameters**

The `parameters` dataframe has columns that may be mandatory or not, depending on some configurations about the case.


Required columns:

  - `date_time::Vector{DateTime}`: Date and time of the Hydro Plant time series data.
  - `min_generation::Vector{Float64}`: Minimum generation of the Hydro Plant `[MWh]`
   - _Required if_ `has_commitment` _is set to_ `1`. _Ignored otherwise._
  - `existing::Vector{Int}`: Whether the hydro plant is existing or not (0 -> not existing, 1 -> existing)
  - `production_factor::Vector{Float64}`: Production factor of the Hydro Plant `[MWh/m³/s]`
  - `max_generation::Vector{Float64}`: Maximum generation of the Hydro Plant `[MWh]`
  - `min_volume::Vector{Float64}`: Minimum volume of the Hydro Plant `[hm³]`
  - `max_volume::Vector{Float64}`: Maximum volume of the Hydro Plant `[hm³]`
  - `max_turbining::Vector{Float64}`: Maximum turbining of the Hydro Plant `[hm³/s]`

Optional columns:
  - `min_outflow::Vector{Float64}`: Minimum outflow of the Hydro Plant `[hm³/s]`
  - `om_cost::Vector{Float64}`: Operation and maintenance cost of the hydro plant `[\$/MWh]`

"""
function add_hydro_plant!(db::DatabaseSQLite; kwargs...)
    if !haskey(kwargs, :gaugingstation_id)
        gauging_station_label = kwargs[:label] * "_gauging_station"
        add_gauging_station!(db; label = gauging_station_label)
        kwargs = Dict(kwargs...)
        kwargs[:gaugingstation_id] = gauging_station_label
    end

    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "HydroPlant"; sql_typed_kwargs...)
    return nothing
end

"""
    update_hydro_plant!(db::DatabaseSQLite, label::String; kwargs...)

Update the Hydro Plant named 'label' in the database.
"""
function update_hydro_plant!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "HydroPlant",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_hydro_plant_relation!(
        db::DatabaseSQLite, 
        hydro_plant_label::String; 
        collection::String, 
        relation_type::String, 
        related_label::String
    )

Update the Hydro Plant named 'label' in the database.

Arguments:

  - `db::PSRClassesInterface.DatabaseSQLite`: Database
  - `hydro_plant_label::String`: Hydro Plant label
  - `collection::String`: Collection name that the Hydro Plant is related to
  - `relation_type::String`: Relation type
  - `related_label::String`: Label of the element that the Hydro Plant is related to
"""
function update_hydro_plant_relation!(
    db::DatabaseSQLite,
    hydro_plant_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "HydroPlant",
        collection,
        hydro_plant_label,
        related_label,
        relation_type,
    )
    return db
end

function update_hydro_plant_time_series_parameter!(
    db::DatabaseSQLite,
    label::String,
    attribute::String,
    value;
    dimensions...,
)
    PSRI.PSRDatabaseSQLite.update_time_series_row!(
        db,
        "HydroPlant",
        attribute,
        label,
        value;
        dimensions...,
    )
    return db
end

"""
    set_hydro_turbine_to!(db::DatabaseSQLite, hydro_plant_from::String, hydro_plant_to::String)

Link two Hydro Plants by setting the downstream turbining Hydro Plant.
"""

function set_hydro_turbine_to!(
    db::DatabaseSQLite,
    hydro_plant_from::String,
    hydro_plant_to::String,
)
    PSRI.set_related!(
        db,
        "HydroPlant",
        "HydroPlant",
        hydro_plant_from,
        hydro_plant_to,
        "turbine_to",
    )
    return nothing
end

"""
    set_hydro_spill_to!(db::DatabaseSQLite, hydro_plant_from::String, hydro_plant_to::String)

Link two Hydro Plants by setting the downstream spillage Hydro Plant.
"""
function set_hydro_spill_to!(
    db::DatabaseSQLite,
    hydro_plant_from::String,
    hydro_plant_to::String,
)
    PSRI.set_related!(
        db,
        "HydroPlant",
        "HydroPlant",
        hydro_plant_from,
        hydro_plant_to,
        "spill_to",
    )
    return nothing
end

"""
    validate(hydro_plant::HydroPlant)

Validate the Hydro Plants' parameters. Return the number of errors found.
"""
function validate(hydro_plant::HydroPlant)
    num_errors = 0
    for i in 1:length(hydro_plant)
        if isempty(hydro_plant.label[i])
            @error("Hydro Plant Label cannot be empty.")
            num_errors += 1
        end
        if hydro_plant.max_generation[i] < 0
            @error(
                "Hydro Plant $(hydro_plant.label[i]) Maximum generation must be non-negative. Current value is $(hydro_plant.max_generation[i])."
            )
            num_errors += 1
        end
        if hydro_plant.max_turbining[i] < 0
            @error(
                "Hydro Plant $(hydro_plant.label[i]) Maximum turbining must be non-negative. Current value is $(hydro_plant.max_turbining[i])."
            )
            num_errors += 1
        end
        if hydro_plant.min_volume[i] < 0
            @error(
                "Hydro Plant $(hydro_plant.label[i]) Minimum volume must be non-negative. Current value is $(hydro_plant.min_volume[i])."
            )
            num_errors += 1
        end
        if hydro_plant.max_volume[i] < 0
            @error(
                "Hydro Plant $(hydro_plant.label[i]) Maximum volume must be non-negative. Current value is $(hydro_plant.max_volume[i])."
            )
            num_errors += 1
        end
        if hydro_plant.initial_volume[i] < 0
            @error(
                "Hydro Plant $(hydro_plant.label[i]) Initial volume must be non-negative. Current value is $(hydro_plant.initial_volume[i])."
            )
            num_errors += 1
        end
        if hydro_plant.min_outflow[i] < 0
            @error(
                "Hydro Plant $(hydro_plant.label[i]) Minimum outflow must be non-negative. Current value is $(hydro_plant.min_outflow[i])."
            )
            num_errors += 1
        end
        if hydro_plant.om_cost[i] < 0
            @error(
                "Hydro Plant $(hydro_plant.label[i]) O&M cost must be non-negative. Current value is $(hydro_plant.om_cost[i])."
            )
            num_errors += 1
        end
        if hydro_plant.initial_volume_type[i] == HydroPlant_InitialVolumeType.PER_UNIT &&
           !(0.0 <= hydro_plant.initial_volume[i] <= 1.0)
            @error(
                "Hydro Plant $(hydro_plant.label[i]) Initial volume type is `PerUnit` must be between 0 and 1. Current value is $(hydro_plant.initial_volume[i])."
            )
            num_errors += 1
        elseif hydro_plant.initial_volume_type[i] == HydroPlant_InitialVolumeType.VOLUME &&
               !(hydro_plant.min_volume[i] <= hydro_plant.initial_volume[i] <= hydro_plant.max_volume[i])
            # TODO: Could min volume be null?
            @error(
                "Hydro Plant $(hydro_plant.label[i]) Initial volume type is `Volume` must be between minimum and maximum volume [$(hydro_plant.min_volume[i]), $(hydro_plant.max_volume[i])]. Current value is $(hydro_plant.initial_volume[i])."
            )
            num_errors += 1
        end
        if !is_null(hydro_plant.turbine_to[i]) &&
           !(hydro_plant.turbine_to[i] in 1:length(hydro_plant))
            @error(
                "Hydro Plant $(hydro_plant.label[i]) downstream turbining Hydro Plant $(hydro_plant.turbine_to[i]) not found."
            )
            num_errors += 1
        end
        if hydro_plant.turbine_to[i] == i
            @error(
                "Hydro Plant $(hydro_plant.label[i]) downstream turbining Hydro Plant cannot be itself."
            )
            num_errors += 1
        end
        if !is_null(hydro_plant.spill_to[i]) &&
           !(hydro_plant.spill_to[i] in 1:length(hydro_plant))
            @error(
                "Hydro Plant $(hydro_plant.label[i]) downstream spillage Hydro Plant $(hydro_plant.spill_to[i]) not found."
            )
            num_errors += 1
        end
        if hydro_plant.spill_to[i] == i
            @error(
                "Hydro Plant $(hydro_plant.label[i]) downstream spillage Hydro Plant cannot be itself."
            )
            num_errors += 1
        end
        if hydro_plant.has_commitment[i] == HydroPlant_HasCommitment.HAS_COMMITMENT
            if is_null(hydro_plant.min_generation[i])
                @error(
                    "Hydro Plant $(hydro_plant.label[i]) Minimum generation must be defined if it has commitment."
                )
                num_errors += 1
            elseif hydro_plant.min_generation[i] < 0
                @error(
                    "Hydro Plant $(hydro_plant.label[i]) Minimum generation must be non-negative. Current value is $(hydro_plant.min_generation[i])."
                )
                num_errors += 1
            end
        end
        if hydro_plant_downstream_cumulative_production_factor(hydro_plant, i) < 0
            @error(
                "Hydro Plant $(hydro_plant.label[i]) cumulative production factor must be non-negative. Current value is $(hydro_plant_downstream_cumulative_production_factor(hydro_plant, i))."
            )
            num_errors += 1
        end
    end
    return num_errors
end

"""
    validate_relations(inputs, hydro_plant::HydroPlant)

Validate the Hydro Plants' references. Return the number of errors found.
"""
# TODO: add validation to bidding_group or virtual_reservoir not nullity
function validate_relations(inputs::AbstractInputs, hydro_plant::HydroPlant)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup)
    gauging_stations = index_of_elements(inputs, GaugingStation)
    any_hydro_has_min_outflow = any_elements(inputs, HydroPlant; filters = [has_min_outflow])

    num_errors = 0
    for i in 1:length(hydro_plant)
        if !(hydro_plant.bus_index[i] in buses)
            @error(
                "Hydro Plant $(hydro_plant.label[i]) Bus ID $(hydro_plant.bus_index[i]) not found."
            )
            num_errors += 1
        end
        if !is_null(hydro_plant.bidding_group_index[i]) &&
           !(hydro_plant.bidding_group_index[i] in bidding_groups)
            @error(
                "Hydro Plant $(hydro_plant.label[i]) Bidding Group ID $(hydro_plant.bidding_group_index[i]) not found."
            )
            num_errors += 1
        end
        if !is_null(hydro_plant.bidding_group_index[i]) &&
           clearing_hydro_representation(inputs) ==
           Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
            @warn(
                "Ignoring Bidding Group ID $(hydro_plant.bidding_group_index[i]) for Hydro Plant $(hydro_plant.label[i])
              because the clearing hydro representation is set to virtual reservoirs."
            )
        end
        if !(hydro_plant.gauging_station_index[i] in gauging_stations)
            @error(
                "Hydro Plant $(hydro_plant.label[i]) Gauging Station ID $(hydro_plant.gauging_station_index[i]) not found."
            )
            num_errors += 1
        end
    end
    if any_hydro_has_min_outflow &&
       isnan(hydro_minimum_outflow_violation_cost(inputs))
        @error("Hydro Plant minimum outflow violation cost is not defined.")
        num_errors += 1
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

"""
    hydro_plant_max_generation(inputs, idx::Int)

Get the maximum generation for the Hydro Plant at index 'idx'.
"""
hydro_plant_max_generation(inputs::AbstractInputs, idx::Int) =
    if is_null(inputs.collections.hydro_plant.max_generation[idx])
        hydro_plant_max_turbining(inputs, idx) * hydro_plant_production_factor(inputs, idx)
    else
        inputs.collections.hydro_plant.max_generation[idx]
    end

"""
    hydro_plant_downstream_cumulative_production_factor(inputs, idx::Int)

Get the sum of production factors for the Hydro Plant at index 'idx' and all plants downstream from it.
"""
function hydro_plant_downstream_cumulative_production_factor(inputs::AbstractInputs, idx::Int)
    return hydro_plant_downstream_cumulative_production_factor(inputs.collections.hydro_plant, idx::Int)
end

function hydro_plant_downstream_cumulative_production_factor(hydro_plant::HydroPlant, idx::Int)
    if is_null(hydro_plant.turbine_to[idx])
        return hydro_plant.production_factor[idx]
    else
        return hydro_plant.production_factor[idx] +
               hydro_plant_downstream_cumulative_production_factor(hydro_plant, hydro_plant.turbine_to[idx])
    end
end

function hydro_plant_max_available_turbining(inputs::AbstractInputs, idx::Int)
    if hydro_plant_production_factor(inputs, idx) <= 1e-6
        return hydro_plant_max_turbining(inputs, idx)
    else
        return min(
            hydro_plant_max_turbining(inputs, idx),
            inputs.collections.hydro_plant.max_generation[idx] / hydro_plant_production_factor(inputs, idx),
        )
    end
end

"""
    hydro_plant_initial_volume(inputs, idx::Int)

Get the initial volume for the Hydro Plant at index 'idx'.
"""
function hydro_plant_initial_volume(inputs::AbstractInputs, idx::Int)
    if inputs.collections.hydro_plant.initial_volume_type[idx] == HydroPlant_InitialVolumeType.PER_UNIT
        return hydro_plant_min_volume(inputs, idx) +
               inputs.collections.hydro_plant.initial_volume[idx] *
               (hydro_plant_max_volume(inputs, idx) - hydro_plant_min_volume(inputs, idx))
    elseif inputs.collections.hydro_plant.initial_volume_type[idx] == HydroPlant_InitialVolumeType.VOLUME
        return inputs.collections.hydro_plant.initial_volume[idx]
    else
        error("Initial volume type not recognized.")
    end
end

function hydro_blocks(inputs::AbstractInputs)
    if hydro_balance_block_resolution(inputs) == Configurations_HydroBalanceBlockResolution.CHRONOLOGICAL_BLOCKS
        # There is one more block because this is the volume at the start of each block.
        # In this case the last block is actually the final volume of a certain stage and
        # the first block of the next stage
        return collect(1:number_of_blocks(inputs)+1)
    elseif hydro_balance_block_resolution(inputs) == Configurations_HydroBalanceBlockResolution.AGGREGATED_BLOCKS
        # In this case the first block is the only one in the stage and the second block is only used to represent
        # the final volume of the stage.
        return [1, 2]
    end
end

function fill_whether_hydro_plant_is_associated_with_some_virtual_reservoir!(inputs::AbstractInputs, idx::Int)
    if !any_elements(inputs, VirtualReservoir)
        inputs.collections.hydro_plant.is_associated_with_some_virtual_reservoir[idx] = false
    else
        hydro_plants_associated_with_some_virtual_reservoir = union(virtual_reservoir_hydro_plant_indices(inputs)...)
        inputs.collections.hydro_plant.is_associated_with_some_virtual_reservoir[idx] =
            idx in hydro_plants_associated_with_some_virtual_reservoir
    end
    return nothing
end

"""
    hydro_plant_generation_file(inputs)

Return the hydro generation time series file for all hydro plants.
"""
hydro_plant_generation_file(inputs::AbstractInputs) = "hydro_generation"

"""
    hydro_plant_opportunity_cost_file(inputs)

Return the hydro opportunity cost time series file for all hydro plants.
"""
hydro_plant_opportunity_cost_file(inputs::AbstractInputs) = "hydro_opportunity_cost"

has_min_outflow(hydro_plant::HydroPlant, idx::Int) = hydro_plant.min_outflow[idx] > 0
has_commitment(hydro_plant::HydroPlant, idx::Int) =
    hydro_plant.has_commitment[idx] == HydroPlant_HasCommitment.HAS_COMMITMENT
operates_with_reservoir(hydro_plant::HydroPlant, idx::Int) =
    hydro_plant.operation_type[idx] == HydroPlant_OperationType.RESERVOIR
operates_as_run_of_river(hydro_plant::HydroPlant, idx::Int) =
    hydro_plant.operation_type[idx] == HydroPlant_OperationType.RUN_OF_RIVER
is_associated_with_some_virtual_reservoir(hydro_plant::HydroPlant, idx::Int) =
    hydro_plant.is_associated_with_some_virtual_reservoir[idx]

function hydro_volume_from_previous_stage(inputs::AbstractInputs, stage::Int, scenario::Int)
    if stage == 1
        return inputs.collections.hydro_plant.initial_volume
    else
        volume = read_serialized_clearing_variable(
            inputs,
            RunTime_ClearingProcedure.EX_POST_PHYSICAL,
            :hydro_volume;
            stage = stage - 1,
            scenario = scenario,
        )
        # The volume at the end of the stage is the first block of the next stage
        return volume.data[end, :]
    end
end
