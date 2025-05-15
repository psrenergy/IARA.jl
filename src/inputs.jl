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

Struct of all input collections.
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
    interconnection::Interconnection = Interconnection()
    branch::Branch = Branch()
    battery_unit::BatteryUnit = BatteryUnit()
    asset_owner::AssetOwner = AssetOwner()
    gauging_station::GaugingStation = GaugingStation()
    bidding_group::BiddingGroup = BiddingGroup()
    virtual_reservoir::VirtualReservoir = VirtualReservoir()
end

"""
    Inputs

Struct of all input data.
"""
@kwdef mutable struct Inputs <: AbstractInputs
    db::DatabaseSQLite
    args::Args
    time_series::TimeSeriesViewsFromExternalFiles = TimeSeriesViewsFromExternalFiles()
    collections::Collections = Collections()
end

"""
    create_study!(
        case_path::String; 
        kwargs...
    )

`create_study!` creates a new study and returns a `PSRClassesInterface.PSRDatabaseSQLite.DatabaseSQLite` object.

$(PSRDatabaseSQLite.collection_docstring(model_directory(), "Configuration"))
"""
function create_study!(case_path::String; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    sql_typed_kwargs[:label] = "Configuration"

    db = PSRI.create_study(
        PSRI.PSRDatabaseSQLiteInterface(),
        joinpath(case_path, "study.iara");
        force = true,
        path_migrations_directory = migrations_directory(),
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
    if read_only
        return PSRI.load_study(
            PSRI.PSRDatabaseSQLiteInterface(),
            joinpath(case_path, "study.iara");
            read_only,
        )
    else
        # If the database is not read-only, we need to provide the migrations directory
        # and possibly apply the migrations so that users can run with this version of IARA.
        path_migrations = migrations_directory()
        return PSRI.load_study(
            PSRI.PSRDatabaseSQLiteInterface(),
            joinpath(case_path, "study.iara"),
            path_migrations,
        )
    end
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
    db = load_study(args.path)
    inputs = Inputs(; db, args)

    PSRBridge.initialize!(inputs)

    # Initialize or allocate all fields from collections
    initialize!(inputs)

    fill_caches!(inputs)

    return inputs
end

"""
    summarize(path::String; run_mode::String = "market-clearing")

Summarize the case based on the `run_mode` passed.

$AVAILABLE_RUN_MODES_MESSAGE
"""
function summarize(path::String; run_mode::String = "market-clearing")
    args = Args(path, parse_run_mode(run_mode))
    initialize(args)
    inputs = load_inputs(args)
    try
        log_inputs(inputs)
    finally
        clean_up(inputs)
    end
    return nothing
end

"""
    load_new_attributes_from_db!(inputs::Inputs, db_temp::DatabaseSQLite)   

Load new attributes from the database.
"""
function load_new_attributes_from_db!(inputs::Inputs, db_temp)
    load_new_attributes_from_db!(inputs.collections.hydro_unit, db_temp)
    return nothing
end

"""
    initialize!(inputs::Inputs)

Initialize the inputs.
"""
function initialize!(inputs::Inputs)
    # Initialize all collections
    for fieldname in fieldnames(Collections)
        initialize!(getfield(inputs.collections, fieldname), inputs)
    end

    # Validate all collections
    try
        validate(inputs)
    catch e
        clean_up(inputs)
        rethrow(e)
    end

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
    validate(path::String; run_mode::String = "market-clearing")

Validate the case based on the `run_mode` passed.

$AVAILABLE_RUN_MODES_MESSAGE
"""
function validate(path::String; run_mode::String = "market-clearing")
    args = Args(path, parse_run_mode(run_mode))
    initialize(args)
    inputs = load_inputs(args)
    try
        validate(inputs)
    finally
        clean_up(inputs)
    end
    return true
end

"""
    validate(inputs)    

validate that the inputs are consistent through all periods.
"""
function validate(inputs)
    num_errors = 0

    # Configurations is only validated once
    num_errors += validate(inputs.collections.configurations)

    for period in periods(inputs)
        num_errors_in_period = 0
        update_time_series_from_db!(inputs, period)
        for fieldname in fieldnames(Collections)
            if fieldname == :configurations
                continue
            end
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
    num_errors += advanced_validations(inputs)

    if num_errors > 0
        error("There are $(num_errors) validation errors in the input collections.")
    end

    return nothing
end

"""
    advanced_validations(inputs::Inputs)

Validate the problem inputs' relations.
"""
function advanced_validations(inputs::Inputs)
    num_errors = 0

    for fieldname in fieldnames(Collections)
        num_errors += advanced_validations(inputs, getfield(inputs.collections, fieldname))
    end

    return num_errors
end

function log_inputs(inputs::Inputs)
    @info("")
    @info("Execution options")
    iara_log(inputs.args)
    iara_log_configurations(inputs)
    @info("")
    @info("Collections")
    for fieldname in fieldnames(Collections)
        if fieldname == :configurations
            continue
        end
        collection = getfield(inputs.collections, fieldname)
        iara_log(collection)
    end
    @info("")
    @info("Time Series from external files")
    iara_log(inputs.time_series)
    @info("")
    @info("Cuts file:")
    if has_fcf_cuts_to_read(inputs)
        @info("   $(fcf_cuts_file(inputs))")
    else
        @info("   No cuts file")
    end
    @info("")
    return nothing
end

"""
    fill_caches!(inputs::Inputs)

Store pre-calculated values for the collections.
"""

function fill_caches!(inputs::Inputs)
    if (is_market_clearing(inputs) || run_mode(inputs) == RunMode.SINGLE_PERIOD_HEURISTIC_BID) &&
       clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
        fill_maximum_number_of_virtual_reservoir_bidding_segments!(inputs)
    end
    if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
        for vr in index_of_elements(inputs, VirtualReservoir)
            fill_waveguide_points!(inputs, vr)
            fill_water_to_energy_factors!(inputs, vr)
            fill_initial_energy_account!(inputs, vr)
        end
    end
    for h in index_of_elements(inputs, HydroUnit)
        fill_whether_hydro_unit_is_associated_with_some_virtual_reservoir!(inputs, h)
    end
    if run_mode(inputs) == RunMode.PRICE_TAKER_BID ||
       run_mode(inputs) == RunMode.STRATEGIC_BID
        update_number_of_bid_segments!(inputs, 1)
    end
    fill_bidding_group_has_generation_besides_virtual_reservoirs!(inputs)
    fill_plot_strings_dict!(inputs)
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
    buses_represented_for_strategic_bidding(inputs::Inputs)

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
    time_series_inflow(inputs::Inputs, run_time_options::RunTimeOptions; subscenario::Int)

Return the inflow time series for the given subscenario.
"""
function time_series_inflow(inputs, run_time_options; subscenario::Union{Int, Nothing} = nothing)
    if is_ex_post_problem(run_time_options)
        if read_ex_post_inflow_file(inputs)
            if isnothing(subscenario)
                error("Always provide a subscenario when reading the ex-post inflow file during ex-post problems.")
            end
            return inputs.time_series.inflow.ex_post[:, :, subscenario]
        elseif read_ex_ante_inflow_file(inputs)
            return inputs.time_series.inflow.ex_ante.data
        end
    else
        if read_ex_ante_inflow_file(inputs)
            return inputs.time_series.inflow.ex_ante.data
        elseif read_ex_post_inflow_file(inputs)
            return mean(inputs.time_series.inflow.ex_post.data; dims = 3)[:, :, 1]
        end
    end
    return error(
        "The inflow time series is not available when the option inflow_scenarios_files is set to NONE. The PAR(p) model should be used instead.",
    )
end

"""
    time_series_demand(inputs::Inputs, run_time_options::RunTimeOptions; subscenario::Int)

Return the demand time series for the given subscenario.
"""
function time_series_demand(inputs, run_time_options; subscenario::Union{Int, Nothing} = nothing)
    if is_ex_post_problem(run_time_options)
        if read_ex_post_demand_file(inputs)
            if isnothing(subscenario)
                error("Always provide a subscenario when reading the ex-post demand file during ex-post problems.")
            end
            return inputs.time_series.demand.ex_post[:, :, subscenario]
        elseif read_ex_ante_demand_file(inputs)
            return inputs.time_series.demand.ex_ante.data
        end
    else
        if read_ex_ante_demand_file(inputs)
            return inputs.time_series.demand.ex_ante.data
        elseif read_ex_post_demand_file(inputs)
            return mean(inputs.time_series.demand.ex_post.data; dims = 3)[:, :, 1]
        end
    end
    return ones(number_of_elements(inputs, DemandUnit), number_of_subperiods(inputs))
end

"""
    time_series_renewable_generation(inputs::Inputs, run_time_options::RunTimeOptions; subscenario::Int)

Return the renewable generation time series for the given subscenario.
"""
function time_series_renewable_generation(inputs, run_time_options; subscenario::Union{Int, Nothing} = nothing)
    if is_ex_post_problem(run_time_options)
        if read_ex_post_renewable_file(inputs)
            if isnothing(subscenario)
                error(
                    "Always provide a subscenario when reading the ex-post renewable generation file during ex-post problems.",
                )
            end
            return inputs.time_series.renewable_generation.ex_post[:, :, subscenario]
        elseif read_ex_ante_renewable_file(inputs)
            return inputs.time_series.renewable_generation.ex_ante.data
        end
    else
        if read_ex_ante_renewable_file(inputs)
            return inputs.time_series.renewable_generation.ex_ante.data
        elseif read_ex_post_renewable_file(inputs)
            return mean(inputs.time_series.renewable_generation.ex_post.data; dims = 3)[:, :, 1]
        end
    end
    return ones(number_of_elements(inputs, RenewableUnit), number_of_subperiods(inputs))
end

"""
    time_series_spot_price(inputs::Inputs)

Return the spot price time series.
"""
function time_series_spot_price(inputs)
    if run_mode(inputs) != RunMode.PRICE_TAKER_BID
        error("Spot price time series is only available for PriceTakerBid run mode.")
    end
    return inputs.time_series.spot_price
end

"""
    time_series_quantity_offer(inputs::Inputs)

Return the quantity offer time series.
"""
function time_series_quantity_offer(inputs)
    if run_mode(inputs) != RunMode.STRATEGIC_BID
        error(
            "This function is only available for STRATEGIC_BID run mode. To access the quantity offer time series in MARKET_CLEARING run mode, use 'time_series_quantity_offer(inputs, period, scenario)'.",
        )
    end

    if run_mode(inputs) == RunMode.STRATEGIC_BID && size(inputs.time_series.quantity_offer)[3] > 1
        error("Quantity offer time series is not available for StrategicBid run mode with multiple segments.")
    end

    return inputs.time_series.quantity_offer
end

"""
    time_series_quantity_offer(inputs::Inputs, period::Int, scenario::Int)

Return the quantity offer time series for the given period and scenario.
"""
function time_series_quantity_offer(
    inputs,
    period::Int,
    scenario::Int,
)
    if !is_market_clearing(inputs)
        error(
            "This function is only available for MARKET_CLEARING run mode. To access the quantity offer time series in STRATEGIC_BID run mode, use 'time_series_quantity_offer(inputs)'.",
        )
    end

    if read_bids_from_file(inputs)
        return inputs.time_series.quantity_offer
    elseif generate_heuristic_bids_for_clearing(inputs)
        quantity_offer, price_offer = read_serialized_heuristic_bids(inputs; period = period, scenario = scenario)
        quantity_view = BidsView{Float64}()
        quantity_view.data = quantity_offer
        return quantity_view
    else
        error("Unrecognized bid source: $(bid_data_source(inputs))")
    end
end

"""
    time_series_price_offer(inputs::Inputs)

Return the price offer time series.
"""
function time_series_price_offer(inputs)
    if run_mode(inputs) != RunMode.STRATEGIC_BID
        error(
            "This function is only available for STRATEGIC_BID run mode. To access the price offer time series in MARKET_CLEARING run mode, use 'time_series_price_offer(inputs, period, scenario)'.",
        )
    end

    if run_mode(inputs) == RunMode.STRATEGIC_BID && size(inputs.time_series.price_offer)[3] > 1
        error("Price offer time series is not available for StrategicBid run mode with multiple segments.")
    end
    return inputs.time_series.price_offer
end

"""
    time_series_price_offer(inputs, period::Int, scenario::Int)

Return the price offer time series for the given period and scenario.
"""
function time_series_price_offer(
    inputs,
    period::Int,
    scenario::Int,
)
    if !is_market_clearing(inputs)
        error(
            "This function is only available for MARKET_CLEARING run mode. To access the price offer time series in STRATEGIC_BID run mode, use 'time_series_price_offer(inputs)'.",
        )
    end

    if read_bids_from_file(inputs)
        return inputs.time_series.price_offer
    elseif generate_heuristic_bids_for_clearing(inputs)
        quantity_offer, price_offer = read_serialized_heuristic_bids(inputs; period = period, scenario = scenario)
        price_view = BidsView{Float64}()
        price_view.data = price_offer
        return price_view
    else
        error("Unrecognized bid source: $(bid_data_source(inputs))")
    end
end

"""
    time_series_quantity_offer_profile(inputs::Inputs)

Return the quantity offer profile time series.
"""
function time_series_quantity_offer_profile(
    inputs,
    period::Int,
    scenario::Int,
)
    if !is_market_clearing(inputs)
        error("Quantity offer profile time series is only available for MarketClearing run mode.")
    end
    if read_bids_from_file(inputs)
        return inputs.time_series.quantity_offer_profile
    elseif generate_heuristic_bids_for_clearing(inputs)
        error("Quantity offer profile time series is not available for heuristic bids.")
    else
        error("Unrecognized bid source: $(bid_data_source(inputs))")
    end
end

"""
    time_series_price_offer_profile(inputs::Inputs)

Return the price offer profile time series.
"""
function time_series_price_offer_profile(
    inputs,
    period::Int,
    scenario::Int,
)
    if !is_market_clearing(inputs)
        error("Price offer profile time series is only available for MarketClearing run mode.")
    end
    if read_bids_from_file(inputs)
        return inputs.time_series.price_offer_profile
    elseif generate_heuristic_bids_for_clearing(inputs)
        error("Price offer profile time series is not available for heuristic bids.")
    else
        error("Unrecognized bid source: $(bid_data_source(inputs))")
    end
end

"""
    time_series_parent_profile(inputs::Inputs)

Return the parent profile profile time series.
"""
function time_series_parent_profile(
    inputs,
    period::Int,
    scenario::Int,
)
    if !is_market_clearing(inputs)
        error("Parent profile profile time series is only available for MarketClearing run mode.")
    end
    if read_bids_from_file(inputs)
        return inputs.time_series.parent_profile
    elseif generate_heuristic_bids_for_clearing(inputs)
        error("Parent profile time series is not available for heuristic bids.")
    else
        error("Unrecognized bid source: $(bid_data_source(inputs))")
    end
end

"""
    time_series_complementary_grouping_profile(inputs::Inputs)

Return the complementary grouping profile time series.
"""
function time_series_complementary_grouping_profile(
    inputs,
    period::Int,
    scenario::Int,
)
    if !is_market_clearing(inputs)
        error("Complementary grouping profile time series is only available for MarketClearing run mode.")
    end
    if read_bids_from_file(inputs)
        return inputs.time_series.complementary_grouping_profile
    elseif generate_heuristic_bids_for_clearing(inputs)
        error("Complementary grouping profile time series is not available for heuristic bids.")
    else
        error("Unrecognized bid source: $(bid_data_source(inputs))")
    end
end

"""
    time_series_minimum_activation_level_profile(inputs::Inputs)

Return the minimum activation level profile time series.
"""

function time_series_minimum_activation_level_profile(
    inputs,
    period::Int,
)
    if !is_market_clearing(inputs)
        error("Minimum activation level profile time series is only available for MarketClearing run mode.")
    end
    if read_bids_from_file(inputs)
        return inputs.time_series.minimum_activation_level_profile
    elseif generate_heuristic_bids_for_clearing(inputs)
        error("Minimum activation level profile time series is not available for heuristic bids.")
    else
        error("Unrecognized bid source: $(bid_data_source(inputs))")
    end
end
"""
    time_series_virtual_reservoir_quantity_offer(inputs::Inputs)

Return the virtual reservoir quantity offer time series.
"""
function time_series_virtual_reservoir_quantity_offer(inputs)
    if run_mode(inputs) != RunMode.STRATEGIC_BID
        error(
            "This function is only available for STRATEGIC_BID run mode. To access the virtual reservoir quantity offer time series in MARKET_CLEARING run mode, use 'time_series_virtual_reservoir_quantity_offer(inputs, period, scenario)'.",
        )
    end
    return inputs.time_series.virtual_reservoir_quantity_offer
end

"""
    time_series_virtual_reservoir_quantity_offer(inputs, period::Int, scenario::Int)

Return the virtual reservoir quantity offer time series for the given period and scenario.
"""
function time_series_virtual_reservoir_quantity_offer(
    inputs,
    period::Int,
    scenario::Int,
)
    if !is_market_clearing(inputs)
        error(
            "This function is only available for MARKET_CLEARING run mode. To access the virtual reservoir quantity offer time series in STRATEGIC_BID run mode, use 'time_series_virtual_reservoir_quantity_offer(inputs)'.",
        )
    end

    if read_bids_from_file(inputs)
        return inputs.time_series.virtual_reservoir_quantity_offer
    elseif generate_heuristic_bids_for_clearing(inputs)
        quantity_offer, price_offer =
            read_serialized_virtual_reservoir_heuristic_bids(inputs; period = period, scenario = scenario)
        quantity_view = VirtualReservoirBidsView{Float64}()
        quantity_view.data = quantity_offer
        return quantity_view
    else
        error("Unrecognized bid source: $(bid_data_source(inputs))")
    end
end

"""
    time_series_virtual_reservoir_price_offer(inputs)

Return the virtual reservoir price offer time series.
"""
function time_series_virtual_reservoir_price_offer(inputs)
    if run_mode(inputs) != RunMode.STRATEGIC_BID
        error(
            "This function is only available for STRATEGIC_BID run mode. To access the virtual reservoir price offer time series in MARKET_CLEARING run mode, use 'time_series_virtual_reservoir_price_offer(inputs, period, scenario)'.",
        )
    end
    return inputs.time_series.virtual_reservoir_price_offer
end

"""
    time_series_virtual_reservoir_price_offer(inputs, period::Int, scenario::Int)

Return the virtual reservoir price offer time series for the given period and scenario.
"""
function time_series_virtual_reservoir_price_offer(
    inputs,
    period::Int,
    scenario::Int,
)
    if !is_market_clearing(inputs)
        error(
            "This function is only available for MARKET_CLEARING run mode. To access the virtual reservoir price offer time series in STRATEGIC_BID run mode, use 'time_series_virtual_reservoir_price_offer(inputs)'.",
        )
    end

    if read_bids_from_file(inputs)
        return inputs.time_series.virtual_reservoir_price_offer
    elseif generate_heuristic_bids_for_clearing(inputs)
        quantity_offer, price_offer =
            read_serialized_virtual_reservoir_heuristic_bids(inputs; period = period, scenario = scenario)
        price_view = VirtualReservoirBidsView{Float64}()
        price_view.data = price_offer
        return price_view
    else
        error("Unrecognized bid source: $(bid_data_source(inputs))")
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

"""
    period_season_map(inputs)

Return a 3-element vector with the current season, sample and next_subscenario given the current period and scenario.
"""
period_season_map_from_file(inputs) = inputs.time_series.period_season_map
