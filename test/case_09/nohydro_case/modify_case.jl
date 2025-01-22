db = IARA.load_study(PATH; read_only = false)

IARA.delete_element!(
    db,
    "HydroUnit",
    "Hydro Upstream",
)

IARA.delete_element!(
    db,
    "HydroUnit",
    "Hydro Downstream",
)

IARA.close_study!(db)
