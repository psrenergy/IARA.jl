#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

@collection @kwdef mutable struct VirtualReservoir <: AbstractCollection
    label::Vector{String} = []
    hydro_unit_indices::Vector{Vector{Int}} = []
    asset_owner_indices::Vector{Vector{Int}} = []
    asset_owners_inflow_allocation::Vector{Vector{Float64}} = []
    number_of_waveguide_points_for_file_template::Vector{Int} = []
    quantity_offer_file::String = ""
    price_offer_file::String = ""
    # caches
    initial_energy_stock::Vector{Vector{Float64}} = [] # TODO: rethink the name "stock"
    waveguide_points::Vector{Matrix{Float64}} = []
    water_to_energy_factors::Vector{Vector{Float64}} = []
    order_to_spill_excess_of_inflow::Vector{Vector{Int}} = []
    maximum_number_of_virtual_reservoir_bidding_segments::Int = 0
end

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
    # Load time series files
    virtual_reservoir.quantity_offer_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "VirtualReservoir", "quantity_offer")
    virtual_reservoir.price_offer_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "VirtualReservoir", "price_offer")
    # Initialize caches
    virtual_reservoir.initial_energy_stock =
        [zeros(Float64, length(index_of_elements(inputs, AssetOwner))) for vr in 1:num_virtual_reservoirs]
    virtual_reservoir.waveguide_points =
        [zeros(Float64, length(virtual_reservoir.hydro_unit_indices[vr]), 0) for vr in 1:num_virtual_reservoirs]
    virtual_reservoir.water_to_energy_factors =
        [zeros(Float64, length(index_of_elements(inputs, HydroUnit))) for vr in 1:num_virtual_reservoirs]
    virtual_reservoir.order_to_spill_excess_of_inflow =
        [zeros(Int, length(virtual_reservoir.hydro_unit_indices[vr])) for vr in 1:num_virtual_reservoirs]

    update_time_series_from_db!(virtual_reservoir, inputs.db, initial_date_time(inputs))

    return nothing
end

function validate(virtual_reservoir::VirtualReservoir)
    num_errors = 0
    for i in 1:length(virtual_reservoir)
        virtual_reservoir_label = virtual_reservoir.label[i]
        if length(virtual_reservoir.hydro_unit_indices[i]) == 0
            @error "Virtual reservoir $(virtual_reservoir_label) must be associated with at least one hydro unit."
            num_errors += 1
        end
        for j in 1:length(virtual_reservoir.hydro_unit_indices[i])
            if is_null(virtual_reservoir.hydro_unit_indices[i][j])
                @error "Hydro unit reference for virtual reservoir $(virtual_reservoir_label) must be fulfilled."
                num_errors += 1
            end
        end
        if length(virtual_reservoir.asset_owner_indices[i]) == 0
            @error "Virtual reservoir $(virtual_reservoir_label) must have at least one asset owner."
            num_errors += 1
        end
        for j in 1:length(virtual_reservoir.asset_owner_indices[i])
            if is_null(virtual_reservoir.asset_owners_inflow_allocation[i][j])
                @error "Inflow allocation for asset owner $(virtual_reservoir.asset_owner_indices[i][j]) in virtual reservoir $(virtual_reservoir_label) must be defined."
                num_errors += 1
            end
            if virtual_reservoir.asset_owners_inflow_allocation[i][j] <= 0 ||
               virtual_reservoir.asset_owners_inflow_allocation[i][j] > 1
                @error "Inflow allocation for asset owner $(virtual_reservoir.asset_owner_indices[i][j]) in virtual reservoir $(virtual_reservoir_label) must be greater than zero and less than or equal to one."
                num_errors += 1
            end
        end
        if sum(virtual_reservoir.asset_owners_inflow_allocation[i]) != 1
            @error "Sum of inflow allocation for virtual reservoir $(virtual_reservoir_label) must be equal to one. Found $(sum(virtual_reservoir.asset_owners_inflow_allocation[i]))."
            num_errors += 1
        end
        if !is_null(virtual_reservoir.number_of_waveguide_points_for_file_template[i]) &&
           virtual_reservoir.number_of_waveguide_points_for_file_template[i] <= 0
            @error "Number of waveguide points for file template for virtual reservoir $(virtual_reservoir_label) must be greater than zero."
            num_errors += 1
        end
    end
    return num_errors
end

function validate_relations(inputs::AbstractInputs, virtual_reservoir::VirtualReservoir)
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
            @error "Hydro unit $(hydro_unit_label) is associated with the following virtual reservoirs: $(virtual_reservoir_label[virtual_reservoirs_including_hydro_unit]). It must be associated with only one virtual reservoir."
            num_errors += 1
        elseif length(virtual_reservoirs_including_hydro_unit) == 0
            @warn "Hydro unit $(hydro_unit_label) is not associated with any virtual reservoir."
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

function add_virtual_reservoir!(db::DatabaseSQLite; kwargs...)
    PSRI.create_element!(db, "VirtualReservoir"; kwargs...)
    return nothing
end

function update_virtual_reservoir!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    for (attribute, value) in kwargs
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

number_of_waveguide_points(inputs::AbstractInputs, vr::Int) =
    size(inputs.collections.virtual_reservoir.waveguide_points[vr], 2)

function virtual_reservoir_asset_owners_inflow_allocation(inputs::AbstractInputs, vr::Int, ao::Int)
    @assert ao in virtual_reservoir_asset_owner_indices(inputs, vr)
    ao_index_among_asset_owners = findfirst(inputs.collections.virtual_reservoir.asset_owner_indices[vr] .== ao)
    return inputs.collections.virtual_reservoir.asset_owners_inflow_allocation[vr][ao_index_among_asset_owners]
end

maximum_number_of_virtual_reservoir_bidding_segments(inputs::AbstractInputs) =
    if run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING && generate_heuristic_bids_for_clearing(inputs)
        inputs.collections.virtual_reservoir.maximum_number_of_virtual_reservoir_bidding_segments
    else
        inputs.collections.configurations.number_of_virtual_reservoir_bidding_segments
    end
