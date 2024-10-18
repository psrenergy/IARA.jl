#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

import Pkg
Pkg.instantiate()

using Documenter
using Literate

Pkg.activate(dirname(@__DIR__))
Pkg.instantiate()
using Dates
using DataFrames
using IARA

tutorial_dir = joinpath(@__DIR__, "src", "tutorial")
for file in readdir(tutorial_dir)
    if occursin(".jl", file)
        Literate.markdown(
            joinpath(tutorial_dir, "$file"),
            tutorial_dir;
            documenter = true)
    end
end

DocMeta.setdocmeta!(
    IARA,
    :DocTestSetup,
    :(using IARA);
    recursive = true,
)

pages = [
    "Home" => "index.md",
    "Conceptual" => [
        "Overview" => "conceptual_overview.md",
        "Formulation" => [
            "Centralized Operation Problem" => "centralized_operation_problem.md",
            "Price Taker Problem" => "price_taker_problem.md",
            "Strategic Bid Problem" => "strategic_bid_problem.md",
            "Market Clearing Problem" => "market_clearing_problem.md",
        ],
    ],
    "Tutorial" => [
        "Index" => "tutorial_index.md",
        "Case 1" => [
            "tutorial/build_base_case.md",
            "tutorial/run_base_case.md",
        ],
        "Case 2" => [
            "tutorial/build_hydroplant_base_case.md",
            "tutorial/run_hydroplant_base_case.md",
        ],
        "Case 3" => [
            "tutorial/build_multi_hour_base_case.md",
            "tutorial/run_multi_hour_base_case.md",
        ],
        "Case 4" => [
            "tutorial/build_multi_min_activation.md",
            "tutorial/run_multi_min_activation.md",
        ],
        "Case 5" => [
            "tutorial/build_reservoir_case.md",
            "tutorial/run_reservoir_case.md",
        ],
    ],
    "Use Guides" => "use_guides.md",
    "Developer Docs" => [
        "Contributing" => "contributing.md",
        "Development guides" => "development_guides.md",
    ],
    "API Reference" => "api_reference.md",
]

makedocs(;
    modules = [IARA],
    doctest = false,
    # clean = true,
    format = Documenter.HTML(;
        mathengine = Documenter.MathJax2(),
        prettyurls = false,
        edit_link = nothing,
        footer = nothing,
        disable_git = true,
        repolink = nothing,
        size_threshold_ignore = ["api_reference.md"],
    ),
    sitename = "IARA",
    warnonly = true,
    pages = pages,
)

# Remove the tutorial files from the docs
for file in readdir(tutorial_dir)
    if occursin(".md", file)
        rm(joinpath(tutorial_dir, file))
    end
end
