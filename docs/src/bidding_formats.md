# Introduction: Bid structures and bid data

## Types of bid and data flow

Being able to describe agents' strategies in a bid-based market is one of IARA's [key features](key_features.md). IARA has three main types of bid that can be submitted by decision-making agents:

- `independent bids` refer to price-quantity offers that are associated to a single subperiod, and which can be accepted or rejected in a fully independent manner
- `profile bids` refer to price-quantity offers that represent an interdependence between different subperiods, with a single decision potentially affecting output in multiple subperiods
- `virtual reservoir bids` refer to price-quantity offers tied to [virtual reservoir accounts](build_a_case_from_scratch.md#building-the-ownership-structure), designed to combat the [externality issues involved in hydro cascades](hydro_challenges.md).

For all three types of bid, there are two possible options for managing this bid data: 

- Bid data can be produced automatically, using IARA's standard "heuristic bid" functionality that is applied by default in the course of [running a market clearing problem](key_features.md#the-market-clearing-process)
- Alternatively, bid data can be read from external files, which are referenced as [external data structures](build_a_case_from_scratch.md#building-external-data-structures) of the IARA database.

Note that, in case the heuristic bid alternative is chosen, bid files will be generated with the same structure that is expected if bids were to be read as input data.

## Price and quantity parameter data files

All three types of bid in IARA involve "price" and "quantity" information that can be expressed by a [time series file](build_a_case_from_scratch.md#building-external-data-structures), and which can be linked using the function `link_time_series_to_file`. The particulars of the time series that characterize each type of bid, however, are slightly different, particularly with regards to the representation of the [subperiod](key_features.md#glossary) dimension:

- `independent bids` have both quantities and prices varying per subperiod, as decisions are indeed individualized per subperiod. Independent bids can be parameterized using the following syntax: `link_time_series_to_file(db,"BiddingGroup"; quantity_offer = "q", price_offer = "p")`
- `profile bids` have quantities varying per subperiod but prices not: the decision on whether or not to activate the profile bid is made only once in the period (and therefore it is sufficient to represent the associated cost with a single price parameter), but potentially affects all subperiods. Profile bids can be parameterized using the following syntax: `link_time_series_to_file(db,"BiddingGroup"; quantity_offer_profile = "q", price_offer_profile = "p")`
- `virtual reservoir bids` have neither quantities nor prices varying per subperiod, as the decisions associated with the virtual reservoir bids are intended to drive the target reservoir storage level at the end of the period (for which it is not necessary to include per-subperiod granularity). Virtual reservoir bids can be parameterized using the following syntax: `link_time_series_to_file(db,"BiddingGroup"; virtual_reservoir_quantity_offer = "q", virtual_reservoir_price_offer = "p")`

Note that in the examples above we assume that the quantity file `"q"` and the price file `"p"` follow the correct structure specified above for each bid type. It is also worth highlighting that all three types of bid also have their time series varying per [period, scenario, and segment](key_features.md#glossary), in addition to potentially varying per subperiod.

## Complex profile bids

Although the representation introduced earlier of independent bids, profile bids, and virtual reservoir bids is quite powerful, it is insufficient for properly representing all possible types of interdependence between the decisions at multiple subperiods that would be needed to actually emulate realistic constraints of various types of physical units. In order to extend the model and truly allow for all types of interplay (synergies and anti-synergies) between possible dispatch choices at different hours, we introduce three additional features tied to the profile bids structure:

- **Precedence constraints**, modeled in the form $\lambda_A \leq \lambda_B$, and represented in the database by the `parent_profile` time series parameter
- **Complementarity constraints**, modeled in the form $\lambda_A + \lambda_B \leq 1$, and represented in the database by the `complementary_grouping_profile` time series parameter (with any number of segments being potentially included in a complementarity grouping for the purpose of defining these constraints)
- **Minimum activation constraints**, modeled with the introduction of an additional binary variable and by imposing that $\lambda_A > 0 \Rightarrow \lambda_A \geq L_A$, and represented in the database by the `minimum_activation_level_profile` time series parameter (with any number of segments being potentially included in a complementarity grouping for the purpose of defining these constraints)

These three types of constraints associated with the profile bids are analogous to the "block bid" functionalities extensively used in Europe, and they represent a technology-neutral way to express any possible technological feature leading to interdependence relations between the operational choices at different hours. It is possible to demonstrate that, with only the three types of constraints above and assuming that the number of profiles and constraints that can be used is sufficiently large, it is possible to represent virtually any possible shape of interdependencies.

## Practical examples

The tutorials below highlight the construction and execution of studies using different types of bids:

- [A simple introduction to profile bids](tutorial/case_03_build_profile_base_case.md)
- [A case with minimum activation and integer variables](tutorial/case_04_build_multi_min_activation.md)
- [A case with reservoir hydro bids](tutorial/case_05_build_reservoir_case.md)
