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
    period_season_map::TimeSeriesView{Float64, 1} = TimeSeriesView{Float64, 1}()

    # Agents x subperiods
    demand_window::TimeSeriesView{Int, 2} = TimeSeriesView{Int, 2}()

    # Agents x lag
    parp_coefficients::TimeSeriesView{Float64, 2} = TimeSeriesView{Float64, 2}()

    # Agents x subperiods
    inflow::ExAnteAndExPostTimeSeriesView{Float64, 2, 3} = ExAnteAndExPostTimeSeriesView{Float64, 2, 3}()
    demand::ExAnteAndExPostTimeSeriesView{Float64, 2, 3} = ExAnteAndExPostTimeSeriesView{Float64, 2, 3}()
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
    no_markup_price_offer::BidsView{Float64} = BidsView{Float64}()

    # BiddingGroups x buses x segments x subperiods
    quantity_offer_profile = BidsView{Float64}()

    # BiddingGroups x profile
    # On profile bids, the price offer is the same for all subperiods and all buses
    price_offer_profile::TimeSeriesView{Float64, 2} =
        TimeSeriesView{Float64, 2}()
    # BiddingGroups x profile
    parent_profile::TimeSeriesView{Float64, 2} =
        TimeSeriesView{Float64, 2}()
    # BiddingGroups x profile
    complementary_grouping_profile::TimeSeriesView{Float64, 3} =
        TimeSeriesView{Float64, 3}()
    # BiddingGroups x profile
    minimum_activation_level_profile::TimeSeriesView{Float64, 2} =
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

    # Hour subperiod map
    if has_hour_subperiod_map(inputs)
        num_errors += initialize_hour_subperiod_mapping(inputs)
    end

    # Period season map
    if has_period_season_map_file(inputs)
        num_errors += initialize_time_series_view_from_external_file(
            inputs.time_series.period_season_map,
            inputs,
            joinpath(path_case(inputs), period_season_map_file(inputs));
            expected_unit = " ",
            possible_expected_dimensions = [
                [:period, :scenario],
            ],
            labels_to_read = ["season", "sample", "next_subscenario"],
        )
    end

    # Inflow
    if any_elements(inputs, HydroUnit)
        if read_inflow_from_file(inputs)
            possible_dimensions = if cyclic_policy_graph(inputs)
                [[:season, :sample, :subperiod], [:season, :sample, :hour]]
            else
                [[:period, :scenario, :subperiod], [:period, :scenario, :hour]]
            end
            num_errors += initialize_ex_ante_and_ex_post_time_series_view_from_external_files!(
                inputs.time_series.inflow,
                inputs;
                ex_ante_file_path = joinpath(path_case(inputs), hydro_unit_inflow_ex_ante_file(inputs)),
                ex_post_file_path = joinpath(path_case(inputs), hydro_unit_inflow_ex_post_file(inputs)),
                files_to_read = inflow_scenarios_files(inputs),
                expected_unit = "m3/s",
                possible_expected_dimensions = possible_dimensions,
                labels_to_read = gauging_station_label(inputs),
            )
        else
            num_errors += initialize_time_series_view_from_external_file(
                inputs.time_series.inflow_noise,
                inputs,
                joinpath(path_parp(inputs), gauging_station_inflow_noise_file(inputs));
                expected_unit = "m3/s",
                possible_expected_dimensions = [
                    [:period, :scenario],
                ],
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
        num_errors += initialize_time_series_view_from_external_file(
            inputs.time_series.hydro_generation,
            inputs,
            joinpath(path_case(inputs), hydro_unit_generation_file(inputs));
            expected_unit = "GWh",
            possible_expected_dimensions = [
                [:period, :scenario, :subperiod],
            ],
            labels_to_read = hydro_unit_label(inputs),
        )
        num_errors += initialize_time_series_view_from_external_file(
            inputs.time_series.hydro_opportunity_cost,
            inputs,
            joinpath(path_case(inputs), hydro_unit_opportunity_cost_file(inputs));
            expected_unit = "\$/MWh",
            possible_expected_dimensions = [
                [:period, :scenario, :subperiod],
            ],
            labels_to_read = hydro_unit_label(inputs),
        )
    end

    # Demand
    if any_elements(inputs, DemandUnit) > 0
        possible_dimensions = if cyclic_policy_graph(inputs)
            [[:season, :sample, :subperiod]]
        else
            [
                [:period, :scenario, :subperiod],
                [:period, :scenario, :hour],
            ]
        end
        num_errors += initialize_ex_ante_and_ex_post_time_series_view_from_external_files!(
            inputs.time_series.demand,
            inputs;
            ex_ante_file_path = joinpath(path_case(inputs), demand_unit_demand_ex_ante_file(inputs)),
            ex_post_file_path = joinpath(path_case(inputs), demand_unit_demand_ex_post_file(inputs)),
            files_to_read = demand_scenarios_files(inputs),
            expected_unit = "p.u.",
            possible_expected_dimensions = possible_dimensions,
            labels_to_read = demand_unit_label(inputs),
        )
    end

    # Renewable generation
    if any_elements(inputs, RenewableUnit)
        possible_dimensions = if cyclic_policy_graph(inputs)
            [[:season, :sample, :subperiod]]
        else
            [[:period, :scenario, :subperiod]]
        end
        num_errors += initialize_ex_ante_and_ex_post_time_series_view_from_external_files!(
            inputs.time_series.renewable_generation,
            inputs;
            ex_ante_file_path = joinpath(path_case(inputs), renewable_unit_generation_ex_ante_file(inputs)),
            ex_post_file_path = joinpath(path_case(inputs), renewable_unit_generation_ex_post_file(inputs)),
            files_to_read = renewable_scenarios_files(inputs),
            expected_unit = "p.u.",
            possible_expected_dimensions = possible_dimensions,
            labels_to_read = renewable_unit_label(inputs),
        )
    end

    # Flexible demand
    if any_elements(inputs, DemandUnit; filters = [is_flexible])
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
    if run_mode(inputs) == RunMode.PRICE_TAKER_BID
        num_errors += initialize_time_series_view_from_external_file(
            inputs.time_series.spot_price,
            inputs,
            joinpath(path_case(inputs), "load_marginal_cost");
            expected_unit = raw"$/MWh",
            labels_to_read = bus_label(inputs),
        )
    end

    # Offers
    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    if run_mode(inputs) == RunMode.STRATEGIC_BID ||
       (
        is_market_clearing(inputs) && any_elements(inputs, BiddingGroup) &&
        read_bids_from_file(inputs) && has_any_bid_simple_input_files(inputs)
    )
        file = joinpath(path_case(inputs), bidding_group_quantity_offer_file(inputs))
        num_errors += initialize_bids_view_from_external_file!(
            inputs.time_series.quantity_offer,
            inputs,
            file;
            expected_unit = "MWh",
            possible_expected_dimensions = [
                [:period, :scenario, :subperiod, :profile],
                [:period, :scenario, :subperiod, :bid_segment],
            ],
            bidding_groups_to_read = bidding_group_label(inputs)[bidding_groups],
            buses_to_read = bus_label(inputs),
        )

        file = joinpath(path_case(inputs), bidding_group_price_offer_file(inputs))
        num_errors += initialize_bids_view_from_external_file!(
            inputs.time_series.price_offer,
            inputs,
            file;
            expected_unit = raw"$/MWh",
            possible_expected_dimensions = [
                [:period, :scenario, :subperiod, :profile],
                [:period, :scenario, :subperiod, :bid_segment],
            ],
            bidding_groups_to_read = bidding_group_label(inputs)[bidding_groups],
            buses_to_read = bus_label(inputs),
        )
    end

    # profile offers
    if is_market_clearing(inputs) && any_elements(inputs, BiddingGroup) &&
       read_bids_from_file(inputs) && has_any_profile_input_files(inputs)
        file = joinpath(path_case(inputs), bidding_group_quantity_offer_profile_file(inputs))
        num_errors += initialize_bids_view_from_external_file!(
            inputs.time_series.quantity_offer_profile,
            inputs,
            file;
            expected_unit = "MWh",
            possible_expected_dimensions = [
                [:period, :scenario, :subperiod, :profile],
                [:period, :scenario, :subperiod, :bid_segment],
            ],
            bidding_groups_to_read = bidding_group_label(inputs)[bidding_groups],
            buses_to_read = bus_label(inputs),
            has_profile_bids = true,
        )

        file = joinpath(path_case(inputs), bidding_group_price_offer_profile_file(inputs))
        num_errors += initialize_time_series_view_from_external_file(
            inputs.time_series.price_offer_profile,
            inputs,
            file;
            expected_unit = raw"$/MWh",
            labels_to_read = bidding_group_label(inputs),
        )

        if has_any_profile_complex_input_files(inputs)
            file = joinpath(path_case(inputs), bidding_group_parent_profile_file(inputs))
            num_errors += initialize_time_series_view_from_external_file(
                inputs.time_series.parent_profile,
                inputs,
                file;
                expected_unit = "-",
                labels_to_read = bidding_group_label(inputs),
            )

            file = joinpath(path_case(inputs), bidding_group_complementary_grouping_profile_file(inputs))
            num_errors += initialize_time_series_view_from_external_file(
                inputs.time_series.complementary_grouping_profile,
                inputs,
                file;
                expected_unit = "-",
                labels_to_read = bidding_group_label(inputs),
            )

            file = joinpath(path_case(inputs), bidding_group_minimum_activation_level_profile_file(inputs))
            num_errors += initialize_time_series_view_from_external_file(
                inputs.time_series.minimum_activation_level_profile,
                inputs,
                file;
                expected_unit = "-",
                labels_to_read = bidding_group_label(inputs),
            )
        end
    end
    # Virtual reservoir offers
    if (
           run_mode(inputs) == RunMode.STRATEGIC_BID ||
           is_market_clearing(inputs)
       ) && any_elements(inputs, VirtualReservoir) && read_bids_from_file(inputs)
        file = joinpath(path_case(inputs), virtual_reservoir_quantity_offer_file(inputs))
        num_errors += initialize_virtual_reservoir_bids_view_from_external_file!(
            inputs.time_series.virtual_reservoir_quantity_offer,
            inputs,
            file;
            expected_unit = "MWh",
            possible_expected_dimensions = [
                [:period, :scenario, :bid_segment],
            ],
            virtual_reservoirs_to_read = virtual_reservoir_label(inputs),
            asset_owners_to_read = asset_owner_label(inputs),
        )

        file = joinpath(path_case(inputs), virtual_reservoir_price_offer_file(inputs))
        num_errors += initialize_virtual_reservoir_bids_view_from_external_file!(
            inputs.time_series.virtual_reservoir_price_offer,
            inputs,
            file;
            expected_unit = raw"$/MWh",
            possible_expected_dimensions = [
                [:period, :scenario, :bid_segment],
            ],
            virtual_reservoirs_to_read = virtual_reservoir_label(inputs),
            asset_owners_to_read = asset_owner_label(inputs),
        )
    end

    # Elastic demand price
    if any_elements(inputs, DemandUnit; filters = [is_elastic]) && need_demand_price_input_data(inputs)
        num_errors += initialize_time_series_view_from_external_file(
            inputs.time_series.elastic_demand_price,
            inputs,
            joinpath(path_case(inputs), demand_unit_elastic_demand_price_file(inputs));
            expected_unit = raw"$/MWh",
            possible_expected_dimensions = [
                [:period, :scenario, :subperiod],
            ],
            labels_to_read = elastic_demand_labels(inputs),
        )
    end

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
            read_time_series_view_from_external_file!(
                inputs,
                ts;
                period,
                scenario,
            )
        end
        if isa(ts, HourSubperiodMapping) && ts.reader !== nothing
            update_hour_subperiod_mapping!(inputs; period = period_index_in_year(inputs, period))
        end
        if isa(ts, BidsView) && ts.reader !== nothing
            has_profile_bids = field == :quantity_offer_profile
            read_bids_view_from_external_file!(
                inputs,
                ts;
                period,
                scenario,
                has_profile_bids,
            )
        end
        if isa(ts, VirtualReservoirBidsView) && ts.reader !== nothing
            read_virtual_reservoir_bids_view_from_external_file!(
                inputs,
                ts;
                period,
                scenario,
            )
        end
        if isa(ts, ExAnteAndExPostTimeSeriesView)
            if has_ex_ante_time_series(ts)
                read_time_series_view_from_external_file!(
                    inputs,
                    ts.ex_ante;
                    period,
                    scenario,
                )
            end
            if has_ex_post_time_series(ts)
                read_time_series_view_from_external_file!(
                    inputs,
                    ts.ex_post;
                    period,
                    scenario,
                )
            end
        end
    end
    if any_elements(inputs, DemandUnit; filters = [is_flexible])
        fill_flexible_demand_window_caches!(inputs, time_series.demand_window.data)
    end

    return nothing
end

function update_segments_profile_dimensions!(inputs, period)
    if !any_elements(inputs, BiddingGroup)
        return nothing
    end
    if run_mode(inputs) in [RunMode.STRATEGIC_BID, RunMode.PRICE_TAKER_BID]
        # Isso é necessário? Já não foi inicializado com 1?
        update_number_of_bg_valid_bidding_segments!(inputs, ones(Int, number_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])))
        update_maximum_number_of_bg_bidding_segments!(inputs, 1)
        return nothing
    end
    if is_market_clearing(inputs)
        if generate_heuristic_bids_for_clearing(inputs)
            # TODO: In the heuristic case, the number of segments doesn't
            # change with the period
        elseif read_bids_from_file(inputs)
            update_segments_profile_dimensions_by_timeseries!(inputs, period)
        end
    end
    return nothing
end

function update_segments_profile_dimensions_by_timeseries!(inputs, period)
    time_series = inputs.time_series
    ts_quantity_offer = time_series.quantity_offer
    ts_quantity_offer_profile = time_series.quantity_offer_profile
    ts_virtual_reservoir_quantity_offer = time_series.virtual_reservoir_quantity_offer

    # Start with 0 segments and profiles to update it later

    number_of_bidding_groups = length(index_of_elements(inputs, BiddingGroup))
    number_of_virtual_reservoirs = length(index_of_elements(inputs, VirtualReservoir))

    total_valid_segments_per_period = zeros(Int, number_of_bidding_groups)
    total_valid_profiles_per_period = zeros(Int, number_of_bidding_groups)
    total_valid_vr_segments_per_period = zeros(Int, number_of_virtual_reservoirs)

    for scenario in 1:number_of_scenarios(inputs)
        has_profile_bids = false
        read_bids_view_from_external_file!(
            inputs,
            ts_quantity_offer;
            period = period,
            scenario = scenario,
            has_profile_bids,
        )

        valid_segments_per_timeseries = calculate_maximum_valid_segments_or_profiles_per_timeseries(
            inputs,
            ts_quantity_offer;
            has_profile_bids = has_profile_bids,
        )

        total_valid_segments_per_period =
            max.(
                valid_segments_per_timeseries,
                total_valid_segments_per_period,
            )

        if has_any_profile_bids(inputs)
            has_profile_bids = true
            read_bids_view_from_external_file!(
                inputs,
                ts_quantity_offer_profile;
                period = period,
                scenario = scenario,
                has_profile_bids,
            )

            valid_profiles_per_timeseries = calculate_maximum_valid_segments_or_profiles_per_timeseries(
                inputs,
                ts_quantity_offer_profile;
                has_profile_bids = has_profile_bids,
            )

            total_valid_profiles_per_period =
                max.(
                    valid_profiles_per_timeseries,
                    total_valid_profiles_per_period,
                )

            update_number_of_bid_profiles!(inputs, valid_profiles_per_timeseries)
        end

        if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
            read_virtual_reservoir_bids_view_from_external_file!(
                inputs,
                ts_virtual_reservoir_quantity_offer;
                period = period,
                scenario = scenario,
            )
            valid_segments_per_timeseries = calculate_maximum_valid_segments_or_profiles_per_timeseries(
                inputs,
                ts_virtual_reservoir_quantity_offer;
                has_profile_bids = false,
                is_virtual_reservoir = true,
            )

            total_valid_vr_segments_per_period =
                max.(
                    valid_segments_per_timeseries,
                    total_valid_vr_segments_per_period,
                )
        end
    end

    update_number_of_bg_valid_bidding_segments!(inputs, total_valid_segments_per_period)
    update_number_of_bid_profiles!(inputs, total_valid_profiles_per_period)
    update_number_of_vr_valid_bidding_segments!(inputs, total_valid_vr_segments_per_period)

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
            @info("   $(field)")
        end
    end
end
