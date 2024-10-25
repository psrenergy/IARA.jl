using IARA, DataFrames, CSV

db = IARA.load_study(PATH; read_only = false)

IARA.update_configuration!(db;
    virtual_reservoir_waveguide_source = IARA.Configurations_VirtualReservoirWaveguideSource.USER_PROVIDED,
    waveguide_user_provided_source = IARA.Configurations_WaveguideUserProvidedSource.CSV_FILE,
)

IARA.update_virtual_reservoir!(db, "virtual_reservoir_1"; number_of_waveguide_points_for_file_template = 3)

waveguide_points = [
    0.0 0.0
    0.0 0.108
    0.108 0.108
]

df = DataFrame(waveguide_points, ["hydro_1", "hydro_2"])
filepath = IARA.virtual_reservoir_waveguide_filename(PATH, "virtual_reservoir_1")
CSV.write(filepath, df)

IARA.close_study!(db)
