db = IARA.load_study(PATH; read_only = false)

IARA.update_configuration!(db;
    virtual_reservoir_initial_energy_account_share = IARA.Configurations_VirtualReservoirInitialEnergyAccount.CALCULATED_USING_ENERGY_ACCOUNT_SHARES,
)

IARA.PSRDatabaseSQLite.update_vector_parameters!(
    db,
    "VirtualReservoir",
    "initial_energy_account_share",
    "virtual_reservoir_1",
    [0.3, 0.7],
)

IARA.close_study!(db)
