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

ENV["JULIA_DEBUG"] = "Documenter"

Pkg.activate(dirname(@__DIR__))
Pkg.instantiate()
using Dates
using DataFrames
using IARA

tutorial_dir = joinpath(@__DIR__, "src", "tutorial")

# List of each tutorial file
tutorial_files = [
    "first_execution.jl",
    "case_building.jl",
    "clearing_executions.jl",
    "case_01_build_base_case.jl",
    "case_01_run_base_case.jl",
    "case_02_build_hydrounit_base_case.jl",
    "case_02_run_hydrounit_base_case.jl",
    "case_03_build_profile_base_case.jl",
    "case_03_run_profile_base_case.jl",
    "case_04_build_multi_min_activation.jl",
    "case_04_run_multi_min_activation.jl",
    "case_05_build_reservoir_case.jl",
    "case_05_run_reservoir_case.jl",
    "case_06_build_policy_graph.jl",
    "case_06_run_policy_graph.jl",
    "case_07_modifications_case.jl",
    "plots_tutorial.jl",
]
if isempty(tutorial_files)
    tutorial_paths = readdir(tutorial_dir)
else
    tutorial_paths = [joinpath(tutorial_dir, file) for file in tutorial_files]
end
for file in tutorial_paths
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
    :(using IARA, Dates, DataFrames);
    recursive = true,
)

pages = [
    "About IARA" => "index.md",
    "Getting started" => [
        "My first execution" => "tutorial/first_execution.md",
        "Editing physical data" => "tutorial/case_building.md",
        "Editing clearing options" => "tutorial/clearing_executions.md",
    ],
    "Conceptual overview" => [
        "Key features of IARA" => "key_features.md",
        "The market clearing structure" => "clearing_procedure.md",
        "Hydro reservoirs, cascades and virtual reservoirs" => "hydro_challenges.md",
        "Formulations" => [
            "Conceptual formulations" => "conceptual_formulation.md",
            "Centralized operation problem" => "centralized_operation_problem.md",
            "Market clearing problem" => "market_clearing_problem.md",
            "Heuristic bids" => "heuristic_bids.md",
        ],
    ],
    "Use guides and tutorials" => [
        "Building a case from scratch" => [
            "Introduction" => "build_a_case_from_scratch.md",
            "Case creation example" => "tutorial/case_01_build_base_case.md",
        ],
        "Manipulating bid data" => [
            "Introduction" => "bidding_formats.md",
            "Profile bids example" => "tutorial/case_03_build_profile_base_case.md",
            "Minimum activation bids example" => "tutorial/case_04_build_multi_min_activation.md",
            "Virtual reservoir example" => "tutorial/case_05_build_reservoir_case.md",
        ],
        "Structuring the policy graph" => [
            "Introduction" => "intro_policy_graph.md",
            "Policy graphs example: building" => "tutorial/case_06_build_policy_graph.md",
            "Policy graphs example: running" => "tutorial/case_06_run_policy_graph.md",
        ],
        "Custom Plots" => [
            "tutorial/plots_tutorial.md",
        ],
    ],
    "Input and Outputs" => [
        "Quiver" => "quiver_format.md",
        "Input files" => "input_files.md",
        "Output files" => "output_files.md",
    ],
    "Contributing" => [
        "How to contribute" => "contributing.md",
        "Developer guides" => "development_guides.md",
    ],
    "API Reference" => "api_reference.md",
]

makedocs(;
    modules = [IARA],
    doctest = false,
    clean = true,
    format = Documenter.HTML(;
        assets = ["assets/favicon.ico"],
        mathengine = Documenter.MathJax2(),
        prettyurls = false,
        edit_link = nothing,
        footer = nothing,
        disable_git = true,
        # Disabling the size thresholds is not a good practice but 
        # it is necessary in the current state of the documentation

        # Setting it to nothing will write every example block
        example_size_threshold = nothing,
        # Setting it to nothing will ignore the size threshold
        size_threshold = nothing,
    ),
    sitename = "IARA.jl",
    authors = "psrenergy",
    warnonly = false,
    pages = pages,
    remotes = nothing,
)

# Remove the tutorial files from the docs
for file in readdir(tutorial_dir)
    if occursin(".md", file)
        rm(joinpath(tutorial_dir, file))
    end
end

deploydocs(;
    repo = "github.com/psrenergy/IARA.jl.git",
    push_preview = true,
)
