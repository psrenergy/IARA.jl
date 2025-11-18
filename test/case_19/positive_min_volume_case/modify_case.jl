db = IARA.load_study(PATH; read_only = false)

IARA.update_hydro_unit_time_series_parameter!(
    db,
    "hydro_1",
    "min_volume",
    3.0; # 0.0 -> 3.0
    date_time = DateTime(0),
)

IARA.update_hydro_unit_time_series_parameter!(
    db,
    "hydro_1",
    "max_volume",
    10.0; # 7.0 -> 10.0
    date_time = DateTime(0),
)

IARA.update_hydro_unit!(
    db,
    "hydro_1",
    initial_volume = 3.5 # 0.5 -> 3.5
)

IARA.close_study!(db)
