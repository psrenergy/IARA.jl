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

# Extend the horizon from 4 to 6 periods. This runs before the elastic demand
# and renewables modifications, which rewrite every period-dimensioned time
# series file (bids, bid justifications, demand, solar generation and elastic
# demand price) sized by number_of_periods. Those series are constant across
# periods, so the two new periods repeat the existing ones
number_of_periods = 6

IARA.update_configuration!(
    db;
    number_of_periods = number_of_periods,
)

IARA.close_study!(db)
