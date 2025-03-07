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
    HydroUnit

Hydro units are high-level data structures that represent hydro electricity generation.
"""
@collection @kwdef mutable struct HydroUnit <: AbstractCollection
    label::Vector{String} = []
    existing::Vector{HydroUnit_Existence.T} = []
    max_generation::Vector{Float64} = []
    production_factor::Vector{Float64} = []
    max_turbining::Vector{Float64} = []
    min_volume::Vector{Float64} = []
    max_volume::Vector{Float64} = []
    initial_volume::Vector{Float64} = []
    initial_volume_type::Vector{HydroUnit_InitialVolumeType.T} = []
    min_outflow::Vector{Float64} = []
    om_cost::Vector{Float64} = []
    has_commitment::Vector{HydroUnit_HasCommitment.T} = []
    operation_type::Vector{HydroUnit_OperationType.T} = []
    min_generation::Vector{Float64} = []
    # index of the bus to which the hydro unit belongs in the collection Bus
    bus_index::Vector{Int} = []
    # index of the bidding group to which the hydro unit belongs in the collection BiddingGroup
    bidding_group_index::Vector{Int} = []
    # index of the gauging station from which the hydro unit receives its inflow in the collection GaugingStation
    gauging_station_index::Vector{Int} = []
    # index of the downstream turbining hydro Plant in the collection HydroUnit
    turbine_to::Vector{Int} = []
    # index of the downstream spillage hydro Plant in the collection HydroUnit
    spill_to::Vector{Int} = []
    waveguide_volume::Vector{Vector{Float64}} = []
    inflow_ex_ante_file::String = ""
    inflow_ex_post_file::String = ""

    # caches
    is_associated_with_some_virtual_reservoir::Vector{Bool} = []
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(hydro_unit::HydroUnit, inputs::AbstractInputs)

Initialize the Hydro Unit collection from the database.
"""
function initialize!(hydro_unit::HydroUnit, inputs::AbstractInputs)
    num_hydro_units = PSRI.max_elements(inputs.db, "HydroUnit")
    if num_hydro_units == 0
        return nothing
    end

    hydro_unit.label = PSRI.get_parms(inputs.db, "HydroUnit", "label")
    hydro_unit.initial_volume = PSRI.get_parms(inputs.db, "HydroUnit", "initial_volume")
    hydro_unit.initial_volume_type =
        convert_to_enum.(
            PSRI.get_parms(inputs.db, "HydroUnit", "initial_volume_type"),
            HydroUnit_InitialVolumeType.T,
        )
    hydro_unit.operation_type =
        convert_to_enum.(
            PSRI.get_parms(inputs.db, "HydroUnit", "operation_type"),
            HydroUnit_OperationType.T,
        )
    hydro_unit.has_commitment =
        convert_to_enum.(
            PSRI.get_parms(inputs.db, "HydroUnit", "has_commitment"),
            HydroUnit_HasCommitment.T,
        )
    hydro_unit.bus_index = PSRI.get_map(inputs.db, "HydroUnit", "Bus", "id")
    hydro_unit.bidding_group_index = PSRI.get_map(inputs.db, "HydroUnit", "BiddingGroup", "id")
    hydro_unit.gauging_station_index = PSRI.get_map(inputs.db, "HydroUnit", "GaugingStation", "id")
    hydro_unit.turbine_to = PSRI.get_map(inputs.db, "HydroUnit", "HydroUnit", "turbine_to")
    hydro_unit.spill_to = PSRI.get_map(inputs.db, "HydroUnit", "HydroUnit", "spill_to")
    hydro_unit.waveguide_volume =
        PSRDatabaseSQLite.read_vector_parameters(inputs.db, "HydroUnit", "waveguide_volume")

    # Load time series files
    hydro_unit.inflow_ex_ante_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "HydroUnit", "inflow_ex_ante")
    hydro_unit.inflow_ex_post_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "HydroUnit", "inflow_ex_post")

    hydro_unit.is_associated_with_some_virtual_reservoir = zeros(Bool, num_hydro_units)

    update_time_series_from_db!(hydro_unit, inputs.db, initial_date_time(inputs))

    return nothing
end

function load_new_attributes_from_db!(hydro_unit::HydroUnit, db_temp)
    hydro_unit.waveguide_volume =
        PSRDatabaseSQLite.read_vector_parameters(db_temp, "HydroUnit", "waveguide_volume")
    return nothing
end

"""
    update_time_series_from_db!(hydro_unit::HydroUnit, db::DatabaseSQLite, period_date_time::DateTime)

Update the Hydro Unit time series from the database.
"""
function update_time_series_from_db!(
    hydro_unit::HydroUnit,
    db::DatabaseSQLite,
    period_date_time::DateTime,
)
    date = Dates.format(period_date_time, "yyyymmddHHMMSS")
    hydro_unit.existing =
        @memoized_serialization "hydro_unit-existing-$date" convert_to_enum.(
            PSRDatabaseSQLite.read_time_series_row(
                db,
                "HydroUnit",
                "existing";
                date_time = period_date_time,
            ),
            HydroUnit_Existence.T,
        )
    hydro_unit.production_factor =
        @memoized_serialization "hydro_unit-production_factor-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "HydroUnit",
            "production_factor";
            date_time = period_date_time,
        )
    hydro_unit.min_generation =
        @memoized_serialization "hydro_unit-min_generation-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "HydroUnit",
            "min_generation";
            date_time = period_date_time,
        )
    hydro_unit.max_generation =
        @memoized_serialization "hydro_unit-max_generation-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "HydroUnit",
            "max_generation";
            date_time = period_date_time,
        )
    hydro_unit.max_turbining =
        @memoized_serialization "hydro_unit-max_turbining-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "HydroUnit",
            "max_turbining";
            date_time = period_date_time,
        )
    hydro_unit.min_volume =
        @memoized_serialization "hydro_unit-min_volume-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "HydroUnit",
            "min_volume";
            date_time = period_date_time,
        )
    hydro_unit.max_volume =
        @memoized_serialization "hydro_unit-max_volume-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "HydroUnit",
            "max_volume";
            date_time = period_date_time,
        )
    hydro_unit.min_outflow =
        @memoized_serialization "hydro_unit-min_outflow-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "HydroUnit",
            "min_outflow";
            date_time = period_date_time,
        )
    hydro_unit.om_cost =
        @memoized_serialization "hydro_unit-om_cost-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "HydroUnit",
            "om_cost";
            date_time = period_date_time,
        )
    return nothing
end

"""
    add_hydro_unit!(db::DatabaseSQLite; kwargs...)
    
Add a Hydro Unit to the database.
    
Required arguments:
    
  - `label::String`: Hydro Unit label.
  - `bus_id::String`: Bus label of the Hydro Unit (only if the bus already exists).
  - `parameters::DataFrames.DataFrame`: A dataframe containing time series attributes (described below).
  - `gaugingstation_id::String`: Gauging station of the hydro unit (only if the gauging station already exists).
  - `biddinggroup_id::String`: Bidding Group label (only if the BiddingGroup already exists)
    - _Required if_ [`IARA.RunMode`](@ref) _is not set to_ `TRAIN_MIN_COST`
  - `operation_type::HydroUnit_OperationType.T`: Operation type of the Hydro Unit ([`IARA.HydroUnit_OperationType`](@ref)).

Optional arguments:
  
  - `initial_volume::Float64`: Initial volume of the Hydro Unit.
  - `initial_volume_type::HydroUnit_InitialVolumeType.T`: Initial volume type of the Hydro Unit ([`IARA.HydroUnit_InitialVolumeType`](@ref)).
    - _Default is_ `HydroUnit_InitialVolumeType.VOLUME`.
  - `has_commitment::Int`: Whether the Hydro Unit has commitment (0 -> false, 1 -> true).
    - _Default is_ `0`.
  - `hydrounit_turbine_to::String`: Downstream plant for turbining (only if the Hydro Unit already exists).
  - `hydrounit_spill_to::String`: Downstream plant for spillage (only if the Hydro Unit already exists).

---

**Time Series Parameters**

The `parameters` dataframe has columns that may be mandatory or not, depending on some configurations about the case.


Required columns:

  - `date_time::Vector{DateTime}`: Date and time of the Hydro Unit time series data.
  - `min_generation::Vector{Float64}`: Minimum generation of the Hydro Unit `[MWh]`
   - _Required if_ `has_commitment` _is set to_ `1`. _Ignored otherwise._
  - `existing::Vector{Int}`: Whether the hydro unit is existing or not (0 -> not existing, 1 -> existing)
  - `production_factor::Vector{Float64}`: Production factor of the Hydro Unit `[MWh/m³/s]`
  - `max_generation::Vector{Float64}`: Maximum generation of the Hydro Unit `[MWh]`
  - `min_volume::Vector{Float64}`: Minimum volume of the Hydro Unit `[hm³]`
  - `max_volume::Vector{Float64}`: Maximum volume of the Hydro Unit `[hm³]`
  - `max_turbining::Vector{Float64}`: Maximum turbining of the Hydro Unit `[hm³/s]`

Optional columns:
  - `min_outflow::Vector{Float64}`: Minimum outflow of the Hydro Unit `[hm³/s]`
  - `om_cost::Vector{Float64}`: Operation and maintenance cost of the hydro unit `[\$/MWh]`


Example:
```julia
IARA.add_hydro_unit!(db;
    label = "Hydro1",
    operation_type = IARA.HydroUnit_OperationType.RUN_OF_RIVER,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [IARA.HydroUnit_Existence.EXISTS], # 1 = true
        production_factor = [1.0], # MW/m³/s
        max_generation = [100.0], # MW
        max_turbining = [100.0], # m³/s
        min_volume = [0.0], # hm³
        max_volume = [0.0], # hm³
        min_outflow = [0.0], # m³/s
        om_cost = [0.0], # \$/MWh
    ),
    initial_volume = 0.0, # hm³
    gaugingstation_id = "gauging_station",
    biddinggroup_id = "Hydro Owner",
    bus_id = "Island",
)
```
"""
function add_hydro_unit!(db::DatabaseSQLite; kwargs...)
    if !haskey(kwargs, :gaugingstation_id)
        gauging_station_label = kwargs[:label]
        add_gauging_station!(db; label = gauging_station_label)
        kwargs = Dict(kwargs...)
        kwargs[:gaugingstation_id] = gauging_station_label
    end

    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "HydroUnit"; sql_typed_kwargs...)
    return nothing
end

"""
    update_hydro_unit!(db::DatabaseSQLite, label::String; kwargs...)

Update the Hydro Unit named 'label' in the database.

Example:
```julia
IARA.update_hydro_unit!(
    db,
    "hyd_1";
    initial_volume = 1000.0
)
```
"""
function update_hydro_unit!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "HydroUnit",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_hydro_unit_vectors!(db::DatabaseSQLite, label::String; kwargs...)

Update the vectors of the Hydro Unit named 'label' in the database.
"""
function update_hydro_unit_vectors!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRDatabaseSQLite.update_vector_parameters!(
            db,
            "HydroUnit",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_hydro_unit_relation!(
        db::DatabaseSQLite, 
        hydro_unit_label::String; 
        collection::String, 
        relation_type::String, 
        related_label::String
    )

Update the Hydro Unit named 'label' in the database.

Arguments:

  - `db::PSRClassesInterface.DatabaseSQLite`: Database
  - `hydro_unit_label::String`: Hydro Unit label
  - `collection::String`: Collection name that the Hydro Unit is related to
  - `relation_type::String`: Relation type
  - `related_label::String`: Label of the element that the Hydro Unit is related to

Example:
```julia
IARA.update_hydro_unit_relation!(db, "hyd_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_1",
)
```
"""
function update_hydro_unit_relation!(
    db::DatabaseSQLite,
    hydro_unit_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "HydroUnit",
        collection,
        hydro_unit_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    update_hydro_unit_time_series_parameter!(
        db::DatabaseSQLite, 
        label::String, 
        attribute::String, 
        value; 
        dimensions...
    )

Update a Hydro Unit time series parameter in the database for a given dimension value

Arguments:

  - `db::PSRClassesInterface.DatabaseSQLite`: Database
  - `label::String`: Hydro Unit label
  - `attribute::String`: Attribute name
  - `value`: Value to be updated
  - `dimensions...`: Dimension values

Example:
```julia
IARA.update_hydro_unit_time_series_parameter!(
    db,
    "hyd_1",
    "max_volume",
    30.0;
    date_time = DateTime(0), # dimension value
)
```
"""
function update_hydro_unit_time_series_parameter!(
    db::DatabaseSQLite,
    label::String,
    attribute::String,
    value;
    dimensions...,
)
    PSRI.PSRDatabaseSQLite.update_time_series_row!(
        db,
        "HydroUnit",
        attribute,
        label,
        value;
        dimensions...,
    )
    return db
end

"""
    set_hydro_turbine_to!(db::DatabaseSQLite, hydro_unit_from::String, hydro_unit_to::String)

Link two Hydro Units by setting the downstream turbining Hydro Unit.

Example:
```julia
IARA.set_hydro_turbine_to!(db, "hydro_1", "hydro_2")
```
"""
function set_hydro_turbine_to!(
    db::DatabaseSQLite,
    hydro_unit_from::String,
    hydro_unit_to::String,
)
    PSRI.set_related!(
        db,
        "HydroUnit",
        "HydroUnit",
        hydro_unit_from,
        hydro_unit_to,
        "turbine_to",
    )
    return nothing
end

"""
    set_hydro_spill_to!(db::DatabaseSQLite, hydro_unit_from::String, hydro_unit_to::String)

Link two Hydro Units by setting the downstream spillage Hydro Unit.

Example:
```julia
IARA.set_hydro_spill_to!(db, "hydro_1", "hydro_2")
```
"""
function set_hydro_spill_to!(
    db::DatabaseSQLite,
    hydro_unit_from::String,
    hydro_unit_to::String,
)
    PSRI.set_related!(
        db,
        "HydroUnit",
        "HydroUnit",
        hydro_unit_from,
        hydro_unit_to,
        "spill_to",
    )
    return nothing
end

"""
    validate(hydro_unit::HydroUnit)

Validate the Hydro Units' parameters. Return the number of errors found.
"""
function validate(hydro_unit::HydroUnit)
    num_errors = 0
    for i in 1:length(hydro_unit)
        if isempty(hydro_unit.label[i])
            @error("Hydro Unit Label cannot be empty.")
            num_errors += 1
        end
        if hydro_unit.max_generation[i] < 0
            @error(
                "Hydro Unit $(hydro_unit.label[i]) Maximum generation must be non-negative. Current value is $(hydro_unit.max_generation[i])."
            )
            num_errors += 1
        end
        if hydro_unit.max_turbining[i] < 0
            @error(
                "Hydro Unit $(hydro_unit.label[i]) Maximum turbining must be non-negative. Current value is $(hydro_unit.max_turbining[i])."
            )
            num_errors += 1
        end
        if hydro_unit.min_volume[i] < 0
            @error(
                "Hydro Unit $(hydro_unit.label[i]) Minimum volume must be non-negative. Current value is $(hydro_unit.min_volume[i])."
            )
            num_errors += 1
        end
        if hydro_unit.max_volume[i] < 0
            @error(
                "Hydro Unit $(hydro_unit.label[i]) Maximum volume must be non-negative. Current value is $(hydro_unit.max_volume[i])."
            )
            num_errors += 1
        end
        if hydro_unit.initial_volume[i] < 0
            @error(
                "Hydro Unit $(hydro_unit.label[i]) Initial volume must be non-negative. Current value is $(hydro_unit.initial_volume[i])."
            )
            num_errors += 1
        end
        if hydro_unit.min_outflow[i] < 0
            @error(
                "Hydro Unit $(hydro_unit.label[i]) Minimum outflow must be non-negative. Current value is $(hydro_unit.min_outflow[i])."
            )
            num_errors += 1
        end
        if hydro_unit.om_cost[i] < 0
            @error(
                "Hydro Unit $(hydro_unit.label[i]) O&M cost must be non-negative. Current value is $(hydro_unit.om_cost[i])."
            )
            num_errors += 1
        end
        if hydro_unit.initial_volume_type[i] == HydroUnit_InitialVolumeType.PER_UNIT &&
           !(0.0 <= hydro_unit.initial_volume[i] <= 1.0)
            @error(
                "Hydro Unit $(hydro_unit.label[i]) Initial volume type is `PerUnit` must be between 0 and 1. Current value is $(hydro_unit.initial_volume[i])."
            )
            num_errors += 1
        elseif hydro_unit.initial_volume_type[i] == HydroUnit_InitialVolumeType.VOLUME &&
               !(hydro_unit.min_volume[i] <= hydro_unit.initial_volume[i] <= hydro_unit.max_volume[i])
            # TODO: Could min volume be null?
            @error(
                "Hydro Unit $(hydro_unit.label[i]) Initial volume type is `Volume` must be between minimum and maximum volume [$(hydro_unit.min_volume[i]), $(hydro_unit.max_volume[i])]. Current value is $(hydro_unit.initial_volume[i])."
            )
            num_errors += 1
        end
        if !is_null(hydro_unit.turbine_to[i]) &&
           !(hydro_unit.turbine_to[i] in 1:length(hydro_unit))
            @error(
                "Hydro Unit $(hydro_unit.label[i]) downstream turbining Hydro Unit $(hydro_unit.turbine_to[i]) not found."
            )
            num_errors += 1
        end
        if hydro_unit.turbine_to[i] == i
            @error(
                "Hydro Unit $(hydro_unit.label[i]) downstream turbining Hydro Unit cannot be itself."
            )
            num_errors += 1
        end
        if !is_null(hydro_unit.spill_to[i]) &&
           !(hydro_unit.spill_to[i] in 1:length(hydro_unit))
            @error(
                "Hydro Unit $(hydro_unit.label[i]) downstream spillage Hydro Unit $(hydro_unit.spill_to[i]) not found."
            )
            num_errors += 1
        end
        if hydro_unit.spill_to[i] == i
            @error(
                "Hydro Unit $(hydro_unit.label[i]) downstream spillage Hydro Unit cannot be itself."
            )
            num_errors += 1
        end
        if hydro_unit.has_commitment[i] == HydroUnit_HasCommitment.HAS_COMMITMENT
            if is_null(hydro_unit.min_generation[i])
                @error(
                    "Hydro Unit $(hydro_unit.label[i]) Minimum generation must be defined if it has commitment."
                )
                num_errors += 1
            elseif hydro_unit.min_generation[i] < 0
                @error(
                    "Hydro Unit $(hydro_unit.label[i]) Minimum generation must be non-negative. Current value is $(hydro_unit.min_generation[i])."
                )
                num_errors += 1
            end
        end
        if hydro_unit_downstream_cumulative_production_factor(hydro_unit, i) < 0
            @error(
                "Hydro Unit $(hydro_unit.label[i]) cumulative production factor must be non-negative. Current value is $(hydro_unit_downstream_cumulative_production_factor(hydro_unit, i))."
            )
            num_errors += 1
        end
    end
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, hydro_unit::HydroUnit)

Validate the Hydro Units' context within the inputs. Return the number of errors found.
"""
# TODO: add validation to bidding_group or virtual_reservoir not nullity
function advanced_validations(inputs::AbstractInputs, hydro_unit::HydroUnit)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup)
    gauging_stations = index_of_elements(inputs, GaugingStation)
    any_hydro_has_min_outflow = any_elements(inputs, HydroUnit; filters = [has_min_outflow])

    num_errors = 0
    for i in 1:length(hydro_unit)
        if !(hydro_unit.bus_index[i] in buses)
            @error(
                "Hydro Unit $(hydro_unit.label[i]) Bus ID $(hydro_unit.bus_index[i]) not found."
            )
            num_errors += 1
        end
        if !is_null(hydro_unit.bidding_group_index[i]) &&
           !(hydro_unit.bidding_group_index[i] in bidding_groups)
            @error(
                "Hydro Unit $(hydro_unit.label[i]) Bidding Group ID $(hydro_unit.bidding_group_index[i]) not found."
            )
            num_errors += 1
        end
        if !is_null(hydro_unit.bidding_group_index[i]) &&
           clearing_hydro_representation(inputs) ==
           Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
            @warn(
                "Ignoring Bidding Group ID $(hydro_unit.bidding_group_index[i]) for Hydro Unit $(hydro_unit.label[i])
              because the clearing hydro representation is set to virtual reservoirs."
            )
        end
        if !(hydro_unit.gauging_station_index[i] in gauging_stations)
            @error(
                "Hydro Unit $(hydro_unit.label[i]) Gauging Station ID $(hydro_unit.gauging_station_index[i]) not found."
            )
            num_errors += 1
        end
    end
    if any_hydro_has_min_outflow &&
       isnan(hydro_minimum_outflow_violation_cost(inputs))
        @error("Hydro Unit minimum outflow violation cost is not defined.")
        num_errors += 1
    end
    if read_ex_ante_inflow_file(inputs) && hydro_unit.inflow_ex_ante_file == "" && length(hydro_unit) > 0
        @error(
            "The option inflow_scenarios_files is set to $(inflow_scenarios_files(inputs)), but no ex_ante inflow file was linked."
        )
        num_errors += 1
    end
    if read_ex_post_inflow_file(inputs) && hydro_unit.inflow_ex_post_file == "" && length(hydro_unit) > 0
        @error(
            "The option inflow_scenarios_files is set to $(inflow_scenarios_files(inputs)), but no ex_post inflow file was linked."
        )
        num_errors += 1
    end
    if !read_ex_ante_inflow_file(inputs) && hydro_unit.inflow_ex_ante_file != "" && length(hydro_unit) > 0
        @warn(
            "The option inflow_scenarios_files is set to $(inflow_scenarios_files(inputs)), but an ex_ante inflow file was linked.
            This file will be ignored."
        )
    end
    if !read_ex_post_inflow_file(inputs) && hydro_unit.inflow_ex_post_file != "" && length(hydro_unit) > 0
        @warn(
            "The option inflow_scenarios_files is set to $(inflow_scenarios_files(inputs)), but an ex_post inflow file was linked.
            This file will be ignored."
        )
    end
    if generate_heuristic_bids_for_clearing(inputs) &&
       clearing_hydro_representation(inputs) ==
       Configurations_ClearingHydroRepresentation.PURE_BIDS &&
       any_elements(inputs, HydroUnit; filters = [operates_as_run_of_river])
        @warn(
            "The BidDataSource option is set to PRICETAKER_HEURISTICS, and the clearing representation is set to PURE_BIDS.
            All Hydro Units operating as run of river will be treated with profile bids during the clearing process."
        )
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

"""
    hydro_unit_max_generation(inputs::AbstractInputs, idx::Int)

Get the maximum generation for the Hydro Unit at index 'idx'.
"""
hydro_unit_max_generation(inputs::AbstractInputs, idx::Int) =
    if is_null(inputs.collections.hydro_unit.max_generation[idx])
        hydro_unit_max_turbining(inputs, idx) * hydro_unit_production_factor(inputs, idx)
    else
        inputs.collections.hydro_unit.max_generation[idx]
    end

"""
    hydro_unit_downstream_cumulative_production_factor(inputs::AbstractInputs, idx::Int)

Get the sum of production factors for the Hydro Unit at index 'idx' and all plants downstream from it.
"""
function hydro_unit_downstream_cumulative_production_factor(inputs::AbstractInputs, idx::Int)
    return hydro_unit_downstream_cumulative_production_factor(inputs.collections.hydro_unit, idx::Int)
end

function hydro_unit_downstream_cumulative_production_factor(hydro_unit::HydroUnit, idx::Int)
    if is_null(hydro_unit.turbine_to[idx])
        return hydro_unit.production_factor[idx]
    else
        return hydro_unit.production_factor[idx] +
               hydro_unit_downstream_cumulative_production_factor(hydro_unit, hydro_unit.turbine_to[idx])
    end
end

function hydro_unit_max_available_turbining(inputs::AbstractInputs, idx::Int)
    if hydro_unit_production_factor(inputs, idx) <= 1e-6
        return hydro_unit_max_turbining(inputs, idx)
    else
        return min(
            hydro_unit_max_turbining(inputs, idx),
            inputs.collections.hydro_unit.max_generation[idx] / hydro_unit_production_factor(inputs, idx),
        )
    end
end

"""
    hydro_unit_initial_volume(inputs::AbstractInputs, idx::Int)

Get the initial volume for the Hydro Unit at index 'idx'.
"""
function hydro_unit_initial_volume(inputs::AbstractInputs, idx::Int)
    if inputs.collections.hydro_unit.initial_volume_type[idx] == HydroUnit_InitialVolumeType.PER_UNIT
        return hydro_unit_min_volume(inputs, idx) +
               inputs.collections.hydro_unit.initial_volume[idx] *
               (hydro_unit_max_volume(inputs, idx) - hydro_unit_min_volume(inputs, idx))
    elseif inputs.collections.hydro_unit.initial_volume_type[idx] == HydroUnit_InitialVolumeType.VOLUME
        return inputs.collections.hydro_unit.initial_volume[idx]
    else
        error("Initial volume type not recognized.")
    end
end

function hydro_subperiods(inputs::AbstractInputs)
    if hydro_balance_subperiod_resolution(inputs) ==
       Configurations_HydroBalanceSubperiodResolution.CHRONOLOGICAL_SUBPERIODS
        # There is one more subperiod because this is the volume at the start of each subperiod.
        # In this case the last subperiod is actually the final volume of a certain period and
        # the first subperiod of the next period
        return collect(1:number_of_subperiods(inputs)+1)
    elseif hydro_balance_subperiod_resolution(inputs) ==
           Configurations_HydroBalanceSubperiodResolution.AGGREGATED_SUBPERIODS
        # In this case the first subperiod is the only one in the period and the second subperiod is only used to represent
        # the final volume of the period.
        return [1, 2]
    end
end

function fill_whether_hydro_unit_is_associated_with_some_virtual_reservoir!(inputs::AbstractInputs, idx::Int)
    if !any_elements(inputs, VirtualReservoir)
        inputs.collections.hydro_unit.is_associated_with_some_virtual_reservoir[idx] = false
    else
        hydro_units_associated_with_some_virtual_reservoir = union(virtual_reservoir_hydro_unit_indices(inputs)...)
        inputs.collections.hydro_unit.is_associated_with_some_virtual_reservoir[idx] =
            idx in hydro_units_associated_with_some_virtual_reservoir
    end
    return nothing
end

"""
    hydro_unit_generation_file(inputs::AbstractInputs)

Return the hydro generation time series file for all hydro units.
"""
hydro_unit_generation_file(inputs::AbstractInputs) = "hydro_generation"

"""
    hydro_unit_opportunity_cost_file(inputs::AbstractInputs)

Return the hydro opportunity cost time series file for all hydro units.
"""
hydro_unit_opportunity_cost_file(inputs::AbstractInputs) = "hydro_opportunity_cost"

"""
    has_min_outflow(hydro_unit::HydroUnit, idx::Int) 

Check if the Hydro Unit at index 'idx' has a minimum outflow.
"""
has_min_outflow(hydro_unit::HydroUnit, idx::Int) = hydro_unit.min_outflow[idx] > 0

"""
    has_commitment(hydro_unit::HydroUnit, idx::Int)

Check if the Hydro Unit at index 'idx' has commitment.
"""
has_commitment(hydro_unit::HydroUnit, idx::Int) =
    hydro_unit.has_commitment[idx] == HydroUnit_HasCommitment.HAS_COMMITMENT

"""
    operates_with_reservoir(hydro_unit::HydroUnit, idx::Int)

Check if the Hydro Unit at index 'idx' operates with reservoir.
"""
operates_with_reservoir(hydro_unit::HydroUnit, idx::Int) =
    hydro_unit.operation_type[idx] == HydroUnit_OperationType.RESERVOIR

"""
    operates_as_run_of_river(hydro_unit::HydroUnit, idx::Int)

Check if the Hydro Unit at index 'idx' operates as run of river.
"""
operates_as_run_of_river(hydro_unit::HydroUnit, idx::Int) =
    hydro_unit.operation_type[idx] == HydroUnit_OperationType.RUN_OF_RIVER

"""
    is_associated_with_some_virtual_reservoir(hydro_unit::HydroUnit, idx::Int)

Check if the Hydro Unit at index 'idx' is associated with some virtual reservoir.
"""
is_associated_with_some_virtual_reservoir(hydro_unit::HydroUnit, idx::Int) =
    hydro_unit.is_associated_with_some_virtual_reservoir[idx]

"""
    hydro_volume_from_previous_period(inputs::AbstractInputs, period::Int, scenario::Int)

Get the hydro volume from the previous period.

If the period is the first one, the initial volume is returned. Otherwise, it is read from the serialized results of the previous stage.
"""
function hydro_volume_from_previous_period(inputs::AbstractInputs, period::Int, scenario::Int)
    if period == 1
        return inputs.collections.hydro_unit.initial_volume
    else
        volume = read_serialized_clearing_variable(
            inputs,
            RunTime_ClearingSubproblem.EX_POST_PHYSICAL,
            :hydro_volume;
            period = period - 1,
            scenario = scenario,
        )
        # The volume at the end of the period is the first subperiod of the next period
        return volume.data[end, :]
    end
end

function hydro_unit_zone_index(inputs::AbstractInputs, idx::Int)
    return bus_zone_index(inputs, hydro_unit_bus_index(inputs, idx))
end
