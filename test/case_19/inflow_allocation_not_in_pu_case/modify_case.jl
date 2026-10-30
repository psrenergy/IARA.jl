db = IARA.load_study(PATH; read_only = false)

IARA.update_virtual_reservoir!(
    db,
    "VR 1";
    assetowner_id = ["AO 1", "AO 2"],
    inflow_allocation = [21.0, 9.0],
    initial_energy_account_share = [0.7, 0.3],
)

IARA.update_virtual_reservoir!(
    db,
    "VR 2";
    assetowner_id = ["AO 1", "AO 2"],
    inflow_allocation = [1.0, 1.0],
    initial_energy_account_share = [0.5, 0.5],
)

IARA.close_study!(db)
