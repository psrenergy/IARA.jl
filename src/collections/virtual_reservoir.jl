#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

"""
    VirtualReservoir

Collection representing the virtual reservoir.
"""
@collection @kwdef mutable struct VirtualReservoir <: AbstractCollection
    label::Vector{String} = []
    hydro_unit_indices::Vector{Vector{Int}} = []
    asset_owner_indices::Vector{Vector{Int}} = []
    asset_owners_inflow_allocation::Vector{Vector{Float64}} = []
    asset_owners_initial_energy_account_share::Vector{Vector{Float64}} = []
    number_of_waveguide_points_for_file_template::Vector{Int} = []
    quantity_offer_file::String = ""
    price_offer_file::String = ""
    # caches
    initial_energy_account::Vector{Vector{Float64}} = []
    waveguide_points::Vector{Matrix{Float64}} = []
    water_to_energy_factors::Vector{Vector{Float64}} = []
    _number_of_valid_bidding_segments::Vector{Int} = Int[]
    _maximum_number_of_bidding_segments::Int = 0
end

"""
    initialize!(virtual_reservoir::VirtualReservoir, inputs::AbstractInputs)

Initialize the VirtualReservoir collection from the database.
"""
function initialize!(virtual_reservoir::VirtualReservoir, inputs::AbstractInputs)
    num_virtual_reservoirs = PSRI.max_elements(inputs.db, "VirtualReservoir")
    if num_virtual_reservoirs == 0
        return nothing
    end

    virtual_reservoir.label = PSRI.get_parms(inputs.db, "VirtualReservoir", "label")
    virtual_reservoir.hydro_unit_indices = PSRI.get_vector_map(inputs.db, "VirtualReservoir", "HydroUnit", "id")
    virtual_reservoir.asset_owner_indices = PSRI.get_vector_map(inputs.db, "VirtualReservoir", "AssetOwner", "id")
    virtual_reservoir.asset_owners_inflow_allocation =
        PSRDatabaseSQLite.read_vector_parameters(inputs.db, "VirtualReservoir", "inflow_allocation")
    virtual_reservoir.number_of_waveguide_points_for_file_template =
        PSRI.get_parms(inputs.db, "VirtualReservoir", "number_of_waveguide_points_for_file_template")
    virtual_reservoir.asset_owners_initial_energy_account_share =
        PSRDatabaseSQLite.read_vector_parameters(inputs.db, "VirtualReservoir", "initial_energy_account_share")
    # Load time series files
    virtual_reservoir.quantity_offer_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "VirtualReservoir", "quantity_offer")
    virtual_reservoir.price_offer_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "VirtualReservoir", "price_offer")
    # Initialize caches
    virtual_reservoir.initial_energy_account =
        [zeros(Float64, length(index_of_elements(inputs, AssetOwner))) for vr in 1:num_virtual_reservoirs]
    virtual_reservoir.waveguide_points =
        [zeros(Float64, length(virtual_reservoir.hydro_unit_indices[vr]), 0) for vr in 1:num_virtual_reservoirs]
    virtual_reservoir.water_to_energy_factors =
        [zeros(Float64, length(index_of_elements(inputs, HydroUnit))) for vr in 1:num_virtual_reservoirs]

    update_time_series_from_db!(virtual_reservoir, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    validate(virtual_reservoir::VirtualReservoir)

Validate the VirtualReservoir's parameters. Return the number of errors found.
"""
function validate(virtual_reservoir::VirtualReservoir)
    num_errors = 0
    for i in 1:length(virtual_reservoir)
        virtual_reservoir_label = virtual_reservoir.label[i]
        if length(virtual_reservoir.hydro_unit_indices[i]) == 0
            @error("Virtual reservoir $(virtual_reservoir_label) must be associated with at least one hydro unit.")
            num_errors += 1
        end
        for j in 1:length(virtual_reservoir.hydro_unit_indices[i])
            if is_null(virtual_reservoir.hydro_unit_indices[i][j])
                @error("Hydro unit reference for virtual reservoir $(virtual_reservoir_label) must be fulfilled.")
                num_errors += 1
            end
        end
        if length(virtual_reservoir.asset_owner_indices[i]) == 0
            @error("Virtual reservoir $(virtual_reservoir_label) must have at least one asset owner.")
            num_errors += 1
        end
        for j in 1:length(virtual_reservoir.asset_owner_indices[i])
            if is_null(virtual_reservoir.asset_owners_inflow_allocation[i][j])
                @error(
                    "Inflow allocation for asset owner $(virtual_reservoir.asset_owner_indices[i][j]) in virtual reservoir $(virtual_reservoir_label) must be defined."
                )
                num_errors += 1
            end
            if virtual_reservoir.asset_owners_inflow_allocation[i][j] <= 0 ||
               virtual_reservoir.asset_owners_inflow_allocation[i][j] > 1
                @error(
                    "Inflow allocation for asset owner $(virtual_reservoir.asset_owner_indices[i][j]) in virtual reservoir $(virtual_reservoir_label) must be greater than zero and less than or equal to one."
                )
                num_errors += 1
            end
            if virtual_reservoir.asset_owners_initial_energy_account_share[i][j] < 0 ||
               virtual_reservoir.asset_owners_initial_energy_account_share[i][j] > 1
                @error(
                    "Initial energy account share for asset owner $(virtual_reservoir.asset_owner_indices[i][j]) in virtual reservoir $(virtual_reservoir_label) must be greater than or equal to zero and less than or equal to one."
                )
                num_errors += 1
            end
        end
        if sum(virtual_reservoir.asset_owners_inflow_allocation[i]) != 1
            @error(
                "Sum of inflow allocation for virtual reservoir $(virtual_reservoir_label) must be equal to one. Found $(sum(virtual_reservoir.asset_owners_inflow_allocation[i]))."
            )
            num_errors += 1
        end
        sum_of_initial_energy_account_share = sum(virtual_reservoir.asset_owners_initial_energy_account_share[i])
        if !is_null(sum_of_initial_energy_account_share) && sum_of_initial_energy_account_share != 1
            @error(
                "Sum of initial energy account share for virtual reservoir $(virtual_reservoir_label) must be equal to one. Found $(sum(virtual_reservoir.asset_owners_initial_energy_account_share[i]))."
            )
            num_errors += 1
        end
        if !is_null(virtual_reservoir.number_of_waveguide_points_for_file_template[i]) &&
           virtual_reservoir.number_of_waveguide_points_for_file_template[i] <= 0
            @error(
                "Number of waveguide points for file template for virtual reservoir $(virtual_reservoir_label) must be greater than zero."
            )
            num_errors += 1
        end
        if !allunique(virtual_reservoir.hydro_unit_indices[i])
            @error(
                "Virtual reservoir $(virtual_reservoir_label) has duplicate hydro unit indices: $(virtual_reservoir.hydro_unit_indices[i]). Each hydro unit must be associated with a virtual reservoir only once."
            )
            num_errors += 1
        end
        if !allunique(virtual_reservoir.asset_owner_indices[i])
            @error(
                "Virtual reservoir $(virtual_reservoir_label) has duplicate asset owner indices: $(virtual_reservoir.asset_owner_indices[i]). Each asset owner must be associated with a virtual reservoir only once."
            )
            num_errors += 1
        end
    end
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, virtual_reservoir::VirtualReservoir)

Validate the VirtualReservoir within the inputs context. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, virtual_reservoir::VirtualReservoir)
    num_errors = 0
    if length(virtual_reservoir) == 0
        return 0
    end
    hydro_units = index_of_elements(inputs, HydroUnit)
    for h in hydro_units
        hydro_unit_label = inputs.collections.hydro_unit.label[h]
        virtual_reservoirs_including_hydro_unit =
            findall(vr -> h in virtual_reservoir.hydro_unit_indices[vr], 1:length(virtual_reservoir))
        if length(virtual_reservoirs_including_hydro_unit) > 1
            @error(
                "Hydro unit $(hydro_unit_label) is associated with the following virtual reservoirs: $(virtual_reservoir_label[virtual_reservoirs_including_hydro_unit]). It must be associated with only one virtual reservoir."
            )
            num_errors += 1
        elseif length(virtual_reservoirs_including_hydro_unit) == 0
            @warn("Hydro unit $(hydro_unit_label) is not associated with any virtual reservoir.")
        end
    end
    virtual_reservoir_initial_energy_account_share =
        inputs.collections.configurations.virtual_reservoir_initial_energy_account_share
    if virtual_reservoir_initial_energy_account_share ==
       Configurations_VirtualReservoirInitialEnergyAccount.CALCULATED_USING_ENERGY_ACCOUNT_SHARES
        for i in 1:length(virtual_reservoir)
            virtual_reservoir_label = virtual_reservoir.label[i]
            if any(is_null, virtual_reservoir.asset_owners_initial_energy_account_share[i])
                @error(
                    "Initial energy account share for virtual reservoir $(virtual_reservoir_label) must be defined for all asset owners."
                )
                num_errors += 1
            end
        end
    end
    supply_security_agent =
        findfirst(inputs.collections.asset_owner.price_type .== AssetOwner_PriceType.SUPPLY_SECURITY_AGENT)
    if !isnothing(supply_security_agent)
        for vr in 1:length(virtual_reservoir)
            if !(supply_security_agent in virtual_reservoir.asset_owner_indices[vr])
                @error(
                    "Supply security agent $(inputs.collections.asset_owner.label[supply_security_agent]) must be associated with virtual reservoir $(virtual_reservoir.label[vr])."
                )
                num_errors += 1
            else
                index_among_vr = findfirst(virtual_reservoir.asset_owner_indices[vr] .== supply_security_agent)
                if virtual_reservoir.asset_owners_inflow_allocation[vr][index_among_vr] > 0.0
                    @error(
                        "Supply security agent $(inputs.collections.asset_owner.label[supply_security_agent]) in virtual reservoir $(virtual_reservoir.label[vr]) must have an inflow allocation of zero."
                    )
                    num_errors += 1
                end
            end
        end
    end
    return num_errors
end

"""
    update_time_series_from_db!(virtual_reservoir::VirtualReservoir, db::DatabaseSQLite, period_date_time::DateTime)

Update the VirtualReservoir time series from the database.
"""
function update_time_series_from_db!(
    virtual_reservoir::VirtualReservoir,
    db::DatabaseSQLite,
    period_date_time::DateTime,
)
    return nothing
end

"""
    add_virtual_reservoir!(db::DatabaseSQLite; kwargs...)

Add a VirtualReservoir to the database.

$(PSRDatabaseSQLite.collection_docstring(model_directory(), "VirtualReservoir"))

Example:
```julia
IARA.add_virtual_reservoir!(db;
    label = "reservoir_1",
    assetowner_id = ["asset_owner_1", "asset_owner_2"],
    inflow_allocation = [0.4, 0.6],
    hydrounit_id = ["hydro_1", "hydro_2"],
)
```
"""
function add_virtual_reservoir!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "VirtualReservoir"; sql_typed_kwargs...)
    return nothing
end

"""
    update_virtual_reservoir!(db::DatabaseSQLite, label::String; kwargs...)

Update the VirtualReservoir named 'label' in the database.

Example:
```julia
IARA.update_virtual_reservoir!(db, "virtual_reservoir_1"; number_of_waveguide_points_for_file_template = 3)
```
"""
function update_virtual_reservoir!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "VirtualReservoir",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    number_of_waveguide_points(inputs::AbstractInputs, vr::Int)

Return the number of waveguide points for the VirtualReservoir `vr`.
"""
number_of_waveguide_points(inputs::AbstractInputs, vr::Int) =
    size(inputs.collections.virtual_reservoir.waveguide_points[vr], 2)

"""
    virtual_reservoir_asset_owners_inflow_allocation(inputs::AbstractInputs, vr::Int, ao::Int)

Return the inflow allocation of the asset owner `ao` in the VirtualReservoir `vr`.
"""
function virtual_reservoir_asset_owners_inflow_allocation(inputs::AbstractInputs, vr::Int, ao::Int)
    @assert ao in virtual_reservoir_asset_owner_indices(inputs, vr)
    ao_index_among_asset_owners = findfirst(inputs.collections.virtual_reservoir.asset_owner_indices[vr] .== ao)
    return inputs.collections.virtual_reservoir.asset_owners_inflow_allocation[vr][ao_index_among_asset_owners]
end

function virtual_reservoir_asset_owners_initial_energy_account_share(inputs::AbstractInputs, vr::Int, ao::Int)
    if virtual_reservoir_initial_energy_account_share(inputs) ==
       Configurations_VirtualReservoirInitialEnergyAccount.CALCULATED_USING_INFLOW_SHARES
        return virtual_reservoir_asset_owners_inflow_allocation(inputs, vr, ao)
    else
        @assert ao in virtual_reservoir_asset_owner_indices(inputs, vr)
        ao_index_among_asset_owners = findfirst(inputs.collections.virtual_reservoir.asset_owner_indices[vr] .== ao)
        return inputs.collections.virtual_reservoir.asset_owners_initial_energy_account_share[vr][ao_index_among_asset_owners]
    end
end

function virtual_reservoir_water_to_energy_factors(inputs::AbstractInputs, vr::Int, h::Int)
    @assert h in virtual_reservoir_hydro_unit_indices(inputs, vr)
    # the water_to_energy_factors field contains indices of all hydro units, filled with NaN for the ones not
    # associated with vr. It follows a different rule from virtual_reservoir_asset_owners_inflow_allocation, it should be
    # changed to be the same.
    return inputs.collections.virtual_reservoir.water_to_energy_factors[vr][h]
end

function maximum_number_of_vr_bidding_segments(inputs::AbstractInputs)
    return inputs.collections.virtual_reservoir._maximum_number_of_bidding_segments
end

function number_of_vr_valid_bidding_segments(inputs::AbstractInputs, vr::Int)
    return inputs.collections.virtual_reservoir._number_of_valid_bidding_segments[vr]
end

function update_maximum_number_of_vr_bidding_segments!(inputs::AbstractInputs, value::Int)
    previous_value = inputs.collections.virtual_reservoir._maximum_number_of_bidding_segments
    if previous_value == 0
        inputs.collections.virtual_reservoir._maximum_number_of_bidding_segments = value
    elseif previous_value != value
        @warn(
            "The maximum number of bidding segments for virtual reservoirs is already set to $(previous_value). It will not be updated to $(value)."
        )
    end
    return nothing
end

function update_number_of_vr_valid_bidding_segments!(inputs::AbstractInputs, values::Vector{Int})
    if length(inputs.collections.virtual_reservoir._number_of_valid_bidding_segments) == 0
        inputs.collections.virtual_reservoir._number_of_valid_bidding_segments = zeros(
            Int,
            length(index_of_elements(inputs, VirtualReservoir)),
        )
    end
    inputs.collections.virtual_reservoir._number_of_valid_bidding_segments .= values
    return nothing
end
