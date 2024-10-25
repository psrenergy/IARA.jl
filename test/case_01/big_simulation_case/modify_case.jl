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

# This case is built on top of the cyclic graph case

number_of_years_to_simulate = 3
new_number_of_periods = number_of_periods * number_of_years_to_simulate

IARA.update_configuration!(db;
    number_of_periods = new_number_of_periods,
)

IARA.update_hydro_unit!(
    db,
    "hyd_1";
    initial_volume = 12.0 * m3_per_second_to_hm3 * (new_subperiod_duration / subperiod_duration_in_hours) *
                     number_of_years_to_simulate,
)
IARA.update_hydro_unit_time_series_parameter!(
    db,
    "hyd_1",
    "max_volume",
    30.0 * m3_per_second_to_hm3 * (new_subperiod_duration / subperiod_duration_in_hours) * number_of_years_to_simulate;
    date_time = DateTime(0),
)

IARA.close_study!(db)
