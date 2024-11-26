db = IARA.load_study(PATH; read_only = false)

IARA.update_configuration!(db;
    reservoirs_physical_virtual_correspondence_type = IARA.Configurations_ReservoirsPhysicalVirtualCorrespondenceType.BY_VOLUME,
)

IARA.close_study!(db)
