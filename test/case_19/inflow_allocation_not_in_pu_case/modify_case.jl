db = IARA.load_study(PATH; read_only = false)
 
IARA.PSRDatabaseSQLite.update_vector_parameters!(
    db,
    "VirtualReservoir",
    "inflow_allocation",
    "VR 1",
    [21.0, 9.0],
)

IARA.PSRDatabaseSQLite.update_vector_parameters!(
    db,
    "VirtualReservoir",
    "inflow_allocation",
    "VR 2",
    [1.0, 1.0],
)

IARA.close_study!(db)