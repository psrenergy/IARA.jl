#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

db = IARA.load_study(PATH; read_only = false)

maximum_number_of_bidding_profiles = 2

minimum_activation_level_multihour =
    zeros(
        number_of_bidding_groups,
        maximum_number_of_bidding_segments,
        number_of_scenarios,
        number_of_periods,
    )

minimum_activation_level_multihour[2, :, :, :] .= 0.0
IARA.write_timeseries_file(
    joinpath(PATH, "minimum_activation_level_multihour"),
    minimum_activation_level_multihour;
    dimensions = ["period", "scenario", "profile"],
    labels = ["bg_1", "bg_2"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "-",
)

parent_profile_multihour =
    zeros(
        number_of_bidding_groups,
        maximum_number_of_bidding_segments,
        number_of_periods,
    )

parent_profile_multihour[2, 2, :] .= 0
IARA.write_timeseries_file(
    joinpath(PATH, "parent_profile_multihour"),
    parent_profile_multihour;
    dimensions = ["period", "profile"],
    labels = ["bg_1", "bg_2"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "-",
)

number_of_complementary_groups = 3
complementary_grouping_multihour =
    zeros(
        number_of_bidding_groups,
        number_of_complementary_groups,
        maximum_number_of_bidding_profiles,
        number_of_periods,
    )

complementary_grouping_multihour[2, 1, :, :] .= 1
complementary_grouping_multihour[2, 2, 1, :] .= 1
complementary_grouping_multihour[2, 3, 2, :] .= 1
IARA.write_timeseries_file(
    joinpath(PATH, "complementary_grouping_multihour"),
    complementary_grouping_multihour;
    dimensions = ["period", "profile", "complementary_group"],
    labels = ["bg_1", "bg_2"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        maximum_number_of_bidding_profiles,
        number_of_complementary_groups,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "-",
)

IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    minimum_activation_level_multihour = "minimum_activation_level_multihour",
    parent_profile_multihour = "parent_profile_multihour",
    complementary_grouping_multihour = "complementary_grouping_multihour",
)

IARA.close_study!(db)
