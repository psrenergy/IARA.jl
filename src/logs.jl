function set_global_logger(logger_path::String)
    level = Dict(
        "Debug Level" => "debug",
        "Debug" => "debug",
        "Info" => "",
        "Warn" => "warn",
        "Error" => "error",
        "Fatal Error" => "fatal",
    )
    color = Dict(
        "Debug Level" => :cyan,
        "Debug" => :cyan,
        "Info" => :cyan,
        "Warn" => :yellow,
        "Error" => :red,
        "Fatal Error" => :red,
    )
    background = Dict(
        "Debug Level" => false,
        "Debug" => false,
        "Info" => false,
        "Warn" => false,
        "Error" => false,
        "Fatal Error" => true,
    )
    bracket_dict = Dict(
        "Debug Level" => ["[", "]"],
        "Debug" => ["[", "]"],
        "Info" => ["", ""],
        "Warn" => ["[", "]"],
        "Error" => ["[", "]"],
        "Fatal Error" => ["[", "]"],
    )

    logger = Log.create_polyglot_logger(
        logger_path;
        level_dict = level,
        color_dict = color,
        background_reverse_dict = background,
        bracket_dict = bracket_dict,
    )

    return logger
end

function initialize_logger(args::Args)
    Log.close_polyglot_logger()
    logger_path = joinpath(args.outputs_path, "iara.log")
    if isfile(logger_path)
        rm(logger_path; force = true)
    end
    logger = set_global_logger(logger_path)
    return logger
end

function finalize_logger()
    Log.close_polyglot_logger()
    # back to default logger
    logger = Log.Logging.ConsoleLogger()
    Log.Logging.global_logger(logger)
    return nothing
end
