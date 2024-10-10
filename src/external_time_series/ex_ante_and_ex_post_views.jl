#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

"""
    ExAnteAndExPostTimeSeriesView{T, N}

Some time series can come in two flavours:

1 - Ex-Ante (DA) time series: These are time series that are available before the stages of operation. They are used to make decisions for the next stage.
2 - Ex-Post (RT) time series: These are time series that are available on the stage of operation. They are used to make decisions for the current stage.

In some use cases it is necessary to have both time series available. This view is used to store both time series in a single object.
If the Ex-Post (RT) time series is nit available it will default to use the Ex-Ante (DA) time series.

Besides the conceptual idea about the time of availability of the data there is one concrete difference between the two time series:
The Ex-Post (RT) time series always have one dimension more than the Ex-Ante (DA) time series. This extra dimension is called `subscenario`.
For a given stage and scenario that the model made a decision we can use multiple new scenarios of the Ex-Post (RT) time series. This is the `subscenario` dimension.
"""
@kwdef mutable struct ExAnteAndExPostTimeSeriesView{T, N, M} <: ViewFromExternalFile
    ex_ante::TimeSeriesView{T, N} = TimeSeriesView{T, N}()
    ex_post::TimeSeriesView{T, M} = TimeSeriesView{T, M}()
end

function Base.isempty(ts::ExAnteAndExPostTimeSeriesView)
    return isempty(ts.ex_ante) && isempty(ts.ex_post)
end

function Base.getindex(time_series::ExAnteAndExPostTimeSeriesView, inds...)
    return getindex(time_series.ex_ante, inds...)
end

function has_ex_ante_time_series(ts::ExAnteAndExPostTimeSeriesView)
    return ts.ex_ante.reader !== nothing
end
function has_ex_post_time_series(ts::ExAnteAndExPostTimeSeriesView)
    return ts.ex_post.reader !== nothing
end

function initialize_da_and_rt_time_series_view_from_external_files!(
    ts::ExAnteAndExPostTimeSeriesView,
    inputs,
    file_path::AbstractString;
    expected_unit::String = "",
    labels_to_read::Vector{String} = String[],
)
    # Validate that the ExAnteAndExPostTimeSeriesView was correectly initialized
    if ndims(ts.ex_ante.data) != ndims(ts.ex_post.data) - 1
        error(
            "The ExAnte time series must have one dimension less than the ExPost time series. " *
            "The ExAnte time series has $(ndims(ts.ex_ante.data)) dimensions and the ExPost " *
            "time series has $(ndims(ts.ex_post.data)) dimensions.")
    end

    num_errors = 0

    # Build file paths
    ex_ante_file = file_path * "_ex_ante"
    ex_post_file = file_path * "_ex_post"

    # Check if the day ahead and real time files exist
    # If they exist we must initialize both time series
    # If they don`t exist we must initialize only the day ahead time series
    if quiver_file_exists(ex_ante_file) && quiver_file_exists(ex_post_file)
        # Initialize both time series
        num_errors += initialize_time_series_view_from_external_file(
            ts.ex_ante,
            inputs,
            ex_ante_file;
            expected_unit = expected_unit,
            labels_to_read = labels_to_read,
        )
        num_errors += initialize_time_series_view_from_external_file(
            ts.ex_post,
            inputs,
            ex_post_file;
            expected_unit = expected_unit,
            labels_to_read = labels_to_read,
        )
        # subscenario dimension should always be after stage and scenario
        @assert ts.ex_post.reader.metadata.dimensions[3] == :subscenario
    else
        num_errors += initialize_time_series_view_from_external_file(
            ts.ex_ante,
            inputs,
            file_path;
            expected_unit = expected_unit,
            labels_to_read = labels_to_read,
        )
    end

    return num_errors
end

function Base.close(ts::ExAnteAndExPostTimeSeriesView)
    Base.close(ts.ex_ante)
    Base.close(ts.ex_post)
    return nothing
end
