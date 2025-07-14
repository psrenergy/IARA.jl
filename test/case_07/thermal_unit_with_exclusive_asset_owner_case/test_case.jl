module TestCase07ThermalUnitWithExclusiveAssetOwnerCase

using Test
using IARA

const PATH = @__DIR__

db = nothing
try
    include("../base_case/build_case.jl")
    include("../virtual_reservoir_and_thermal/modify_case.jl")
    include("modify_case.jl")
finally
    if db !== nothing
        IARA.close_study!(db)
    end
end

IARA.train_min_cost(PATH; plot_outputs = false, delete_output_folder_before_execution = true)
mv(joinpath(PATH, "outputs", "cuts.json"), joinpath(PATH, "cuts.json"); force = true)

IARA.market_clearing(PATH; plot_outputs = false, delete_output_folder_before_execution = true)

if Main.UPDATE_RESULTS
    Main.update_outputs!(PATH)
else
    Main.compare_outputs(PATH;
        test_only_subperiod_sum = [
            "deficit",
            "hydro_generation",
            "hydro_minimum_outflow_slack",
            "hydro_om_costs",
            "hydro_turbining",
            "hydro_minimum_outflow_violation_cost_expression",
        ],
        skipped_outputs = [
            "hydro_final_volume",
            "hydro_initial_volume",
        ],
    )
end

end
