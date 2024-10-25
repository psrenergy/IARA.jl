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
# Input definition
# ---------------------------------------------------------------------
"""
    Collections

Collection of all input collections.

"""
@kwdef mutable struct Collections <: AbstractCollections
    configurations::Configurations = Configurations()
    renewable_unit::RenewableUnit = RenewableUnit()
    hydro_unit::HydroUnit = HydroUnit()
    thermal_unit::ThermalUnit = ThermalUnit()
    zone::Zone = Zone()
    bus::Bus = Bus()
    demand_unit::DemandUnit = DemandUnit()
    dc_line::DCLine = DCLine()
    branch::Branch = Branch()
    battery_unit::BatteryUnit = BatteryUnit()
    asset_owner::AssetOwner = AssetOwner()
    gauging_station::GaugingStation = GaugingStation()
    bidding_group::BiddingGroup = BiddingGroup()
    virtual_reservoir::VirtualReservoir = VirtualReservoir()
end

@kwdef mutable struct Caches
    templates_for_time_series_files_have_been_generated::Bool = false
    templates_for_waveguide_files_have_been_generated::Bool = false
end

@kwdef mutable struct Inputs <: AbstractInputs
    db::DatabaseSQLite
    args::Args
    time_series::TimeSeriesViewsFromExternalFiles = TimeSeriesViewsFromExternalFiles()
    collections::Collections = Collections()
    caches::Caches = Caches()
end

"""
    migration_dir()

Return the path to the migration directory.
"""
function get_migration_dir()
    return joinpath(dirname(@__DIR__), "database", "migrations")
end

"""
    create_study!(
        case_path::String; 
        kwargs...
    )

`create_study!` creates a new study and returns a `PSRClassesInterface.PSRDatabaseSQLite.DatabaseSQLite` object.

Required arguments:

  - `PATH::String`: the path where the study will be created
  - `number_of_periods::Int`: the number of periods in the study
  - `number_of_scenarios::Int`: the number of scenarios in the study
  - `number_of_subperiods::Int`: the number of subperiods in the study
  - `demand_deficit_cost::Float64`: the cost of demand deficit in `R\$\\MWh`
  - `yearly_discount_rate::Float64`: the yearly discount rate
  - `subperiod_duration_in_hours::Vector{Float64}`: subperiod duration in hours (one entry for each subperiod)
Optional arguments:

  - `period_type::Int`: the type of the period
  - `subperiod_duration_in_hours::Vector{Float64}`: the duration of each subperiod in hours
  - `loop_subperiods_for_thermal_constraints::Int`
  - `number_of_nodes::Int`: the number of nodes in the study
  - `iteration_limit::Int`: the maximum number of iterations of SDDP algorithm
  - `initial_date_time::Dates.DateTime`: the initial `Dates.DateTime` of the study
  - `run_mode::Int`
  - `policy_graph_type::Configurations_PolicyGraphType`: the the policy graph, of type [`IARA.Configurations_PolicyGraphType`](@ref)
  - `use_binary_variables::Int`: whether to use binary variables
  - `yearly_duration_in_hours::Float64`: the duration of a year in hours
  - `hydro_minimum_outflow_violation_cost::Float64`: the cost of hydro minimum outflow violation in `[\$/m³/s]`
  - `hydro_spillage_cost::Float64`: the cost of hydro spillage in `[\$/hm³]`
  - `aggregate_buses_for_strategic_bidding::Int`: whether to aggregate buses for strategic bidding (0 or 1)
  - `parp_max_lags::Int`: the maximum number of lags in the PAR(p) model
  - `inflow_source::Int`
"""
function create_study!(case_path::String; kwargs...)
    migration_dir = get_migration_dir()
    @assert isdir(migration_dir)

    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    sql_typed_kwargs[:label] = "Configuration"

    db = PSRI.create_study(
        PSRI.PSRDatabaseSQLiteInterface(),
        joinpath(case_path, "study.iara");
        force = true,
        path_migrations_directory = migration_dir,
        sql_typed_kwargs...,
    )

    return db
end

"""
    load_study(case_path::String; read_only::Bool = true)

Open the database file and return a database object.

Required arguments:
  - `case_path::String`: Path to the case folder.
  - `read_only::Bool`: Whether the database should be opened in read-only mode. Default is `true`.
"""
function load_study(case_path::String; read_only::Bool = true)
    return PSRI.load_study(
        PSRI.PSRDatabaseSQLiteInterface(),
        joinpath(case_path, "study.iara");
        read_only,
    )
end

"""
    close_study!(db::DatabaseSQLite)

Closes the database.
"""
function close_study!(db::DatabaseSQLite)
    PSRI.PSRDatabaseSQLite.close!(db)
    return nothing
end

"""
    load_inputs(args::Args)

Initialize the inputs from the database.
"""
function load_inputs(args::Args)
    println("Loading inputs from $(args.path)")

    db = load_study(args.path)
    inputs = Inputs(; db, args)

    PSRBridge.initialize!(inputs)

    # Initialize or allocate all fields from collections
    initialize!(inputs)
    close_study!(inputs.db)
    db_temp = load_study(args.path; read_only = false)
    read_files_to_database!(inputs, db_temp)
    close_study!(db_temp)
    inputs.db = load_study(args.path)

    fill_caches!(inputs)

    log_inputs(inputs)

    return inputs
end

function read_files_to_database!(inputs::Inputs, db_temp::DatabaseSQLite)
    if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS &&
       virtual_reservoir_waveguide_source(inputs) == Configurations_VirtualReservoirWaveguideSource.USER_PROVIDED &&
       waveguide_user_provided_source(inputs) == Configurations_WaveguideUserProvidedSource.CSV_FILE
        read_waveguide_points_from_file_to_db(inputs, db_temp)
        load_new_attributes_from_db!(inputs, db_temp)
    end
    return nothing
end

function load_new_attributes_from_db!(inputs::Inputs, db_temp)
    load_new_attributes_from_db!(inputs.collections.hydro_unit, db_temp)
    return nothing
end

function initialize!(inputs::Inputs)
    # Initialize all collections
    for fieldname in fieldnames(Collections)
        initialize!(getfield(inputs.collections, fieldname), inputs)
    end

    validate(inputs)

    # Fit PAR(p) and generate scenarios
    if !read_inflow_from_file(inputs)
        generate_inflow_scenarios(inputs)
    end

    # Load time series from files
    try
        initialize_time_series_from_external_files(inputs)
    catch e
        clean_up(inputs)
        rethrow(e)
    end

    return nothing
end

"""
    update_time_series_from_db!(inputs::Inputs, period::Int)

Update the time series stored inside db file for the given period.
"""
function update_time_series_from_db!(inputs::Inputs, period::Int)
    period_date_time = date_time_from_period(inputs, period)
    for fieldname in fieldnames(Collections)
        collection = getfield(inputs.collections, fieldname)
        update_time_series_from_db!(collection, inputs.db, period_date_time)
    end
    return nothing
end

"""
    validate(inputs::Inputs)    

validate that the inputs are consistent through all periods.
"""
function validate(inputs)
    num_errors = 0

    for period in periods(inputs)
        num_errors_in_period = 0
        update_time_series_from_db!(inputs, period)
        for fieldname in fieldnames(Collections)
            num_errors_in_period += validate(getfield(inputs.collections, fieldname))
        end
        if num_errors_in_period > 0
            period_date_time = date_time_from_period(inputs, period)
            @error(
                "Input collections have $(num_errors_in_period) validation errors in period $(period) ($(period_date_time))."
            )
        end
        num_errors += num_errors_in_period
    end

    # Put the time controller in the first period
    update_time_series_from_db!(inputs, 1)

    # Validate relations 
    num_errors += validate_relations(inputs)

    if num_errors > 0
        error("Input collections have $(num_errors) validation errors.")
    end
    return nothing
end

"""
    validate_relations(inputs)

Validate the problem inputs' relations.
"""
function validate_relations(inputs::Inputs)
    num_errors = 0

    for fieldname in fieldnames(Collections)
        num_errors += validate_relations(inputs, getfield(inputs.collections, fieldname))
    end

    return num_errors
end

function log_inputs(inputs::Inputs)
    println("")
    println("Case configurations")
    iara_log(inputs.collections.configurations)
    println("")
    println("Loaded collections")
    for fieldname in fieldnames(Collections)
        if fieldname == :configurations
            continue
        end
        collection = getfield(inputs.collections, fieldname)
        iara_log(collection)
    end
    println("")
    println("Time Series from external files")
    iara_log(inputs.time_series)
    println("")
    return nothing
end

"""
    fill_caches!(inputs::Inputs)

Store pre-calculated values for the collections.
"""

function fill_caches!(inputs::Inputs)
    if run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING &&
       clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
        fill_maximum_number_of_virtual_reservoir_bidding_segments!(inputs)
    end
    if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
        for vr in index_of_elements(inputs, VirtualReservoir)
            fill_waveguide_points!(inputs, vr)
            fill_water_to_energy_factors!(inputs, vr)
            fill_initial_energy_stock!(inputs, vr)
            fill_order_to_spill_excess_of_inflow!(inputs, vr)
        end
    end
    for h in index_of_elements(inputs, HydroUnit)
        fill_whether_hydro_unit_is_associated_with_some_virtual_reservoir!(inputs, h)
    end
    return nothing
end

# ---------------------------------------------------------------------
# Input getters
# ---------------------------------------------------------------------

"""
    path_case(db::DatabaseSQLite)

Return the path to the case.
"""
path_case(db::DatabaseSQLite) = dirname(PSRDatabaseSQLite.database_path(db))

"""
    buses_represented_for_strategic_bidding(inputs)

If the 'aggregate_buses_for_strategic_bidding' attribute is set to AGGREGATE, return [1].
Otherwise, return the index of all Buses.
"""
function buses_represented_for_strategic_bidding(inputs)
    if aggregate_buses_for_strategic_bidding(inputs)
        return [1]
    else
        return index_of_elements(inputs, Bus)
    end
end

"""
    time_series_inflow(inputs)

Return the inflow time series.
"""
function time_series_inflow(inputs)
    if !read_inflow_from_file(inputs)
        error("Inflow time series is not available when 'read_inflow_from_file' is set to false.")
    end
    return inputs.time_series.inflow
end

"""
    time_series_inflow(inputs, run_time_options, subscenario::Int)

Return the inflow time series for the given subscenario.
"""
function time_series_inflow(inputs, run_time_options, subscenario::Int)
    if is_ex_post_problem(run_time_options) && time_series_inflow(inputs).ex_post.reader !== nothing
        return time_series_inflow(inputs).ex_post[:, :, subscenario]
    else
        return time_series_inflow(inputs).ex_ante
    end
end

"""
    time_series_demand(inputs)

Return the demand time series.
"""
time_series_demand(inputs) = inputs.time_series.demand_unit

"""
    time_series_demand(inputs, run_time_options, subscenario::Int)

Return the demand time series for the given subscenario.
"""
function time_series_demand(inputs, run_time_options, subscenario::Int)
    if is_ex_post_problem(run_time_options) && time_series_demand(inputs).ex_post.reader !== nothing
        return time_series_demand(inputs).ex_post[:, :, subscenario]
    else
        return time_series_demand(inputs).ex_ante
    end
end

"""
    time_series_renewable_generation(inputs)

Return the renewable generation time series.
"""
time_series_renewable_generation(inputs) = inputs.time_series.renewable_generation

"""
    time_series_renewable_generation(inputs, run_time_options, subscenario::Int)

Return the renewable generation time series for the given subscenario.
"""
function time_series_renewable_generation(inputs, run_time_options, subscenario::Int)
    if is_ex_post_problem(run_time_options) && time_series_renewable_generation(inputs).ex_post.reader !== nothing
        return time_series_renewable_generation(inputs).ex_post[:, :, subscenario]
    else
        return time_series_renewable_generation(inputs).ex_ante
    end
end

"""
    time_series_spot_price(inputs)

Return the spot price time series.
"""
function time_series_spot_price(inputs)
    if run_mode(inputs) != Configurations_RunMode.PRICE_TAKER_BID
        error("Spot price time series is only available for PriceTakerBid run mode.")
    end
    return inputs.time_series.spot_price
end

"""
    time_series_quantity_offer(inputs)

Return the quantity offer time series.
"""
function time_series_quantity_offer(inputs)
    if run_mode(inputs) != Configurations_RunMode.STRATEGIC_BID
        error(
            "This function is only available for STRATEGIC_BID run mode. To access the quantity offer time series in MARKET_CLEARING run mode, use 'time_series_quantity_offer(inputs, period, scenario)'.",
        )
    end

    if run_mode(inputs) == Configurations_RunMode.STRATEGIC_BID && size(inputs.time_series.quantity_offer)[3] > 1
        error("Quantity offer time series is not available for StrategicBid run mode with multiple segments.")
    end

    return inputs.time_series.quantity_offer
end

function time_series_quantity_offer(
    inputs,
    period::Int,
    scenario::Int,
)
    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        error(
            "This function is only available for MARKET_CLEARING run mode. To access the quantity offer time series in STRATEGIC_BID run mode, use 'time_series_quantity_offer(inputs)'.",
        )
    end

    if read_bids_from_file(inputs)
        return inputs.time_series.quantity_offer
    elseif generate_heuristic_bids_for_clearing(inputs)
        quantity_offer, price_offer = read_serialized_heuristic_bids(inputs; period = period, scenario = scenario)
        return quantity_offer
    else
        error("Unrecognized bid source: $(clearing_bid_source(inputs))")
    end
end

"""
    time_series_price_offer(inputs)

Return the price offer time series.
"""
function time_series_price_offer(inputs)
    if run_mode(inputs) != Configurations_RunMode.STRATEGIC_BID
        error(
            "This function is only available for STRATEGIC_BID run mode. To access the price offer time series in MARKET_CLEARING run mode, use 'time_series_price_offer(inputs, period, scenario)'.",
        )
    end

    if run_mode(inputs) == Configurations_RunMode.STRATEGIC_BID && size(inputs.time_series.price_offer)[3] > 1
        error("Price offer time series is not available for StrategicBid run mode with multiple segments.")
    end
    return inputs.time_series.price_offer
end

function time_series_price_offer(
    inputs,
    period::Int,
    scenario::Int,
)
    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        error(
            "This function is only available for MARKET_CLEARING run mode. To access the price offer time series in STRATEGIC_BID run mode, use 'time_series_price_offer(inputs)'.",
        )
    end

    if read_bids_from_file(inputs)
        return inputs.time_series.price_offer
    elseif generate_heuristic_bids_for_clearing(inputs)
        quantity_offer, price_offer = read_serialized_heuristic_bids(inputs; period = period, scenario = scenario)
        return price_offer
    else
        error("Unrecognized bid source: $(clearing_bid_source(inputs))")
    end
end

"""
    time_series_quantity_offer_multihour(inputs)

Return the quantity offer multihour time series.
"""
function time_series_quantity_offer_multihour(inputs)
    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        error("Quantity offer multihour time series is only available for MarketClearing run mode.")
    end
    return inputs.time_series.quantity_offer_multihour
end

"""
    time_series_price_offer_multihour(inputs)

Return the price offer multihour time series.
"""
function time_series_price_offer_multihour(inputs)
    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        error("Price offer multihour time series is only available for MarketClearing run mode.")
    end
    return inputs.time_series.price_offer_multihour
end

"""
    time_series_parent_profile_multihour(inputs)

Return the parent profile multihour time series.
"""
function time_series_parent_profile_multihour(inputs)
    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        error("Parent profile multihour time series is only available for MarketClearing run mode.")
    end
    return inputs.time_series.parent_profile_multihour
end

"""
    time_series_complementary_grouping_multihour(inputs)

Return the complementary grouping multihour time series.
"""
function time_series_complementary_grouping_multihour(inputs)
    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        error("Complementary grouping multihour time series is only available for MarketClearing run mode.")
    end
    return inputs.time_series.complementary_grouping_multihour
end

"""
    time_series_minimum_activation_level_multihour(inputs)

Return the minimum activation level multihour time series.
"""

function time_series_minimum_activation_level_multihour(inputs)
    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        error("Minimum activation level multihour time series is only available for MarketClearing run mode.")
    end
    return inputs.time_series.minimum_activation_level_multihour
end
"""
    time_series_virtual_reservoir_quantity_offer(inputs)

Return the virtual reservoir quantity offer time series.
"""
function time_series_virtual_reservoir_quantity_offer(inputs)
    if run_mode(inputs) != Configurations_RunMode.STRATEGIC_BID
        error(
            "This function is only available for STRATEGIC_BID run mode. To access the virtual reservoir quantity offer time series in MARKET_CLEARING run mode, use 'time_series_virtual_reservoir_quantity_offer(inputs, period, scenario)'.",
        )
    end
    return inputs.time_series.virtual_reservoir_quantity_offer
end

function time_series_virtual_reservoir_quantity_offer(
    inputs,
    period::Int,
    scenario::Int,
)
    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        error(
            "This function is only available for MARKET_CLEARING run mode. To access the virtual reservoir quantity offer time series in STRATEGIC_BID run mode, use 'time_series_virtual_reservoir_quantity_offer(inputs)'.",
        )
    end

    if read_bids_from_file(inputs)
        return inputs.time_series.virtual_reservoir_quantity_offer
    elseif generate_heuristic_bids_for_clearing(inputs)
        quantity_offer, price_offer =
            read_serialized_virtual_reservoir_heuristic_bids(inputs; period = period, scenario = scenario)
        return quantity_offer
    else
        error("Unrecognized bid source: $(clearing_bid_source(inputs))")
    end
end

"""
    time_series_virtual_reservoir_price_offer(inputs)

Return the virtual reservoir price offer time series.
"""
function time_series_virtual_reservoir_price_offer(inputs)
    if run_mode(inputs) != Configurations_RunMode.STRATEGIC_BID
        error(
            "This function is only available for STRATEGIC_BID run mode. To access the virtual reservoir price offer time series in MARKET_CLEARING run mode, use 'time_series_virtual_reservoir_price_offer(inputs, period, scenario)'.",
        )
    end
    return inputs.time_series.virtual_reservoir_price_offer
end

function time_series_virtual_reservoir_price_offer(
    inputs,
    period::Int,
    scenario::Int,
)
    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        error(
            "This function is only available for MARKET_CLEARING run mode. To access the virtual reservoir price offer time series in STRATEGIC_BID run mode, use 'time_series_virtual_reservoir_price_offer(inputs)'.",
        )
    end

    if read_bids_from_file(inputs)
        return inputs.time_series.virtual_reservoir_price_offer
    elseif generate_heuristic_bids_for_clearing(inputs)
        quantity_offer, price_offer =
            read_serialized_virtual_reservoir_heuristic_bids(inputs; period = period, scenario = scenario)
        return price_offer
    else
        error("Unrecognized bid source: $(clearing_bid_source(inputs))")
    end
end

"""
    time_series_elastic_demand_price(inputs)

Return the elastic demand price time series.
"""
time_series_elastic_demand_price(inputs) = inputs.time_series.elastic_demand_price

"""
    time_series_hydro_generation(inputs)

Return the hydro generation time series.
"""
time_series_hydro_generation(inputs) = inputs.time_series.hydro_generation

"""
    time_series_hydro_opportunity_cost(inputs)

Return the hydro opportunity cost time series.
"""
time_series_hydro_opportunity_cost(inputs) = inputs.time_series.hydro_opportunity_cost

"""
    time_series_inflow_noise(inputs)

Return the inflow noise time series.
"""
function time_series_inflow_noise(inputs)
    if read_inflow_from_file(inputs)
        error("Inflow noise is not available when 'read_inflow_from_file' is set to true.")
    end
    return inputs.time_series.inflow_noise
end

"""
    time_series_inflow_period_average(inputs)

Return the inflow period average time series.
"""
time_series_inflow_period_average(inputs) = inputs.time_series.inflow_period_average

"""
    time_series_inflow_period_std_dev(inputs)

Return the inflow period standard deviation time series.
"""
time_series_inflow_period_std_dev(inputs) = inputs.time_series.inflow_period_std_dev

"""
    time_series_parp_coefficients(inputs)

Return the PAR(p) coefficients time series.
"""
time_series_parp_coefficients(inputs) = inputs.time_series.parp_coefficients

"""
    hour_subperiod_map(inputs)

Return a vector of integers mapping each hour to a single subperiod.
"""
hour_subperiod_map(inputs) = inputs.time_series.hour_subperiod_mapping.hour_subperiod_map

"""
    subperiod_hour_map(inputs)

Return a vector of vectors, mapping each subperiod to multiple hours.
"""
subperiod_hour_map(inputs) = inputs.time_series.hour_subperiod_mapping.subperiod_hour_map
