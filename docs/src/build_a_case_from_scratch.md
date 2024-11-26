# Introduction: Building a case from scratch

The best way to learn is by doing - we ecourage you to explore the tutorial for the [construction of a simple case](tutorial/build_base_case.md). This page explains conceptually the step by step process that is followed in each of these examples in order to build each of the [key components](key_features.md#iara's-physical-system-data) of a IARA database, which should be applicable to any type of case.

## Building the temporal structure

Given that [intertemporality is a key component](hydro_challenges.md) of realistic electricity systems IARA is meant to represent, having a well-defined temporal structure is a key component for IARA execution, as this profoundly affects the decision-making process in the model. The fundamental language for the representation of this temporal structure is the "Policy graph", as described in detail in the [SDDP.jl documentation](https://sddp.dev/stable/tutorial/first_steps/). Further explorations of the options available for constructing a Policy Graph in IARA are presented in a [dedicated page](intro_policy_graph.md) that introduces the complexities associated with the Policy Graph representation step by step.

Policy graph parameters are usually passed directly when calling the `create_study!` function, with the following key parameters being related to policy graph construction. Please refer to [IARA's standard nomenclature](key_features.md#glossary) for further explanations on the jargon used (e.g. subperiods, seasons, cycles, etc.):

- `number_of_subperiods` is an integer that indicates how many subperiods are included when simulating each period, using. Note that a "period" represents a block of decisions made at once (e.g. looking at an entire day, week, month, etc.) and a "subperiod" corresponds to subdivisions within that period for simulation and optimization purposes (e.g. broken down into days, hourly intervals, 15-minute intervals, etc.)
- `subperiod_duration_in_hours` is a vector that indicates the length of each subperiod - therefore, the length of this vector corresponds to the number of subperiods represented. The duration of each "representative subproblem" will be equal to the sum of the elements in the `subperiod_duration_in_hours`. Each season's representative subproblem will have the same duration.
- `expected_number_of_repeats_per_node` is a vector that indicates, for each season, how many times the "representative subproblem" is expected to repeat in order to constitute the total length of the season. This must be a number greater than or equal to one (but can be fractional), and the expected duration of the season as a whole is equal to the product of all three parameters: the `subperiod_duration_in_hours`, the  `number_of_subperiods`, and the `expected_number_of_repeats_per_node`.
- `cycle_duration_in_hours` is a real number that can be used either to validate the total duration of the cycle (calculated from adding up the expected duration as a whole of each season as described above) or to introduce an adjustment multiplier. Note that in the cycle represents one year, this parameter should always be equal to 8760 hours, but it is useful to have the flexibility to change this definition.
- `cycle_discount_rate` is a real number that describes how much future periods are discounted relative to the present, expressed as a discrete one-time discount after the entire duration of a cycle (which is a common way to express this parameter in economic applications). In practice, IARA will distribute this yearly discount rate as a discount that is applied after each season's representative subproblem (based on the corresponding duration), in such a way that the cumulative effect over the course of a period with length equal to `cycle_duration_in_hours` is equivalent to applying the `cycle_discount_rate`.
- `policy_graph_type` is an enumeration parameter that allows for different [policy graph representation paradigms](intro_policy_graph.md). IARA's default representation is a "cyclic" policy graph.

When calling the `create_study!` function, it is also possible to define additional parameters that describe the dimensions of the study execution, as detailed below (once again, refer to [this page](key_features.md#glossary) for nomenclature and definitions). One important distinction is that, while the parameters used to define the policy graph are in a sense more "fundamental" in describing the physical nature of the problem, the number of periods, scenarios and subscenarios in essence represent a choice of how many samples one wishes to model, taking into account computational limitations. Nonetheless, these parameters will have an influence when [building time series data](#building-external-data-structures) to finalize the database creation:

- `number_of_periods` represents how many subproblems (representative of each season) will be modeled sequentially in the execution
- `number_of_scenarios` represents how many subproblems (representative of each season) will be modeled in parallel (i.e. representing independent trajectories) in the execution
- `number_of_subscenarios` represents how many "openings" of each trajectory (represented by the "scenarios") will be modeled, with an impact on the [structure of subproblems to be modeled](clearing_process.md)

Note that the output of the `create_study!` function is a database object, `db`. In all subsequent steps for creating the database, the `db` object is the first parameter that ought to be passed for most functions (marked by a `!` as the last character of the function signature).

## Building the spatial structure

The spatial structure is characterized by a network of *buses* organized into *zones*. The entities that characterize the spatial structure are created by calling the following functions:

- `add_zone!` introduces a Zone to the study
- `add_bus!` introduces a Bus to the study and links it to a Zone
- `add_dc_line!` introduces a connection in direct current (DC) to the study, linking it to the two buses that are connected by this physical line (a "starting" bus and an "ending" bus), and defining relevant physical parameters for modelling the line's physical features
- `add_branch!` introduces an electrical connection (a transmission line in alternate current or a transformer) to the study, linking it to the two buses that are connected by this physical line (a "starting" bus and an "ending" bus), and defining relevant physical parameters for modelling the branch's physical features

Because all [Units](#building-the-unit-structure) will later need to be placed in this spatial structure, this is a fundamental component for input data. Conceptually, the system operator's optimization problem for making economic dispatch decisions in an electricity system can either be constructed on a "zonal" basis (with one supply-demand balance constraint per zone) or on a "nodal" basis (with one supply-demand balance constraint per bus). Note that DC lines and Branches effectively represent "arcs" in the representation of the spatial graph, and these are assumed to be fully under the control of the system operator as long as they remain within the physical limits characterized by the lines' parameters and physical laws.

## Building the ownership structure

The ownership structure is characterized by (i) a number of *bidding groups*, (ii) a number of *virtual reservoirs*, and (iii) a number of *asset owners*. The entities that characterize the ownership structure are created by calling the following functions:

- `add_asset_owner!` introduces an Asset Owner to the study, potentially indicates that this particular agent operates as a "pricemaker" when making strategic decisions (with the default behavior being "pricetaker"), and potentially defines additional parameters useful for building the agent's preferred "pricemaker" strategy.
- `add_virtual_reservoir!` introduces a Virtual Reservoir to the study, and indicates which asset owners are registered to make [virtual reservoir bids](conceptual_formulation.md#the-virtual-reservoir-representation) on this virtual reservoir. Note that the relationship between virtual reservoirs and asset owners is one-to-many, and a "virtual reservoir account" is characterized by the combination of a virtual reservoir and an asset owner.
- `add_bidding_group!` introduces a Bidding Group to the study, linking it to a single asset owner responsible for submitting the associated bids, and introducing parameters relevant for describing heuristic bid strategies specific for the bidding group.

Note that [Units](#building-the-unit-structure) will later be associated to Bidding Groups (mandatorily) and Virtual Reservoirs (restricted to hydro-type units, optionally). Even though in a [cost-based market structure](key_features.md#optimization-problem-structure) the asset owner's strategy does not play a role, pricemaker asset owners may be able to influence the market outcomes under a bid-based market structure in accordance with their preferences. In practice, an asset owner will seek to maximize their profits (possibly adjusted for some preference parameters), taking into account the joint effect of bidding strategies applied in all bidding groups and all virtual reservoir accounts under the control of that asset owner.

## Building the unit structure

"Units" refer to any type of physical asset connected to the system which can be under the control of an [asset owner](#building-the-ownership-structure). While the diversity of Units that could potentially be contemplated in IARA is very high (with highly complex parameterizations), the current implementation focuses on four types of unit, which can be created using the following functions:

- `add_renewable_unit!` introduces a Renewable Unit to the study (representing a technology such as wind or solar, with variable and curtailable resource), links it to a Bus in the spatial structure and to a Bidding Group in the ownership structure, and defines additional physical parameters.
- `add_hydro_unit!` introduces a Hydro Unit to the study (representing a technology that has a variable resource with some flexibility to transfer resource between subperiods and/or periods), links it to a Bus in the spatial structure and to a Bidding Group in the ownership structure, and defines additional parameters.
- `add_thermal_unit!` introduces a Thermal Unit to the study (representing a technology that is more dispatchable/controllable, with parameters aiming to describe its degree of controllability), links it to a Bus in the spatial structure and to a Bidding Group in the ownership structure, and defines additional parameters.
- `add_demand_unit!` introduces a Demand Unit to the study (which typically contributes to the supply-demand balance equation with a negative sign, contrary to the other UNits above), links it to a Bus in the spatial structure and to a Bidding Group in the ownership structure, and defines additional parameters.

Note that each Unit has its own set of complex and thorough parameters, which can be assessed in the [API reference](api_reference.md). However, they all share the same basic structure of fundamentally linking to the spatial structure and the ownership structure.

## Building external data structures

"External data structures" refer to information that is available in separate files (usually in an easy-to-manipulate csv format), which the IARA database links to and accesses in order to build individual optimization subproblems. These external files can contain detailed information that varies per period, subperiod, scenario and subscenario following the study's [temporal structure](#building-the-temporal-structure).

These external links can be classified into three main groups:
- The first group corresponds to **physical time series data**, and contains information that is associated to Units with a stochastic dependency. Most prominently, this group includes the representation of demand fluctuations (tied to Demand Units), renewable production fluctuations (tied to Renewable Units), and inflow availability fluctuations (tied to Hydro Units).
- The second group corresponds to **bid time series data**, and contains information that is associated to the different types of bid that can be submitted by the agents, as described in detail in a [dedicated page](bidding_formats.md) describing the bidding formats available.
- A third group is more "**miscellaneous**", and includes other types of data that can be linked by the IARA database. One example of this category is the "curve guide" parameter inputs, which is used in the virtual reservoir representation as a "tiebreaker" function.

Generally speaking, in case a csv file has been pre-generated with the required structure of rows and columns (as exemplified in our practical examples), it is possible to link this external data structure to the database using the `link_time_series_to_file` function, following the indications shown in our [API reference](api_reference.md).

