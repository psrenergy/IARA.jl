db = IARA.load_study(PATH; read_only = false)

IARA.PSRDatabaseSQLite.update_vector_parameters!(
    db,
    "VirtualReservoir",
    "initial_energy_account_share",
    "virtual_reservoir_1",
    [30.0, 70.0],
)

IARA.close_study!(db)
