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
if !isdir(joinpath(PATH, "parp"))
    mkdir(joinpath(PATH, "parp"))
end

months_in_year = 12
parp_max_lags = 6

IARA.update_configuration!(
    db;
    inflow_model = IARA.Configurations_InflowModel.READ_PARP_COEFFICIENTS,
)
inflow_noise_vector = [
    -0.359729, 1.087208, -0.41959, 0.71891, 0.420247, -0.685671, 2.054763, 0.324893, -0.304901, 0.461695, -0.844958,
    0.886712,
]

parp_coefficients_vector = [
    0.008858,
    1.156036,
    0.0,
    -1.040942,
    0.34462,
    0.0,
    -1.689399,
    1.513022,
    0.0,
    0.0,
    -0.619175,
    -0.001954,
    0.414042,
    -2.57022,
    0.0,
    4.795635,
    0.0,
    -3.826926,
    0.807279,
    -0.599425,
    -1.604563,
    0.0,
    0.404166,
    0.0,
    -0.558262,
    0.783189,
    0.407499,
    0.0,
    0.0,
    -0.19384,
    0.0,
    -0.101936,
    -0.382069,
    -0.942211,
    0.0,
    -0.75115,
    0.798837,
    -0.202437,
    0.0,
    0.32354,
    0.0,
    -0.588692,
    0.0,
    0.787174,
    0.0,
    -0.433542,
    1.28866,
    0.906851,
    1.164445,
    0.0,
    -0.445199,
    0.0,
    0.259719,
    -1.005205,
    0.527855,
    -0.127252,
    0.0,
    -0.090405,
    0.0,
    0.50146,
    -0.179483,
    0.337359,
    -0.0184,
    0.0,
    -0.631012,
    0.0,
    0.0,
    0.689586,
    0.391315,
    -0.115726,
    0.0,
    -0.284529,
]

inflow_period_average_vector = [
    0.648075, 0.647849, 0.598264, 0.482038, 0.334491, 0.306566, 0.257736, 0.206868, 0.18634, 0.240906, 0.288679,
    0.463925,
]

inflow_period_std_dev_vector =
    [
        0.18688,
        0.134691,
        0.1372,
        0.082807,
        0.033039,
        0.060359,
        0.038656,
        0.032727,
        0.056528,
        0.067912,
        0.045793,
        0.120473,
    ]

inflow_noise = zeros(1, number_of_scenarios, number_of_periods)
i = 0
for p in 1:number_of_periods, s in 1:number_of_scenarios
    global i += 1
    inflow_noise[1, s, p] = inflow_noise_vector[i]
end
parp_coefficients = zeros(1, parp_max_lags, months_in_year)
i = 0
for m in 1:months_in_year, l in 1:parp_max_lags
    global i += 1
    parp_coefficients[1, l, m] = parp_coefficients_vector[i]
end
inflow_period_average = zeros(1, months_in_year)
inflow_period_average[1, :] = inflow_period_average_vector
inflow_period_std_dev = zeros(1, months_in_year)
inflow_period_std_dev[1, :] = inflow_period_std_dev_vector

IARA.write_timeseries_file(
    joinpath(PATH, "parp", "inflow_noise_ex_ante"),
    inflow_noise;
    dimensions = ["period", "scenario"],
    labels = ["gs_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)
IARA.write_timeseries_file(
    joinpath(PATH, "parp", "parp_coefficients"),
    parp_coefficients;
    dimensions = ["inflow_period", "lag"],
    labels = ["gs_1"],
    time_dimension = "inflow_period",
    dimension_size = [months_in_year, parp_max_lags],
    initial_date = "2020-01-01T00:00:00",
    unit = "-",
)
IARA.write_timeseries_file(
    joinpath(PATH, "parp", "inflow_period_average"),
    inflow_period_average;
    dimensions = ["inflow_period"],
    labels = ["gs_1"],
    time_dimension = "inflow_period",
    dimension_size = [months_in_year],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)
IARA.write_timeseries_file(
    joinpath(PATH, "parp", "inflow_period_std_dev"),
    inflow_period_std_dev;
    dimensions = ["inflow_period"],
    labels = ["gs_1"],
    time_dimension = "inflow_period",
    dimension_size = [months_in_year],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

IARA.link_time_series_to_file(
    db,
    "GaugingStation";
    inflow_noise_ex_ante = "inflow_noise_ex_ante",
    parp_coefficients = "parp_coefficients",
    inflow_period_average = "inflow_period_average",
    inflow_period_std_dev = "inflow_period_std_dev",
)

IARA.close_study!(db)
