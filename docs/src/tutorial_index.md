# Tutorial Index

Here you can find a description of the tutorials available in this documentation. 

The data used to build each case is available in the folder [`data`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data), inside `docs/src/tutorial` in the repository.

## Getting started

### Case 1: Base Case

#### [Building](tutorial/case_01_build_base_case.md)

This tutorial describes the steps to build a simple case comprised of 5 thermal units and a renewable unit. All plants are connected to a single bus. The case is used to illustrate the basic functionalities of the library,including the setup of temporal parameters, asset owners, financial elements, and the linking of time series data for demand and generation.

#### [Running](tutorial/case_01_run_base_case.md)

In this section, we demonstrate how to run the base case with two different run modes:
- **Centralized Operation**
- **Market Clearing**

### Case 2: Introducing a Hydro Unit

#### [Building](tutorial/case_02_build_hydrounit_base_case.md)

For this case, we introduce a hydro unit to the [Base Case](tutorial/build_base_case.md). The hydro unit is connected to the same bus as the thermal and renewable units. This tutorial describes the steps to build the case, including the setup of the hydro unit and the linking of time series data for inflow.

#### [Running](tutorial/case_02_run_hydrounit_base_case.md)

In this section, we demonstrate how to run the case with the hydro unit with two different run modes:
- **Centralized Operation**
- **Market Clearing**

## Deep dive into Clearing

### Case 3: Introducing Multi-hour Bidding

#### [Building](tutorial/case_03_build_profile_base_case.md)

In this case we introduce multi-hour bidding with a new case, that includes only two Bidding Groups.

#### [Running](tutorial/case_03_run_profile_base_case.md)

For this instance, we will be running the case using the **Centralized Operation** run mode.

### Case 4: Multi-hour Bidding Advanced

#### [Building](tutorial/case_04_build_multi_min_activation.md)

In this case we start from [Case 3](tutorial/case_03_build_profile_base_case.md) and introduce a minimum activation for one of the Bidding Groups.

#### [Running](tutorial/case_04_run_multi_min_activation.md)

For this instance, we will be running the case using the **Centralized Operation** run mode.

## Virtual Reservoirs

### Case 5: Introducing Virtual Reservoirs

#### [Building](tutorial/case_05_build_reservoir_case.md)

In this case we introduce the concept of a Virtual Reservoir, giving a simple example of two Asset Owners with different bidding offers linked to the same Virtual Reservoir.

#### [Running](tutorial/case_05_run_reservoir_case.md)

For this instance, we will be running the case using the **Market Bidding** run mode.

## Case 6: Advanced Concepts in Policy Graphs

#### [Building](tutorial/case_06_build_policy_graph.md)
#### [Running](tutorial/case_06_run_policy_graph.md)

In this section we will introduce the concept of Policy Graphs, starting with a simple linear graph and moving to more complex structures.

## Advanced Topics

### Case 7: Introducing Modification Parameters

#### [Building and Running](tutorial/case_07_modifications_case.md)

In this case we introduce the concept of Modification Parameters, which allow the user to set changes in the case elements at specific points in time.

### Custom Plots

#### [Tutorial](tutorial/plots_tutorial.md)

In this tutorial we show how to create custom plots based on case results.
