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
    TimeSeriesViewsFromExternalFiles

Struct holding all the time series data that is read from external files.
All fields only store a reference to the data, which is read from the files
in chunks.
"""
@kwdef mutable struct TimeSeriesViewsFromExternalFiles
    # TODO: change period dimension name
    # Agents x periods
    inflow_period_average::TimeSeriesView{Float64, 2} =
        TimeSeriesView{Float64, 2}()
    inflow_period_std_dev::TimeSeriesView{Float64, 2} =
        TimeSeriesView{Float64, 2}()

    # TODO this one should be a similar implementation than the others
    hour_subperiod_mapping::HourSubperiodMapping = HourSubperiodMapping()

    # Agents
    inflow_noise::TimeSeriesView{Float64, 1} = TimeSeriesView{Float64, 1}()

    # Agents x subperiods
    demand_window::TimeSeriesView{Int, 2} = TimeSeriesView{Int, 2}()

    # Agents x lag
    parp_coefficients::TimeSeriesView{Float64, 2} = TimeSeriesView{Float64, 2}()

    # Agents x subperiods
    inflow::ExAnteAndExPostTimeSeriesView{Float64, 2, 3} = ExAnteAndExPostTimeSeriesView{Float64, 2, 3}()
    demand_unit::ExAnteAndExPostTimeSeriesView{Float64, 2, 3} = ExAnteAndExPostTimeSeriesView{Float64, 2, 3}()
    renewable_generation::ExAnteAndExPostTimeSeriesView{Float64, 2, 3} =
        ExAnteAndExPostTimeSeriesView{Float64, 2, 3}()
    spot_price::TimeSeriesView{Float64, 2} = TimeSeriesView{Float64, 2}()
    elastic_demand_price::TimeSeriesView{Float64, 2} =
        TimeSeriesView{Float64, 2}()
    hydro_generation::TimeSeriesView{Float64, 2} = TimeSeriesView{Float64, 2}()
    hydro_opportunity_cost::TimeSeriesView{Float64, 2} =
        TimeSeriesView{Float64, 2}()

    # BiddingGroups x buses x segments x subperiods
    quantity_offer::BidsView{Float64} = BidsView{Float64}()
    price_offer::BidsView{Float64} = BidsView{Float64}()

    # BiddingGroups x buses x segments x subperiods
    quantity_offer_multihour = BidsView{Float64}()

    # BiddingGroups x profile
    # On profile bids, the price offer is the same for all subperiods and all buses
    price_offer_multihour::TimeSeriesView{Float64, 2} =
        TimeSeriesView{Float64, 2}()
    # BiddingGroups x profile
    parent_profile_multihour::TimeSeriesView{Float64, 2} =
        TimeSeriesView{Float64, 2}()
    # BiddingGroups x profile
    complementary_grouping_multihour::TimeSeriesView{Float64, 3} =
        TimeSeriesView{Float64, 3}()
    # BiddingGroups x profile
    minimum_activation_level_multihour::TimeSeriesView{Float64, 2} =
        TimeSeriesView{Float64, 2}()

    # VirtualReservoirs x AssetOwners x segments
    virtual_reservoir_quantity_offer::VirtualReservoirBidsView{Float64} = VirtualReservoirBidsView{Float64}()
    virtual_reservoir_price_offer::VirtualReservoirBidsView{Float64} = VirtualReservoirBidsView{Float64}()
end

"""
    initialize_time_series_from_external_files(inputs)

Initialize the time series data from external files. This function reads the
data from the files and stores it in the `inputs` struct.
"""
function initialize_time_series_from_external_files(inputs)
    num_errors = 0
    num_created_files = 0

    # Hour subperiod map
    if has_hour_subperiod_map(inputs)
        num_errors += initialize_hour_subperiod_mapping(inputs)
    end

    # Inflow
    if any_elements(inputs, HydroUnit)
        if read_inflow_from_file(inputs)
            num_created_files += create_empty_time_series_if_necessary(
                joinpath(path_case(inputs), hydro_unit_inflow_file(inputs)),
                Quiver.csv;
                dimensions = ["period", "scenario", "subperiod"],
                labels = gauging_station_label(inputs),
                time_dimension = "period",
                dimension_size = [number_of_periods(inputs), number_of_scenarios(inputs), number_of_subperiods(inputs)],
                initial_date = initial_date_time(inputs),
                unit = "m3/s",
            )
            num_errors += initialize_da_and_rt_time_series_view_from_external_files!(
                inputs.time_series.inflow,
                inputs,
                joinpath(path_case(inputs), hydro_unit_inflow_file(inputs));
                expected_unit = "m3/s",
                labels_to_read = gauging_station_label(inputs),
            )
        else
            num_errors += initialize_time_series_view_from_external_file(
                inputs.time_series.inflow_noise,
                inputs,
                joinpath(path_parp(inputs), gauging_station_inflow_noise_file(inputs));
                expected_unit = "m3/s",
                labels_to_read = gauging_station_label(inputs),
            )
            if parp_max_lags(inputs) > 0
                num_errors += initialize_time_series_view_from_external_file(
                    inputs.time_series.parp_coefficients,
                    inputs,
                    joinpath(path_parp(inputs), gauging_station_parp_coefficients_file(inputs));
                    expected_unit = "-",
                    labels_to_read = gauging_station_label(inputs),
                )
            end
            num_errors += initialize_time_series_view_from_external_file(
                inputs.time_series.inflow_period_average,
                inputs,
                joinpath(path_parp(inputs), gauging_station_inflow_period_average_file(inputs));
                expected_unit = "m3/s",
                labels_to_read = gauging_station_label(inputs),
            )
            num_errors += initialize_time_series_view_from_external_file(
                inputs.time_series.inflow_period_std_dev,
                inputs,
                joinpath(path_parp(inputs), gauging_station_inflow_period_std_dev_file(inputs));
                expected_unit = "m3/s",
                labels_to_read = gauging_station_label(inputs),
            )
        end
    end

    # Hydro generation
    if must_read_hydro_unit_data_for_markup_wizard(inputs)
        num_created_files += create_empty_time_series_if_necessary(
            joinpath(path_case(inputs), hydro_unit_generation_file(inputs)),
            Quiver.csv;
            dimensions = ["period", "scenario", "subperiod"],
            labels = hydro_unit_label(inputs),
            time_dimension = "period",
            dimension_size = [number_of_periods(inputs), number_of_scenarios(inputs), number_of_subperiods(inputs)],
            initial_date = initial_date_time(inputs),
            unit = "GWh",
        )
        num_errors += initialize_time_series_view_from_external_file(
            inputs.time_series.hydro_generation,
            inputs,
            joinpath(path_case(inputs), hydro_unit_generation_file(inputs));
            expected_unit = "GWh",
            labels_to_read = hydro_unit_label(inputs),
        )

        num_created_files += create_empty_time_series_if_necessary(
            joinpath(path_case(inputs), hydro_unit_opportunity_cost_file(inputs)),
            Quiver.csv;
            dimensions = ["period", "scenario", "subperiod"],
            labels = hydro_unit_label(inputs),
            time_dimension = "period",
            dimension_size = [number_of_periods(inputs), number_of_scenarios(inputs), number_of_subperiods(inputs)],
            initial_date = initial_date_time(inputs),
            unit = "\$/MWh",
        )
        num_errors += initialize_time_series_view_from_external_file(
            inputs.time_series.hydro_opportunity_cost,
            inputs,
            joinpath(path_case(inputs), hydro_unit_opportunity_cost_file(inputs));
            expected_unit = "\$/MWh",
            labels_to_read = hydro_unit_label(inputs),
        )
    end

    # Demand
    if any_elements(inputs, DemandUnit) > 0
        num_created_files += create_empty_time_series_if_necessary(
            joinpath(path_case(inputs), demand_unit_demand_file(inputs)),
            Quiver.csv;
            dimensions = ["period", "scenario", "subperiod"],
            labels = demand_unit_label(inputs),
            time_dimension = "period",
            dimension_size = [number_of_periods(inputs), number_of_scenarios(inputs), number_of_subperiods(inputs)],
            initial_date = initial_date_time(inputs),
            unit = "GWh",
        )
        num_errors += initialize_da_and_rt_time_series_view_from_external_files!(
            inputs.time_series.demand_unit,
            inputs,
            joinpath(path_case(inputs), demand_unit_demand_file(inputs));
            expected_unit = "GWh",
            labels_to_read = demand_unit_label(inputs),
        )
    end

    # Renewable generation
    if any_elements(inputs, RenewableUnit)
        num_created_files += create_empty_time_series_if_necessary(
            joinpath(path_case(inputs), renewable_unit_generation_file(inputs)),
            Quiver.csv;
            dimensions = ["period", "scenario", "subperiod"],
            labels = renewable_unit_label(inputs),
            time_dimension = "period",
            dimension_size = [number_of_periods(inputs), number_of_scenarios(inputs), number_of_subperiods(inputs)],
            initial_date = initial_date_time(inputs),
            unit = "p.u.",
        )
        num_errors += initialize_da_and_rt_time_series_view_from_external_files!(
            inputs.time_series.renewable_generation,
            inputs,
            joinpath(path_case(inputs), renewable_unit_generation_file(inputs));
            expected_unit = "p.u.",
            labels_to_read = renewable_unit_label(inputs),
        )
    end

    # Flexible demand
    if any_elements(inputs, DemandUnit; filters = [is_flexible])
        num_created_files += create_empty_time_series_if_necessary(
            joinpath(path_case(inputs), demand_unit_window_file(inputs)),
            Quiver.csv;
            dimensions = ["period", "subperiod"],
            labels = flexible_demand_labels(inputs),
            time_dimension = "period",
            dimension_size = [number_of_periods(inputs), number_of_subperiods(inputs)],
            initial_date = initial_date_time(inputs),
            unit = "-",
        )
        num_errors += initialize_time_series_view_from_external_file(
            inputs.time_series.demand_window,
            inputs,
            joinpath(path_case(inputs), demand_unit_window_file(inputs));
            expected_unit = "-",
            labels_to_read = flexible_demand_labels(inputs),
        )
        fill_flexible_demand_window_caches!(inputs, inputs.time_series.demand_window.data)
    end

    # Spot price
    if run_mode(inputs) == Configurations_RunMode.PRICE_TAKER_BID
        num_created_files += create_empty_time_series_if_necessary(
            joinpath(path_case(inputs), "load_marginal_cost"),
            Quiver.csv;
            dimensions = ["period", "scenario", "subperiod"],
            labels = bus_label(inputs),
            time_dimension = "period",
            dimension_size = [number_of_periods(inputs), number_of_scenarios(inputs), number_of_subperiods(inputs)],
            initial_date = initial_date_time(inputs),
            unit = raw"$/MWh",
        )
        num_errors += initialize_time_series_view_from_external_file(
            inputs.time_series.spot_price,
            inputs,
            joinpath(path_case(inputs), "load_marginal_cost");
            expected_unit = raw"$/MWh",
            labels_to_read = bus_label(inputs),
        )
    end

    # Offers
    if run_mode(inputs) == Configurations_RunMode.STRATEGIC_BID ||
       (
        run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING && any_elements(inputs, BiddingGroup) &&
        read_bids_from_file(inputs)
    )
        file = joinpath(path_case(inputs), bidding_group_quantity_offer_file(inputs))
        try
            num_created_files += create_empty_time_series_if_necessary(
                file,
                Quiver.csv;
                dimensions = ["period", "scenario", "subperiod", "bid_segment"],
                labels = bidding_group_file_labels(inputs),
                time_dimension = "period",
                dimension_size = [
                    number_of_periods(inputs),
                    number_of_scenarios(inputs),
                    number_of_subperiods(inputs),
                    number_of_bid_segments_for_file_template(inputs),
                ],
                initial_date = initial_date_time(inputs),
                unit = "MWh",
            )
            num_errors += initialize_bids_view_from_external_file!(
                inputs.time_series.quantity_offer,
                inputs,
                file;
                expected_unit = "MWh",
                bidding_groups_to_read = bidding_group_label(inputs),
                buses_to_read = bus_label(inputs),
            )
        catch e
            if number_of_bid_segments_for_file_template(inputs) == 0 && e isa AssertionError
                @error(
                    "The number of bid segments for the file template is zero and the file $file doesn't exist. Add a valid number of segments or add the file $file to the case directory."
                )
                num_errors += 1
            else
                rethrow(e)
            end
        end

        file = joinpath(path_case(inputs), bidding_group_price_offer_file(inputs))
        try
            num_created_files += create_empty_time_series_if_necessary(
                file,
                Quiver.csv;
                dimensions = ["period", "scenario", "subperiod", "bid_segment"],
                labels = bidding_group_file_labels(inputs),
                time_dimension = "period",
                dimension_size = [
                    number_of_periods(inputs),
                    number_of_scenarios(inputs),
                    number_of_subperiods(inputs),
                    number_of_bid_segments_for_file_template(inputs),
                ],
                initial_date = initial_date_time(inputs),
                unit = raw"$/MWh",
            )
            num_errors += initialize_bids_view_from_external_file!(
                inputs.time_series.price_offer,
                inputs,
                file;
                expected_unit = raw"$/MWh",
                bidding_groups_to_read = bidding_group_label(inputs),
                buses_to_read = bus_label(inputs),
            )
        catch e
            if number_of_bid_segments_for_file_template(inputs) == 0 && e isa AssertionError
                @error(
                    "The number of bid segments for the file template is zero and the file $file doesn't exist. Add a valid number of segments or add the file $file to the case directory."
                )
                num_errors += 1
            else
                rethrow(e)
            end
        end
    end

    # Multihour offers
    if run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING &&
       any_elements(inputs, BiddingGroup; filters = [has_profile_bids])
        bidding_group_labels_multihour =
            index_of_elements(inputs, BiddingGroup; filters = [has_profile_bids])
        labels_multihour = bidding_group_label(inputs)[bidding_group_labels_multihour]

        file = joinpath(path_case(inputs), bidding_group_quantity_offer_multihour_file(inputs))
        try
            num_created_files += create_empty_time_series_if_necessary(
                file,
                Quiver.csv;
                dimensions = ["period", "scenario", "subperiod", "profile"],
                labels = bidding_group_file_labels(inputs),
                time_dimension = "period",
                dimension_size = [
                    number_of_periods(inputs),
                    number_of_scenarios(inputs),
                    number_of_subperiods(inputs),
                    number_of_profiles_for_file_template(inputs),
                ],
                initial_date = initial_date_time(inputs),
                unit = "MWh",
            )
            num_errors += initialize_bids_view_from_external_file!(
                inputs.time_series.quantity_offer_multihour,
                inputs,
                file;
                expected_unit = "MWh",
                bidding_groups_to_read = bidding_group_label(inputs),
                buses_to_read = bus_label(inputs),
                has_profile_bids = true,
            )
        catch e
            if number_of_profiles_for_file_template(inputs) == 0 && e isa AssertionError
                @error(
                    "The number of profiles for the file template is zero and the file $file doesn't exist. Add a valid number of profiles or add the file $file to the case directory."
                )
                num_errors += 1
            else
                rethrow(e)
            end
        end

        file = joinpath(path_case(inputs), bidding_group_price_offer_multihour_file(inputs))
        try
            num_created_files += create_empty_time_series_if_necessary(
                file,
                Quiver.csv;
                dimensions = ["period", "scenario", "profile"],
                labels = bidding_group_label(inputs),
                time_dimension = "period",
                dimension_size = [
                    number_of_periods(inputs),
                    number_of_scenarios(inputs),
                    number_of_profiles_for_file_template(inputs),
                ],
                initial_date = initial_date_time(inputs),
                unit = raw"$/MWh",
            )
            num_errors += initialize_time_series_view_from_external_file(
                inputs.time_series.price_offer_multihour,
                inputs,
                file;
                expected_unit = raw"$/MWh",
                labels_to_read = bidding_group_label(inputs),
            )
        catch e
            if number_of_profiles_for_file_template(inputs) == 0 && e isa AssertionError
                @error(
                    "The number of profiles for the file template is zero and the file $file doesn't exist. Add a valid number of profiles or add the file $file to the case directory."
                )
                num_errors += 1
            else
                rethrow(e)
            end
        end

        if has_any_multihour_complex_input_files(inputs)
            file = joinpath(path_case(inputs), bidding_group_parent_profile_multihour_file(inputs))
            try
                num_created_files += create_empty_time_series_if_necessary(
                    file,
                    Quiver.csv;
                    dimensions = ["period", "profile"],
                    labels = labels_multihour,
                    time_dimension = "period",
                    dimension_size = [number_of_periods(inputs), number_of_profiles_for_file_template(inputs)],
                    initial_date = initial_date_time(inputs),
                    unit = "-",
                )
                num_errors += initialize_time_series_view_from_external_file(
                    inputs.time_series.parent_profile_multihour,
                    inputs,
                    file;
                    expected_unit = "-",
                    labels_to_read = labels_multihour,
                )
            catch e
                if number_of_profiles_for_file_template(inputs) == 0 && e isa AssertionError
                    @error(
                        "The number of profiles for the file template is zero and the file $file doesn't exist. Add a valid number of profiles or add the file $file to the case directory."
                    )
                    num_errors += 1
                else
                    rethrow(e)
                end
            end

            file = joinpath(path_case(inputs), bidding_group_complementary_grouping_multihour_file(inputs))
            try
                num_created_files += create_empty_time_series_if_necessary(
                    file,
                    Quiver.csv;
                    dimensions = ["period", "profile", "complementary_group"],
                    labels = labels_multihour,
                    time_dimension = "period",
                    dimension_size = [
                        number_of_periods(inputs),
                        maximum_number_of_bidding_profiles(inputs),
                        number_of_complementary_groups_for_file_template(inputs),
                    ],
                    initial_date = initial_date_time(inputs),
                    unit = "-",
                )
                num_errors += initialize_time_series_view_from_external_file(
                    inputs.time_series.complementary_grouping_multihour,
                    inputs,
                    file;
                    expected_unit = "-",
                    labels_to_read = labels_multihour,
                )
            catch e
                if number_of_complementary_groups_for_file_template(inputs) == 0 && e isa AssertionError
                    @error(
                        "The number of complementary groups for the file template is zero and the file $file doesn't exist. Add a valid number of complementary groups or add the file $file to the case directory."
                    )
                    num_errors += 1
                else
                    rethrow(e)
                end
            end

            file = joinpath(path_case(inputs), bidding_group_minimum_activation_level_multihour_file(inputs))
            try
                num_created_files += create_empty_time_series_if_necessary(
                    file,
                    Quiver.csv;
                    dimensions = ["period", "scenario", "profile"],
                    labels = labels_multihour,
                    time_dimension = "period",
                    dimension_size = [
                        number_of_periods(inputs),
                        number_of_scenarios(inputs),
                        number_of_profiles_for_file_template(inputs),
                    ],
                    initial_date = initial_date_time(inputs),
                    unit = "-",
                )
                num_errors += initialize_time_series_view_from_external_file(
                    inputs.time_series.minimum_activation_level_multihour,
                    inputs,
                    file;
                    expected_unit = "-",
                    labels_to_read = labels_multihour,
                )
            catch e
                if number_of_profiles_for_file_template(inputs) == 0 && e isa AssertionError
                    @error(
                        "The number of profiles for the file template is zero and the file $file doesn't exist. Add a valid number of profiles or add the file $file to the case directory."
                    )
                    num_errors += 1
                else
                    rethrow(e)
                end
            end
        end
    end
    # Virtual reservoir offers
    if (
           run_mode(inputs) == Configurations_RunMode.STRATEGIC_BID ||
           run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING
       ) && any_elements(inputs, VirtualReservoir) && read_bids_from_file(inputs)
        file = joinpath(path_case(inputs), virtual_reservoir_quantity_offer_file(inputs))
        try
            num_created_files += create_empty_time_series_if_necessary(
                file,
                Quiver.csv;
                dimensions = ["period", "scenario", "bid_segment"],
                labels = virtual_reservoir_file_labels(inputs),
                time_dimension = "period",
                dimension_size = [
                    number_of_periods(inputs),
                    number_of_scenarios(inputs),
                    number_of_bid_segments_for_virtual_reservoir_file_template(inputs),
                ],
                initial_date = initial_date_time(inputs),
                unit = "MWh",
            )
            num_errors += initialize_virtual_reservoir_bids_view_from_external_file!(
                inputs.time_series.virtual_reservoir_quantity_offer,
                inputs,
                file;
                expected_unit = "MWh",
                virtual_reservoirs_to_read = virtual_reservoir_label(inputs),
                asset_owners_to_read = asset_owner_label(inputs),
            )
        catch e
            if number_of_bid_segments_for_virtual_reservoir_file_template(inputs) == 0 && e isa AssertionError
                @error(
                    "The number of bid segments for the virtual reservoir file template is zero and the file $file doesn't exist. Add a valid number of segments or add the file $file to the case directory."
                )
                num_errors += 1
            else
                rethrow(e)
            end
        end

        file = joinpath(path_case(inputs), virtual_reservoir_price_offer_file(inputs))
        try
            num_created_files += create_empty_time_series_if_necessary(
                file,
                Quiver.csv;
                dimensions = ["period", "scenario", "bid_segment"],
                labels = virtual_reservoir_file_labels(inputs),
                time_dimension = "period",
                dimension_size = [
                    number_of_periods(inputs),
                    number_of_scenarios(inputs),
                    number_of_bid_segments_for_virtual_reservoir_file_template(inputs),
                ],
                initial_date = initial_date_time(inputs),
                unit = raw"$/MWh",
            )
            num_errors += initialize_virtual_reservoir_bids_view_from_external_file!(
                inputs.time_series.virtual_reservoir_price_offer,
                inputs,
                file;
                expected_unit = raw"$/MWh",
                virtual_reservoirs_to_read = virtual_reservoir_label(inputs),
                asset_owners_to_read = asset_owner_label(inputs),
            )
        catch e
            if number_of_bid_segments_for_virtual_reservoir_file_template(inputs) == 0 && e isa AssertionError
                @error(
                    "The number of bid segments for the virtual reservoir file template is zero and the file $file doesn't exist. Add a valid number of segments or add the file $file to the case directory."
                )
                num_errors += 1
            else
                rethrow(e)
            end
        end
    end

    # Elastic demand price
    if any_elements(inputs, DemandUnit; filters = [is_elastic])
        num_created_files += create_empty_time_series_if_necessary(
            joinpath(path_case(inputs), demand_unit_elastic_demand_price_file(inputs)),
            Quiver.csv;
            dimensions = ["period", "scenario", "subperiod"],
            labels = elastic_demand_labels(inputs),
            time_dimension = "period",
            dimension_size = [number_of_periods(inputs), number_of_scenarios(inputs), number_of_subperiods(inputs)],
            initial_date = initial_date_time(inputs),
            unit = raw"$/MWh",
        )
        num_errors += initialize_time_series_view_from_external_file(
            inputs.time_series.elastic_demand_price,
            inputs,
            joinpath(path_case(inputs), demand_unit_elastic_demand_price_file(inputs));
            expected_unit = raw"$/MWh",
            labels_to_read = elastic_demand_labels(inputs),
        )
    end

    inputs.caches.templates_for_time_series_files_have_been_generated = num_created_files > 0

    if num_errors > 0
        error("There were $num_errors errors in the time series files.")
    end

    # Do some specific validations

    return nothing
end

function update_time_series_views_from_external_files!(
    inputs;
    period::Int,
    scenario::Int,
)
    # TODO this should check if the period and scenario changed
    time_series = inputs.time_series
    for field in fieldnames(TimeSeriesViewsFromExternalFiles)
        ts = getfield(time_series, field)
        if isa(ts, TimeSeriesView) && ts.reader !== nothing
            ts.data = read_time_series_view_from_external_file(
                inputs,
                ts.reader;
                period = period,
                scenario = scenario,
                data_type = eltype(ts.data), # TODO is this really neeeded?
            )
        end
        if isa(ts, HourSubperiodMapping) && ts.reader !== nothing
            update_hour_subperiod_mapping!(inputs; period = period_index_in_year(inputs, period))
        end
        if isa(ts, BidsView) && ts.reader !== nothing
            has_profile_bids = field == :quantity_offer_multihour
            ts.data = read_bids_view_from_external_file(
                inputs,
                ts.reader;
                period = period,
                scenario = scenario,
                data_type = eltype(ts.data),
                has_profile_bids,
            )
        end
        if isa(ts, VirtualReservoirBidsView) && ts.reader !== nothing
            ts.data = read_virtual_reservoir_bids_view_from_external_file(
                inputs,
                ts.reader;
                period = period,
                scenario = scenario,
                data_type = eltype(ts.data),
            )
        end
        if isa(ts, ExAnteAndExPostTimeSeriesView)
            if has_ex_ante_time_series(ts)
                ts.ex_ante.data = read_time_series_view_from_external_file(
                    inputs,
                    ts.ex_ante.reader;
                    period = period,
                    scenario = scenario,
                    data_type = eltype(ts.ex_ante.data),
                )
            end
            if has_ex_post_time_series(ts)
                ts.ex_post.data = read_time_series_view_from_external_file(
                    inputs,
                    ts.ex_post.reader;
                    period = period,
                    scenario = scenario,
                    data_type = eltype(ts.ex_post.data),
                )
            end
        end
    end
    if any_elements(inputs, DemandUnit; filters = [is_flexible])
        fill_flexible_demand_window_caches!(inputs, time_series.demand_window.data)
    end
    return nothing
end

function close_all_external_files_time_series_readers!(inputs)
    time_series = inputs.time_series
    for field in fieldnames(TimeSeriesViewsFromExternalFiles)
        ts = getfield(time_series, field)
        close(ts)
    end
    return nothing
end

function iara_log(ts::TimeSeriesViewsFromExternalFiles)
    for field in fieldnames(TimeSeriesViewsFromExternalFiles)
        ts_field = getfield(ts, field)
        if !isempty(ts_field)
            println("   $(field)")
        end
    end
end
