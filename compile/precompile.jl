import Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

compile_path = @__DIR__

using IARA
compilation_case_01 = joinpath(compile_path, "compilation_case_1")
case_name = "boto_base_01"
IARA.ExampleCases.build_example_case(compilation_case_01, case_name)

IARA.market_clearing(
    compilation_case_01;
    delete_output_folder_before_execution = true,
);

lmc_name = "load_marginal_cost_ex_post_physical.csv"
lmc_path = joinpath(compilation_case_01, "outputs", lmc_name)
IARA.custom_plot(lmc_path, IARA.PlotTimeSeriesMean);

compilation_case_02 = joinpath(compile_path, "compilation_case_2")
case_name = "ui_c3"
IARA.ExampleCases.build_example_case(compilation_case_02, case_name)

IARA.InterfaceCalls.interface_call(
    compilation_case_02;
    delete_output_folder_before_execution = true,
);
IARA.single_period_heuristic_bid(
    compilation_case_02;
    period = 1,
    delete_output_folder_before_execution = true,
    plot_outputs = false,
    plot_ui_outputs = true,
);
IARA.single_period_market_clearing(
    compilation_case_02;
    period = 1,
    delete_output_folder_before_execution = true,
    plot_outputs = false,
    plot_ui_outputs = true,
);

nothing
