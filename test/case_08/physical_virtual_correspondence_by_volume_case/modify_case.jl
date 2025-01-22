db = IARA.load_study(PATH; read_only = false)

IARA.update_configuration!(db;
    virtual_reservoir_correspondence_type = IARA.Configurations_VirtualReservoirCorrespondenceType.STANDARD_CORRESPONDENCE_CONSTRAINT,
)

IARA.close_study!(db)
