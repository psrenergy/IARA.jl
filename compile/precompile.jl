import Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using IARA
compilation_case_01 = joinpath("./compilation_case_1")
case_name = "boto_base_01"
IARA.ExampleCases.build_example_case(compilation_case_01, case_name)

IARA.market_clearing(
    compilation_case_01;
    delete_output_folder_before_execution = true,
);

lmc_name = "load_marginal_cost_ex_post_physical.csv"
lmc_path = joinpath(compilation_case_01, "outputs", lmc_name)
IARA.custom_plot(lmc_path, IARA.PlotTimeSeriesMean)
