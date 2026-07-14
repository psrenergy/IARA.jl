function timeseries_file_extension(file_path::String)
    if isfile(file_path * ".csv")
        return ".csv"
    elseif isfile(file_path * ".qvr")
        return ".qvr"
    else
        return ""
    end
end
