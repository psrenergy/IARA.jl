db = IARA.load_study(PATH; read_only = false)

IARA.update_configuration!(db;
    cvar_alpha = 0.25,
    cvar_lambda = 0.5,
)

IARA.close_study!(db)
