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
    BiddingGroup

Collection representing the bidding groups in the system.
"""
@collection @kwdef mutable struct BiddingGroup <: AbstractCollection
    label::Vector{String} = []
    risk_factor::Vector{Vector{Float64}} = []
    segment_fraction::Vector{Vector{Float64}} = []
    ex_post_adjust_mode::Vector{BiddingGroup_ExPostAdjustMode.T} = []
    # index of the asset_owner to which the bidding group belongs in the collection AssetOwner
    asset_owner_index::Vector{Int} = []
    bid_price_limit_source::Vector{BiddingGroup_BidPriceLimitSource.T} = []
    fixed_cost::Vector{Float64} = []
    quantity_bid_file::String = ""
    price_bid_file::String = ""
    quantity_bid_profile_file::String = ""
    price_bid_profile_file::String = ""
    parent_profile_file::String = ""
    complementary_grouping_profile_file::String = ""
    minimum_activation_level_profile_file::String = ""
    bid_price_limit_justified_independent_file::String = ""
    bid_price_limit_non_justified_independent_file::String = ""
    bid_price_limit_justified_profile_file::String = ""
    bid_price_limit_non_justified_profile_file::String = ""
    bid_justifications_file::String = ""
    # caches
    _has_generation_besides_virtual_reservoirs::Vector{Bool} = []
    _number_of_valid_bidding_segments::Vector{Int} = Int[]
    _maximum_number_of_bidding_segments::Int = 0
    _number_of_valid_profiles::Vector{Int} = Int[]
    _maximum_number_of_profiles::Int = 0
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(bidding_group::BiddingGroup, inputs::AbstractInputs)

Initialize the BiddingGroup collection from the database.
"""
function initialize!(bidding_group::BiddingGroup, inputs::AbstractInputs)
    num_bidding_groups = PSRI.max_elements(inputs.db, "BiddingGroup")
    if num_bidding_groups == 0
        return nothing
    end

    bidding_group.label = PSRI.get_parms(inputs.db, "BiddingGroup", "label")
    bidding_group.asset_owner_index = PSRI.get_map(inputs.db, "BiddingGroup", "AssetOwner", "id")
    bidding_group.bid_price_limit_source =
        convert_to_enum.(
            PSRI.get_parms(inputs.db, "BiddingGroup", "bid_price_limit_source"),
            BiddingGroup_BidPriceLimitSource.T,
        )
    bidding_group.fixed_cost = PSRI.get_parms(inputs.db, "BiddingGroup", "fixed_cost")

    # Load vectors
    bidding_group.risk_factor = PSRI.get_vectors(inputs.db, "BiddingGroup", "risk_factor")
    bidding_group.segment_fraction = PSRI.get_vectors(inputs.db, "BiddingGroup", "segment_fraction")

    for i in 1:num_bidding_groups
        if isempty(bidding_group.segment_fraction[i])
            bidding_group.segment_fraction[i] = [1.0]
        end
        if isempty(bidding_group.risk_factor[i])
            bidding_group.risk_factor[i] = [0.0]
        end
    end

    bidding_group.ex_post_adjust_mode =
        convert_to_enum.(
            PSRI.get_parms(inputs.db, "BiddingGroup", "ex_post_adjust_mode"),
            BiddingGroup_ExPostAdjustMode.T,
        )

    # Load time series files
    bidding_group.quantity_bid_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "quantity_bid")
    bidding_group.price_bid_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "price_bid")
    bidding_group.quantity_bid_profile_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "quantity_bid_profile")
    bidding_group.price_bid_profile_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "price_bid_profile")
    bidding_group.parent_profile_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "parent_profile")
    bidding_group.complementary_grouping_profile_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "complementary_grouping_profile")
    bidding_group.minimum_activation_level_profile_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "minimum_activation_level_profile")
    bidding_group.bid_price_limit_justified_independent_file =
        PSRDatabaseSQLite.read_time_series_file(
            inputs.db,
            "BiddingGroup",
            "bid_price_limit_justified_independent",
        )
    bidding_group.bid_price_limit_non_justified_independent_file =
        PSRDatabaseSQLite.read_time_series_file(
            inputs.db,
            "BiddingGroup",
            "bid_price_limit_non_justified_independent",
        )
    bidding_group.bid_price_limit_justified_profile_file =
        PSRDatabaseSQLite.read_time_series_file(
            inputs.db,
            "BiddingGroup",
            "bid_price_limit_justified_profile",
        )
    bidding_group.bid_price_limit_non_justified_profile_file =
        PSRDatabaseSQLite.read_time_series_file(
            inputs.db,
            "BiddingGroup",
            "bid_price_limit_non_justified_profile",
        )
    bidding_group.bid_justifications_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "bid_justifications")

    # Caches
    bidding_group._has_generation_besides_virtual_reservoirs = zeros(Bool, num_bidding_groups)

    update_time_series_from_db!(bidding_group, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(bidding_group::BiddingGroup, db::DatabaseSQLite, period_date_time::DateTime)

Update the BiddingGroup time series from the database.
"""
function update_time_series_from_db!(bidding_group::BiddingGroup, db::DatabaseSQLite, period_date_time::DateTime)
    return nothing
end

"""
    add_bidding_group!(db::DatabaseSQLite; kwargs...)

Add a BiddingGroup to the database.

$(PSRDatabaseSQLite.collection_docstring(model_directory(), "BiddingGroup"))

Example:
```julia
IARA.add_bidding_group!(
    db;
    label = "bg_1",
    assetowner_id = "asset_owner_1",
    risk_factor = [0.5],
    segment_fraction = [1.0],
    independent_bid_max_segments = 2,
)
```
"""
function add_bidding_group!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "BiddingGroup"; sql_typed_kwargs...)
    return nothing
end

"""
    update_bidding_group!(db::DatabaseSQLite, label::String; kwargs...)

Update the BiddingGroup named 'label' in the database.
"""
function update_bidding_group!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "BiddingGroup",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_bidding_group_relation!(db::DatabaseSQLite, bidding_group_label::String; collection::String, relation_type::String, related_label::String)

Update the BiddingGroup named 'label' in the database.

Example:
```julia
IARA.update_bidding_group_relation!(
    db,
    "bg_1";
    collection = "AssetOwner",
    relation_type = "id",
    related_label = "asset_owner_2",
)
```
"""
function update_bidding_group_relation!(
    db::DatabaseSQLite,
    bidding_group_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "BiddingGroup",
        collection,
        bidding_group_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    update_bidding_group_vectors!(db::DatabaseSQLite, label::String; kwargs...)

Update the vectors of the Bidding Group named 'label' in the database.
"""
function update_bidding_group_vectors!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRDatabaseSQLite.update_vector_parameters!(
            db,
            "BiddingGroup",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    validate(bidding_group::BiddingGroup)

Validate the BiddingGroup's parameters. Returns the number of errors found.
"""
function validate(bidding_group::BiddingGroup)
    num_errors = 0
    for i in 1:length(bidding_group)
        if isempty(bidding_group.label[i])
            @error("BiddingGroup Label cannot be empty.")
            num_errors += 1
        end
        if any(bidding_group.risk_factor[i] .< 0)
            @warn(
                "Bidding group $(bidding_group.label[i]) has negative risk factors $(bidding_group.risk_factor[i]). If this is intentional, ignore this warning."
            )
        end
        if all(is_null.(bidding_group.segment_fraction[i]))
            continue
        end
        if any(is_null.(bidding_group.segment_fraction[i]))
            @error(
                "Segment fraction vector has both null and non-null values for Bidding group $(bidding_group.label[i])."
            )
        end
    end
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, bidding_group::BiddingGroup)

Validate the BiddingGroup's context within the inputs. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, bidding_group::BiddingGroup)
    num_errors = 0

    # Check if bid files are necessary, and if so, if they are provided
    if read_bids_from_file(inputs) && any(bidding_group._has_generation_besides_virtual_reservoirs)
        if (bidding_group.quantity_bid_file == "" || bidding_group.price_bid_file == "") &&
           (bidding_group.quantity_bid_profile_file == "" || bidding_group.price_bid_profile_file == "")
            @error(
                "Bid files are required for some bidding groups, but the quantity or price bid files are missing."
            )
            num_errors += 1
        end
    end

    # Check if the assigned AssetOwner exists in the database
    asset_owners = index_of_elements(inputs, AssetOwner)
    for i in 1:length(bidding_group)
        if !(bidding_group.asset_owner_index[i] in asset_owners)
            @error(
                "BiddingGroup $(bidding_group.label[i]) AssetOwner ID $(bidding_group.asset_owner_index[i]) not found."
            )
            num_errors += 1
        end
    end

    # Check if the bid price limit files are necessary, and if so, if they are provided
    if must_read_bid_price_limit_file(inputs)
        if has_any_simple_bids(inputs)
            if bidding_group.bid_price_limit_justified_independent_file == ""
                @error(
                    "Bid price limit source is set to EXTERNAL_UNVALIDATED_BID for some bidding group, but the bid price limit justified independent file is missing."
                )
                num_errors += 1
            end
            if bidding_group.bid_price_limit_non_justified_independent_file == ""
                @error(
                    "Bid price limit source is set to EXTERNAL_UNVALIDATED_BID for some bidding group, but the bid price limit non-justified independent file is missing."
                )
                num_errors += 1
            end
        end
        if has_any_profile_bids(inputs)
            if bidding_group.bid_price_limit_justified_profile_file == ""
                @error(
                    "Bid price limit source is set to EXTERNAL_UNVALIDATED_BID for some bidding group, but the bid price limit justified profile file is missing."
                )
                num_errors += 1
            end
            if bidding_group.bid_price_limit_non_justified_profile_file == ""
                @error(
                    "Bid price limit source is set to EXTERNAL_UNVALIDATED_BID for some bidding group, but the bid price limit non-justified profile file is missing."
                )
                num_errors += 1
            end
        end
    end

    # Check if all bidding_groups have units assigned to them. If not, some run_modes and options are not available.
    thermal_units = index_of_elements(inputs, ThermalUnit)
    hydro_units = index_of_elements(inputs, HydroUnit)
    renewable_units = index_of_elements(inputs, RenewableUnit)
    battery_units = index_of_elements(inputs, BatteryUnit)
    demand_units = index_of_elements(inputs, DemandUnit)
    number_of_units_per_bidding_group = zeros(Int, length(bidding_group))
    for t in thermal_units
        bg_index = thermal_unit_bidding_group_index(inputs, t)
        if !is_null(bg_index)
            number_of_units_per_bidding_group[bg_index] += 1
        end
    end
    for h in hydro_units
        bg_index = hydro_unit_bidding_group_index(inputs, h)
        if !is_null(bg_index)
            number_of_units_per_bidding_group[bg_index] += 1
        end
    end
    for r in renewable_units
        bg_index = renewable_unit_bidding_group_index(inputs, r)
        if !is_null(bg_index)
            number_of_units_per_bidding_group[bg_index] += 1
        end
    end
    for b in battery_units
        bg_index = battery_unit_bidding_group_index(inputs, b)
        if !is_null(bg_index)
            number_of_units_per_bidding_group[bg_index] += 1
        end
    end
    has_demand_with_bidding_group = false
    for d in demand_units
        bg_index = demand_unit_bidding_group_index(inputs, d)
        if !is_null(bg_index)
            has_demand_with_bidding_group = true
            number_of_units_per_bidding_group[bg_index] += 1
        end
        if is_market_clearing(inputs)
            if !is_null(bg_index) && is_flexible(inputs.collections.demand_unit, d)
                @error("Demand unit $(d) is flexible and this is not allowed for bidding groups.")
            end
            if !is_null(bg_index) && is_inelastic(inputs.collections.demand_unit, d)
                @error("Demand unit $(d) is inelastic and this is not allowed for bidding groups.")
            end
            if is_elastic(inputs.collections.demand_unit, d) && is_null(bg_index)
                @error("Elastic demand unit $(d) is not assigned to any bidding group.")
            end
        end
    end
    if has_demand_with_bidding_group && demand_unit_elastic_demand_price_file(inputs) != "" &&
       is_market_clearing(inputs) && read_bids_from_file(inputs)
        @warn("""
          Elastic demand price file ignored - demand bids are already provided via bidding groups.
          (Bidding group prices take precedence over the file. Remove the file link to avoid this warning.)
          """)
    end
    if any(number_of_units_per_bidding_group .== 0)
        if run_mode(inputs) == RunMode.SINGLE_PERIOD_HEURISTIC_BID
            @error(
                "Some bidding groups do not have any units assigned to them. This is not allowed for the SINGLE_PERIOD_HEURISTIC_BID run mode."
            )
            num_errors += 1
        end
        if is_market_clearing(inputs) && generate_heuristic_bids_for_clearing(inputs)
            @error(
                "Some bidding groups do not have any units assigned to them. This is not allowed when creating heuristic bids for the MARKET_CLEARING run mode."
            )
            num_errors += 1
        end
    end
    supply_security_agent =
        findfirst(inputs.collections.asset_owner.price_type .== AssetOwner_PriceType.SUPPLY_SECURITY_AGENT)
    if !isnothing(supply_security_agent)
        if supply_security_agent in bidding_group.asset_owner_index
            bg_indices = findall(bidding_group.asset_owner_index .== supply_security_agent)
            @error(
                "The supply security agent cannot be assigned to a bidding group. It is assigned to $(bidding_group.label[bg_indices])."
            )
            num_errors += 1
        end
    end

    if construction_type_ex_post_physical(inputs) != Configurations_ConstructionType.SKIP ||
       construction_type_ex_post_commercial(inputs) != Configurations_ConstructionType.SKIP
        bg_indices = index_of_elements(inputs, BiddingGroup)
        for bg in bg_indices
            if bidding_group_has_renewable_units(inputs, bg) &&
               bidding_group_ex_post_adjust(inputs, bg) ==
               BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_GENERATION
                # If the bidding group has renewable units and the ex post adjustment mode is proportional to ex post generation
                # over ex ante generation, you're not bidding all the energy available in the ex post problem
                @warn "Bidding group $(bidding_group_label(inputs, bg)) has renewable units and the ex post adjustment mode is proportional to ex post generation over ex ante generation. This means that you're not bidding all the energy available in the ex post problem. To avoid this distortion, consider splitting thermal and renewable units into different bidding groups."
            end

            if bidding_group_has_thermal_units(inputs, bg) &&
               bidding_group_ex_post_adjust(inputs, bg) ==
               BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID
                # If the bidding group has thermal units and the ex post adjustment mode is proportional to ex post generation
                # over ex ante bid, you're not bidding all the energy available in the ex post problem
                @warn "Bidding group $(bidding_group_label(inputs, bg)) has thermal units and the ex post adjustment mode is proportional to ex post generation over ex ante bid. This means that you're bidding all the thermal energy available in the ex post problem. To avoid this distortion, consider splitting thermal and renewable units into different bidding groups."
            end
        end
    end
    return num_errors
end

function fill_bidding_group_has_generation_besides_virtual_reservoirs!(inputs::AbstractInputs)
    # A bidding group has no variables if all of its units are hydro units associated with virtual reservoirs

    number_of_units = zeros(Int, number_of_elements(inputs, BiddingGroup))
    number_of_hydro_units_in_virtual_reservoirs = zeros(Int, number_of_elements(inputs, BiddingGroup))

    hydro_units = index_of_elements(inputs, HydroUnit)
    thermal_units = index_of_elements(inputs, ThermalUnit)
    renewable_units = index_of_elements(inputs, RenewableUnit)
    battery_units = index_of_elements(inputs, BatteryUnit)
    demand_units = index_of_elements(inputs, DemandUnit)

    for h in hydro_units
        bg_index = hydro_unit_bidding_group_index(inputs, h)
        if !is_null(bg_index)
            number_of_units[bg_index] += 1
            if clearing_hydro_representation(inputs) ==
               Configurations_VirtualReservoirBidProcessing.HEURISTIC_BID_FROM_WATER_VALUES &&
               is_associated_with_some_virtual_reservoir(inputs.collections.hydro_unit, h)
                number_of_hydro_units_in_virtual_reservoirs[bg_index] += 1
            end
        end
    end

    for t in thermal_units
        bg_index = thermal_unit_bidding_group_index(inputs, t)
        if !is_null(bg_index)
            number_of_units[bg_index] += 1
        end
    end

    for r in renewable_units
        bg_index = renewable_unit_bidding_group_index(inputs, r)
        if !is_null(bg_index)
            number_of_units[bg_index] += 1
        end
    end

    for b in battery_units
        bg_index = battery_unit_bidding_group_index(inputs, b)
        if !is_null(bg_index)
            number_of_units[bg_index] += 1
        end
    end

    for d in demand_units
        bg_index = demand_unit_bidding_group_index(inputs, d)
        if !is_null(bg_index)
            number_of_units[bg_index] += 1
        end
    end

    for i in 1:number_of_elements(inputs, BiddingGroup)
        if number_of_units[i] == 0
            inputs.collections.bidding_group._has_generation_besides_virtual_reservoirs[i] = true
        elseif number_of_units[i] - number_of_hydro_units_in_virtual_reservoirs[i] > 0
            inputs.collections.bidding_group._has_generation_besides_virtual_reservoirs[i] = true
        end
        # If the bidding group has a positive number of units but all of them are hydro units associated with virtual reservoirs, the generation is all guided by the virtual reservoirs
    end

    return nothing
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

bidding_group_has_hydro_units(inputs::AbstractInputs, bg::Int) = bg in hydro_unit_bidding_group_index(inputs)

bidding_group_has_thermal_units(inputs::AbstractInputs, bg::Int) = bg in thermal_unit_bidding_group_index(inputs)

bidding_group_has_renewable_units(inputs::AbstractInputs, bg::Int) = bg in renewable_unit_bidding_group_index(inputs)

has_generation_besides_virtual_reservoirs(bg::BiddingGroup, i::Int) = bg._has_generation_besides_virtual_reservoirs[i]

bidding_group_ex_post_adjust(inputs::AbstractInputs, i::Int) = inputs.collections.bidding_group.ex_post_adjust_mode[i]

function has_any_simple_bids(inputs::AbstractInputs)
    return maximum_number_of_bg_bidding_segments(inputs) > 0
end

function has_any_profile_bids(inputs::AbstractInputs)
    return maximum_number_of_profiles(inputs) > 0
end

"""
    has_any_profile_complex_bids(inputs::AbstractInputs)

Return true if the bidding group has any profile complex input files.
"""
function has_any_profile_complex_bids(inputs::AbstractInputs)
    return has_any_profile_bids(inputs) &&
           (
        has_any_profile_complex_input_files(inputs) ||
        generate_heuristic_bids_for_clearing(inputs)
    )
end

function has_any_bid_simple_input_files(inputs::AbstractInputs)
    return bidding_group_quantity_bid_file(inputs) != "" && bidding_group_price_bid_file(inputs) != ""
end

function has_any_profile_input_files(inputs::AbstractInputs)
    return bidding_group_quantity_bid_profile_file(inputs) != "" &&
           bidding_group_price_bid_profile_file(inputs) != ""
end

"""
    has_any_profile_complex_input_files(inputs::AbstractInputs)

Return true if the bidding group has any profile complex input files.
"""
function has_any_profile_complex_input_files(inputs::AbstractInputs)
    return bidding_group_parent_profile_file(inputs) != "" &&
           bidding_group_complementary_grouping_profile_file(inputs) != "" &&
           bidding_group_minimum_activation_level_profile_file(inputs) != ""
end

function maximum_number_of_bg_bidding_segments(inputs::AbstractInputs)
    return inputs.collections.bidding_group._maximum_number_of_bidding_segments
end

function number_of_bg_valid_bidding_segments(inputs::AbstractInputs, bg::Int)
    return inputs.collections.bidding_group._number_of_valid_bidding_segments[bg]
end

function update_maximum_number_of_bg_bidding_segments!(inputs::AbstractInputs, value::Int)
    previous_value = inputs.collections.bidding_group._maximum_number_of_bidding_segments
    if previous_value == 0
        inputs.collections.bidding_group._maximum_number_of_bidding_segments = value
    elseif previous_value != value
        @warn(
            "The maximum number of bidding segments for bidding groups is already set to $(previous_value). It will not be updated to $(value)."
        )
    end
    return nothing
end

function update_number_of_bg_valid_bidding_segments!(inputs::AbstractInputs, values::Vector{Int})
    if length(inputs.collections.bidding_group._number_of_valid_bidding_segments) == 0
        inputs.collections.bidding_group._number_of_valid_bidding_segments = zeros(
            Int,
            length(index_of_elements(inputs, BiddingGroup)),
        )
    end
    inputs.collections.bidding_group._number_of_valid_bidding_segments .= values
    return nothing
end

function maximum_number_of_profiles(inputs::AbstractInputs)
    return inputs.collections.bidding_group._maximum_number_of_profiles
end

function number_of_valid_profiles(inputs::AbstractInputs, bg::Int)
    return inputs.collections.bidding_group._number_of_valid_profiles[bg]
end

function update_maximum_number_of_profiles!(inputs::AbstractInputs, value::Int)
    previous_value = inputs.collections.bidding_group._maximum_number_of_profiles
    if previous_value == 0
        inputs.collections.bidding_group._maximum_number_of_profiles = value
    elseif previous_value != value
        @warn(
            "The maximum number of profiles for bidding groups is already set to $(previous_value). It will not be updated to $(value)."
        )
    end
    return nothing
end

function update_number_of_valid_profiles!(inputs::AbstractInputs, values::Vector{Int})
    if length(inputs.collections.bidding_group._number_of_valid_profiles) == 0
        inputs.collections.bidding_group._number_of_valid_profiles = zeros(
            Int,
            length(index_of_elements(inputs, BiddingGroup)),
        )
    end
    inputs.collections.bidding_group._number_of_valid_profiles .= values
    return nothing
end

function use_bid_price_limits_from_file(inputs::AbstractInputs, bidding_group_index::Int)
    return bidding_group_bid_price_limit_source(inputs)[bidding_group_index] ==
           BiddingGroup_BidPriceLimitSource.READ_FROM_FILE
end

function must_read_bid_price_limit_file(inputs::AbstractInputs)
    return any(
        bidding_group_bid_price_limit_source(inputs) .==
        BiddingGroup_BidPriceLimitSource.READ_FROM_FILE,
    ) && validate_bidding_group_bids(inputs)
end

function bids_justifications_exist(inputs::AbstractInputs)
    return bidding_group_bid_justifications_file(inputs) != "" &&
           isfile(joinpath(path_case(inputs), bidding_group_bid_justifications_file(inputs)))
end
