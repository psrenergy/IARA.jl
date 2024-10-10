#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

db = load_study(PATH; read_only = false)

maximum_number_of_bidding_profiles = 2

minimum_activation_level_multihour =
    zeros(
        number_of_bidding_groups,
        maximum_number_of_bidding_segments,
        number_of_scenarios,
        number_of_stages,
    )

minimum_activation_level_multihour[2, :, :, :] .= 0.80
write_timeseries_file(
    joinpath(PATH, "minimum_activation_level_multihour"),
    minimum_activation_level_multihour;
    dimensions = ["stage", "scenario", "profile"],
    labels = ["bg_1", "bg_2"],
    time_dimension = "stage",
    dimension_size = [
        number_of_stages,
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
        number_of_stages,
    )

parent_profile_multihour[2, :, :] .= 0
write_timeseries_file(
    joinpath(PATH, "parent_profile_multihour"),
    parent_profile_multihour;
    dimensions = ["stage", "profile"],
    labels = ["bg_1", "bg_2"],
    time_dimension = "stage",
    dimension_size = [
        number_of_stages,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "-",
)

number_of_complementary_groups = 1
complementary_grouping_multihour =
    zeros(
        number_of_bidding_groups,
        number_of_complementary_groups,
        maximum_number_of_bidding_profiles,
        number_of_stages,
    )

write_timeseries_file(
    joinpath(PATH, "complementary_grouping_multihour"),
    complementary_grouping_multihour;
    dimensions = ["stage", "profile", "complementary_group"],
    labels = ["bg_1", "bg_2"],
    time_dimension = "stage",
    dimension_size = [
        number_of_stages,
        maximum_number_of_bidding_profiles,
        number_of_complementary_groups,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "-",
)

link_time_series_to_file(
    db,
    "BiddingGroup";
    minimum_activation_level_multihour = "minimum_activation_level_multihour",
    parent_profile_multihour = "parent_profile_multihour",
    complementary_grouping_multihour = "complementary_grouping_multihour",
)

close_study!(db)
