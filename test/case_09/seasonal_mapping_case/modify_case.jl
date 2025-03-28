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

period_season_map = zeros(Int, 3, number_of_scenarios, number_of_periods)

# Seasons
period_season_map[1, 1, :] = [1, 1, 1, 2, 2, 2]
period_season_map[1, 2, :] = [1, 2, 1, 2, 1, 2]
period_season_map[1, 3, :] = [1, 1, 1, 1, 1, 1]
period_season_map[1, 4, :] = [2, 2, 2, 2, 2, 2]
period_season_map[1, 5, :] = [1, 1, 2, 2, 1, 1]
period_season_map[1, 6, :] = [2, 2, 2, 1, 1, 1]
period_season_map[1, 7, :] = [2, 1, 2, 1, 2, 1]
period_season_map[1, 8, :] = [2, 2, 1, 1, 2, 2]
period_season_map[1, 9, :] = [1, 2, 2, 2, 2, 2]
period_season_map[1, 10, :] = [2, 1, 1, 1, 1, 1]
period_season_map[1, 11, :] = [1, 1, 1, 1, 1, 2]
period_season_map[1, 12, :] = [2, 2, 2, 2, 2, 1]
# Samples
period_season_map[2, 1, :] = 1:6
period_season_map[2, 2, :] = 7:12
period_season_map[2, 3, :] = 12:-1:7
period_season_map[2, 4, :] = 6:-1:1
period_season_map[2, 5, :] = [1, 2, 3, 1, 2, 3]
period_season_map[2, 6, :] = [3, 2, 1, 3, 2, 1]
period_season_map[2, 7, :] = [4, 4, 5, 5, 6, 6]
period_season_map[2, 8, :] = [6, 6, 5, 5, 4, 4]
period_season_map[2, 9, :] = [7, 8, 9, 9, 8, 7]
period_season_map[2, 10, :] = [9, 8, 7, 7, 8, 9]
period_season_map[2, 11, :] = [10, 11, 11, 10, 12, 12]
period_season_map[2, 12, :] = [12, 10, 10, 11, 11, 12]
# Next subscenario
period_season_map[3, :, :] = copy(period_season_map[1, :, :])

IARA.write_timeseries_file(
    joinpath(PATH, "period_season_map"),
    period_season_map;
    dimensions = ["period", "scenario"],
    labels = ["season", "sample", "next_subscenario"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios],
    initial_date = "2020-01-01T00:00:00",
    unit = " ",
)

IARA.link_time_series_to_file(
    db,
    "Configuration";
    period_season_map = "period_season_map",
)

IARA.close_study!(db)
