db = IARA.load_study(PATH; read_only = false)

IARA.update_virtual_reservoir!(
    db,
    "virtual_reservoir_1";
    assetowner_id = ["asset_owner_1", "asset_owner_2"],
    inflow_allocation = [0.2, 0.8],
    initial_energy_account_share = [30.0, 70.0],
)

IARA.close_study!(db)
