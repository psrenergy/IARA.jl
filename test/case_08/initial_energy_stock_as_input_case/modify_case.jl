db = IARA.load_study(PATH; read_only = false)

IARA.update_configuration!(db;
    virtual_reservoirs_initial_energy_stock_source = IARA.Configurations_VirtualReservoirInitialEnergyStockSource.USER_DEFINED,
)

IARA.PSRDatabaseSQLite.update_vector_parameters!(
    db,
    "VirtualReservoir",
    "initial_energy_stock_share",
    "virtual_reservoir_1",
    [0.3, 0.7],
)

IARA.close_study!(db)
