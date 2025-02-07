function timeseries_file_extension(file_path::String)
    if isfile(file_path * ".csv")
        return ".csv"
    elseif isfile(file_path * ".quiv")
        return ".quiv"
    else
        return ""
    end
end
