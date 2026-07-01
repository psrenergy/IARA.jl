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

Required arguments:

  - `label::String`: Label of the configuration <default `"Configuration"`>
  - `number_of_subscenarios::Int64`: Number of subscenarios in the configuration <default `1`>
  - `initial_date_time::String`: Initial date time of the configuration `[yyyy-MM-dd HH:mm]` <default `"2024-01-01"`>
  - `time_series_step::Int64`: Time series step of the configuration <default `0`>
  - `cycle_discount_rate::Float64`: Cycle discount rate of the configuration

  - `cycle_duration_in_hours::Float64`: Cycle duration in hours of the configuration <default `8760.0`>
  - `ex_post_physical_hydro_representation::Int64`: Ex post physical hydro representation of the configuration <default `0`>
  - `clearing_integer_variables::Int64`: Clearing integer variables of the configuration <default `0`>
  - `settlement_type::Int64`: Settlement type of the configuration <default `0`>
  - `make_whole_payments::Int64`: Make whole payments of the configuration <default `0`>
  - `number_of_periods::Int64`: Number of periods in the configuration <default `1`>
  - `number_of_scenarios::Int64`: Number of scenarios in the configuration <default `1`>
  - `number_of_subperiods::Int64`: Number of subperiods in the configuration <default `1`>
  - `demand_deficit_cost::Float64`: Demand deficit cost of the configuration <default `1.0e6`>
  - `policy_graph_type::Int64`: Policy graph type of the configuration
    + `0` [Cyclic With Null Root] <default>
    + `1` [Linear]
    + `2` [Cyclic With Season Root]

  - `market_clearing_tiebreaker_weight_for_om_costs::Float64`: Market clearing tiebreaker weight of the configuration <default `0.001`>
  - `bid_price_limit_markup_non_justified_profile::Float64`

  - `bid_price_limit_markup_justified_profile::Float64`

  - `bid_price_limit_markup_non_justified_independent::Float64`

  - `bid_price_limit_markup_justified_independent::Float64`

  - `bid_price_limit_high_reference::Float64`

  - `reference_curve_number_of_segments::Int64`

  - `reference_curve_final_segment_price_markup::Float64`

  - `max_iteration_nash_equilibrium::Int64`

  - `bid_price_validation::Int64`

  - `bid_processing::Int64`

  - `max_rev_equilibrium_bus_aggregation_type::Int64`

  - `max_rev_equilibrium_bid_initialization::Int64`

  - `inflow_model::Int64`

  - `inflow_scenarios_files::Int64`: Inflow scenarios files of the configuration
    + `0` [PAR(p)]
    + `1` [Only Ex Ante]
    + `2` [Only Ex Post] <default>
    + `3` [Ex Ante And Ex Post]

  - `demand_scenarios_files::Int64`: Demand scenarios files of the configuration
    + `0` [PAR(p)]
    + `1` [Only Ex Ante]
    + `2` [Only Ex Post] <default>
    + `3` [Ex Ante And Ex Post]

  - `renewable_scenarios_files::Int64`: Renewable scenarios files of the configuration
    + `0` [PAR(p)]
    + `1` [Only Ex Ante]
    + `2` [Only Ex Post] <default>
    + `3` [Ex Ante And Ex Post]

  - `market_clearing_tiebreaker_weight_for_fcf::Float64`

  - `virtual_reservoir_residual_revenue_split_type::Int64`

  - `cvar_alpha::Float64`

  - `cvar_lambda::Float64`

Optional arguments:

  - `number_of_nodes::Int64`: Number of nodes in the configuration

  - `train_mincost_iteration_limit::Int64`

  - `hydro_balance_subperiod_resolution::Int64`: Hydro balance subperiod resolution of the configuration <default `0`>
  - `thermal_unit_intra_period_operation::Int64`: Loop subperiods for thermal constraints of the configuration

  - `aggregate_buses_for_strategic_bidding::Int64`: Aggregate buses for strategic bidding of the configuration

  - `parp_max_lags::Int64`: PARP max lags of the configuration <default `6`>
  - `construction_type_ex_ante_physical::Int64`: Construction type ex ante physical of the configuration <default `-1`>
  - `construction_type_ex_ante_commercial::Int64`: Construction type ex ante commercial of the configuration <default `-1`>
  - `construction_type_ex_post_physical::Int64`: Construction type ex post physical of the configuration <default `-1`>
  - `construction_type_ex_post_commercial::Int64`: Construction type ex post commercial of the configuration <default `-1`>
  - `integer_variable_representation_ex_ante_physical::Int64`: Integer variable representation ex ante physical of the configuration <default `0`>
  - `integer_variable_representation_ex_ante_commercial::Int64`: Integer variable representation ex ante commercial of the configuration <default `0`>
  - `integer_variable_representation_ex_post_physical::Int64`: Integer variable representation ex post physical of the configuration <default `0`>
  - `integer_variable_representation_ex_post_commercial::Int64`: Integer variable representation ex post commercial of the configuration <default `0`>
  - `spot_price_floor::Float64`: Spot price floor of the configuration

  - `spot_price_cap::Float64`: Spot price cap of the configuration

  - `virtual_reservoir_correspondence_type::Int64`: Virtual reservoir correspondence type of the configuration <default `1`>
  - `integer_variable_representation_mincost::Int64`: Integer variable representation min cost of the configuration <default `0`>
  - `network_representation_mincost::Int64`: Network representation min cost of the configuration <default `0`>
  - `network_representation_ex_ante_physical::Int64`: Network representation ex ante physical of the configuration
    + `0` [Nodal] <default>
    + `1` [Zonal]

  - `network_representation_ex_ante_commercial::Int64`: Network representation ex ante commercial of the configuration
    + `0` [Nodal] <default>
    + `1` [Zonal]

  - `network_representation_ex_post_physical::Int64`: Network representation ex post physical of the configuration
    + `0` [Nodal] <default>
    + `1` [Zonal]

  - `network_representation_ex_post_commercial::Int64`: Network representation ex post commercial of the configuration
    + `0` [Nodal] <default>
    + `1` [Zonal]

  - `language::String`

  - `train_mincost_time_limit_sec::Int64`

  - `bid_price_limit_low_reference::Float64`

  - `supply_function_equilibrium_extra_bid_quantity::Float64`

  - `supply_function_equilibrium_tolerance::Float64`

  - `supply_function_equilibrium_max_iterations::Int64`

  - `supply_function_equilibrium_max_cost_multiplier::Float64`

  - `subperiod_duration_in_hours::Vector{Float64}`: Subperiod duration in hours of the configuration

  - `expected_number_of_repeats_per_node::Vector{Float64}`:
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
    # Initialize or allocate all fields from collections

    try
        PSRBridge.initialize!(inputs)
        initialize!(inputs)
    catch e
        clean_up(inputs)
        rethrow(e)
    end

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
    initialize!(inputs::Inputs)

Initialize the inputs.
"""
function initialize!(inputs::Inputs)
    # Initialize all collections
    for fieldname in fieldnames(Collections)
        initialize!(getfield(inputs.collections, fieldname), inputs)
    end
    # Fill relation caches with collection data
    fill_relation_caches!(inputs)

    # Validate all collections
    validate(inputs)

    # Fit PAR(p) and generate scenarios
    if fit_parp_model(inputs)
        generate_inflow_scenarios(inputs)
    end

    # Load time series from files
    initialize_time_series_from_external_files(inputs)

    # Fill data caches with collection data
    fill_data_caches!(inputs)

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
    fill_relation_caches!(inputs::Inputs)

Store pre-processed relations for the collections.
"""
function fill_relation_caches!(inputs::Inputs)
    if use_virtual_reservoirs(inputs)
        fill_hydro_unit_virtual_reservoir_index!(inputs)
        for h in index_of_elements(inputs, HydroUnit)
            fill_whether_hydro_unit_is_associated_with_some_virtual_reservoir!(inputs, h)
        end
    end
    fill_bidding_group_has_generation_besides_virtual_reservoirs!(inputs)
    fill_plot_strings_dict!(inputs)
    return nothing
end

"""
    fill_data_caches!(inputs::Inputs)

Store pre-processed data for the collections.
"""
function fill_data_caches!(inputs::Inputs)
    if use_virtual_reservoirs(inputs)
        for vr in index_of_elements(inputs, VirtualReservoir)
            fill_water_to_energy_factors!(inputs, vr)
            fill_initial_energy_account!(inputs, vr)
        end
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
    buses_represented_for_strategic_bidding(inputs::Inputs)

If the 'iteration_with_aggregate_buses' attribute is set to AGGREGATE, return [1].
Otherwise, return the index of all Buses.
"""
function buses_represented_for_strategic_bidding(inputs)
    if iteration_with_aggregate_buses(inputs)
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
        "The inflow time series is not available when the option inflow_scenarios_files is set to use the PAR(p) model.",
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
    return inputs.time_series.spot_price
end

"""
    time_series_quantity_bid(inputs::Inputs, period::Int, scenario::Int)

Return the quantity bid time series for the given period and scenario.
"""
function time_series_quantity_bid(
    inputs,
    period::Int,
    scenario::Int,
)
    if read_bids_from_file(inputs) || iterate_nash_equilibrium(inputs)
        return inputs.time_series.quantity_bid
    elseif generate_heuristic_bids_for_clearing(inputs)
        quantity_bid, price_bid = read_serialized_heuristic_bids(inputs; period = period, scenario = scenario)
        quantity_view = BidsView{Float64}()
        quantity_view.data = quantity_bid
        return quantity_view
    else
        error("Unrecognized bid source: $(bid_processing(inputs))")
    end
end

"""
    time_series_price_bid(inputs, period::Int, scenario::Int)

Return the price bid time series for the given period and scenario.
"""
function time_series_price_bid(
    inputs,
    period::Int,
    scenario::Int,
)
    if read_bids_from_file(inputs) || iterate_nash_equilibrium(inputs)
        return inputs.time_series.price_bid
    elseif generate_heuristic_bids_for_clearing(inputs)
        quantity_bid, price_bid = read_serialized_heuristic_bids(inputs; period = period, scenario = scenario)
        price_view = BidsView{Float64}()
        price_view.data = price_bid
        return price_view
    else
        error("Unrecognized bid source: $(bid_processing(inputs))")
    end
end

"""
    time_series_quantity_bid_profile(inputs::Inputs)

Return the quantity bid profile time series.
"""
function time_series_quantity_bid_profile(
    inputs,
    period::Int,
    scenario::Int,
)
    if !is_market_clearing(inputs)
        error("Quantity bid profile time series is only available for MarketClearing run mode.")
    end
    if read_bids_from_file(inputs)
        return inputs.time_series.quantity_bid_profile
    elseif generate_heuristic_bids_for_clearing(inputs)
        error("Quantity bid profile time series is not available for heuristic bids.")
    else
        error("Unrecognized bid source: $(bid_processing(inputs))")
    end
end

"""
    time_series_price_bid_profile(inputs::Inputs)

Return the price bid profile time series.
"""
function time_series_price_bid_profile(
    inputs,
    period::Int,
    scenario::Int,
)
    if !is_market_clearing(inputs)
        error("Price bid profile time series is only available for MarketClearing run mode.")
    end
    if read_bids_from_file(inputs)
        return inputs.time_series.price_bid_profile
    elseif generate_heuristic_bids_for_clearing(inputs)
        error("Price bid profile time series is not available for heuristic bids.")
    else
        error("Unrecognized bid source: $(bid_processing(inputs))")
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
        error("Unrecognized bid source: $(bid_processing(inputs))")
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
        error("Unrecognized bid source: $(bid_processing(inputs))")
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
        error("Unrecognized bid source: $(bid_processing(inputs))")
    end
end

"""
    time_series_virtual_reservoir_quantity_bid(inputs, period::Int, scenario::Int)

Return the virtual reservoir quantity bid time series for the given period and scenario.
"""
function time_series_virtual_reservoir_quantity_bid(
    inputs,
    period::Int,
    scenario::Int,
)
    if read_bids_from_file(inputs)
        return inputs.time_series.virtual_reservoir_quantity_bid
    elseif generate_heuristic_bids_for_clearing(inputs)
        quantity_bid, price_bid =
            read_serialized_virtual_reservoir_heuristic_bids(inputs; period = period, scenario = scenario)
        quantity_view = VirtualReservoirBidsView{Float64}()
        quantity_view.data = quantity_bid
        return quantity_view
    else
        error("Unrecognized bid source: $(bid_processing(inputs))")
    end
end

"""
    time_series_virtual_reservoir_price_bid(inputs, period::Int, scenario::Int)

Return the virtual reservoir price bid time series for the given period and scenario.
"""
function time_series_virtual_reservoir_price_bid(
    inputs,
    period::Int,
    scenario::Int,
)
    if read_bids_from_file(inputs)
        return inputs.time_series.virtual_reservoir_price_bid
    elseif generate_heuristic_bids_for_clearing(inputs)
        quantity_bid, price_bid =
            read_serialized_virtual_reservoir_heuristic_bids(inputs; period = period, scenario = scenario)
        price_view = VirtualReservoirBidsView{Float64}()
        price_view.data = price_bid
        return price_view
    else
        error("Unrecognized bid source: $(bid_processing(inputs))")
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
    time_series_inflow_noise(inputs, run_time_options; subscenario::Union{Int, Nothing} = nothing)

Return the inflow noise time series.
"""
function time_series_inflow_noise(inputs, run_time_options; subscenario::Union{Int, Nothing} = nothing)
    if read_inflow_from_file(inputs)
        error("Inflow noise is not available when 'read_inflow_from_file' is set to true.")
    end
    if is_ex_post_problem(run_time_options)
        if read_ex_post_inflow_file(inputs)
            if isnothing(subscenario)
                error("Always provide a subscenario when reading the ex-post inflow noise during ex-post problems.")
            end
            return inputs.time_series.inflow_noise.ex_post[:, subscenario]
        elseif read_ex_ante_inflow_file(inputs)
            return inputs.time_series.inflow_noise.ex_ante.data
        end
    else
        if read_ex_ante_inflow_file(inputs)
            return inputs.time_series.inflow_noise.ex_ante.data
        elseif read_ex_post_inflow_file(inputs)
            return mean(inputs.time_series.inflow_noise.ex_post.data; dims = 2)[:, 1]
        end
    end
    return error(
        "The inflow noise time series is not available. Check your inflow_scenarios_files configuration.",
    )
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

"""
    time_series_bid_price_limit_justified_independent(inputs)

Return the time series of price limits for justified independent bids.
"""
time_series_bid_price_limit_justified_independent(inputs) = inputs.time_series.bid_price_limit_justified_independent

"""
    time_series_bid_price_limit_non_justified_independent(inputs)

Return the time series of price limits for non justified independent bids.
"""
time_series_bid_price_limit_non_justified_independent(inputs) =
    inputs.time_series.bid_price_limit_non_justified_independent

"""
    time_series_bid_price_limit_justified_profile(inputs)

Return the time series of price limits for justified profile bids.
"""
time_series_bid_price_limit_justified_profile(inputs) = inputs.time_series.bid_price_limit_justified_profile

"""
    time_series_bid_price_limit_non_justified_profile(inputs)

Return the time series of price limits for non justified profile bids.
"""
time_series_bid_price_limit_non_justified_profile(inputs) = inputs.time_series.bid_price_limit_non_justified_profile
