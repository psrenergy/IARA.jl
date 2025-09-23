db = IARA.load_study(PATH; read_only = false)

IARA.update_configuration!(
    db;
    virtual_reservoir_residual_revenue_split_type =
    IARA.Configurations_VirtualReservoirResidualRevenueSplitType.BY_ENERGY_ACCOUNT_SHARES,
)

IARA.close_study!(db)
