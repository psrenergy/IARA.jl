db = IARA.load_study(PATH; read_only = false)

IARA.update_virtual_reservoir!(
    db,
    "virtual_reservoir_1";
    initial_energy_account_share = [30.0, 70.0],
)

IARA.close_study!(db)
