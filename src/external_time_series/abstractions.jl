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
    ViewFromExternalFile

An abstract type that represents a view of a time series that is stored in an external file.
A view represents a chunck of the data in the file. The implementation goal is to avoid
loading the entire file into memory.
"""
abstract type ViewFromExternalFile end

function Base.isempty(ts::ViewFromExternalFile)
    return ts.reader === nothing
end

function Base.close(ts::ViewFromExternalFile)
    if !isempty(ts)
        Quiver.close!(ts.reader)
    end
    return nothing
end
