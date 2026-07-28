db = IARA.load_study(PATH; read_only = false)

IARA.update_virtual_reservoir!(
    db,
    "VR 1";
    inflow_allocation = [21.0, 9.0],
)

IARA.update_virtual_reservoir!(
    db,
    "VR 2";
    inflow_allocation = [1.0, 1.0],
)

IARA.close_study!(db)
