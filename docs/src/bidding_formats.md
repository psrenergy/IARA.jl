# Introduction: Bid structures and bid data

## Types of bid and data flow

Being able to describe agents' strategies in a bid-based market is one of IARA's [key features](key_features.md). IARA has three main types of bid that can be submitted by decision-making agents:

- independent bids refer to price-quantity bids that are associated to a single subperiod, and which can be accepted or rejected in a fully independent manner
- profile bids refer to price-quantity bids that represent an interdependence between different subperiods, with a single decision potentially affecting output in multiple subperiods
- virtual reservoir bids refer to price-quantity bids tied to [virtual reservoir accounts](build_a_case_from_scratch.md#building-the-ownership-structure), designed to combat the [externality issues involved in hydro cascades](hydro_challenges.md).

For all three types of bid, there are two possible options for managing this bid data: 

- Bid data can be produced automatically, using IARA's standard "heuristic bid" functionality that is applied by default in the course of [running a market clearing problem](key_features.md#the-market-clearing-process)
- Alternatively, bid data can be read from external files, which are referenced as [external data structures](build_a_case_from_scratch.md#building-external-data-structures) of the IARA database.

Note that, in case the heuristic bid alternative is chosen, bid files will be generated with the same structure that is expected if bids were to be read as input data.

## Price and quantity parameter data files

All three types of bid in IARA involve "price" and "quantity" information that can be expressed by a [time series file](build_a_case_from_scratch.md#building-external-data-structures), and which can be linked using the function [`IARA.link_time_series_to_file`](@ref).

However, there are some differences in the way that these time series files are structured, depending on the type of bid. The following sections describe the expected structure of the time series files for each type of bid.

### Independent bids:

Independent bids have both quantities and prices varying per [subperiod](key_features.md#glossary), as decisions are indeed individualized per subperiod. Independent bids can be parameterized using the following syntax: `link_time_series_to_file(db,"BiddingGroup"; quantity_bid = "q", price_bid = "p")`, where `"q"` and `"p"` are the names of the CSV files containing the time series data for the quantity and price bids, respectively. The expected structure of these files is shown in the following tables:


#### Price bid


| period | scenario | subperiod | bid_segment | bg_1 - bus_1 | bg_1 - bus_2 | bg_2 - bus_1 | bg_2 - bus_2 |
|:------:|:--------:|:---------:|:-----------:|:------------:|:------------:|:------------:|:------------:|
|   1    |    1     |     1     |      1      |    100.0     |     80.0     |     90.0     |     70.0     |
|   1    |    1     |     2     |      1      |    100.0     |     80.0     |     90.0     |     70.0     |
|   1    |    2     |     1     |      1      |    100.0     |     80.0     |     90.0     |     70.0     |
|   1    |    2     |     2     |      1      |    100.0     |     80.0     |     90.0     |     70.0     |




#### Quantity bid


| period | scenario | subperiod | bid_segment | bg_1 - bus_1 | bg_1 - bus_2 | bg_2 - bus_1 | bg_2 - bus_2 |
|:------:|:--------:|:---------:|:-----------:|:------------:|:------------:|:------------:|:------------:|
|   1    |    1     |     1     |      1      |     5.0      |     1.0      |     5.0      |     2.0      |
|   1    |    1     |     2     |      1      |     5.0      |     1.0      |     5.0      |     2.0      |
|   1    |    2     |     1     |      1      |     4.0      |     1.5      |     4.0      |     3.0      |
|   1    |    2     |     2     |      1      |     4.0      |     1.5      |     4.0      |     3.0      |



### Profile bids:

Profile bids have quantities varying per subperiod.
However, the prices for each bid do not vary, as the decision on whether or not to activate the profile bid is made only once in the period (and therefore it is sufficient to represent the associated cost with a single price parameter). 
Profile bids can be parameterized using the following syntax: `link_time_series_to_file(db,"BiddingGroup"; quantity_bid_profile = "q", price_bid_profile = "p")`, where `"q"` and `"p"` are the names of the CSV files containing the time series data for the quantity and price profile bids, respectively.

#### Price bid


| period | scenario | profile | bg_1 | bg_2 |
|:------:|:--------:|:-------:|:----:|:----:|
|   1    |    1     |    1    | 0.0  | 45.0 |
|   1    |    1     |    2    | 0.0  | 35.0 |
|   1    |    2     |    1    | 0.0  | 45.0 |
|   1    |    2     |    2    | 0.0  | 35.0 |



#### Quantity bid



| period | scenario | subperiod | profile | bg_1 - bus_1 | bg_1 - bus_2 | bg_2 - bus_1 | bg_2 - bus_2 |
|:------:|:--------:|:---------:|:-------:|:------------:|:------------:|:------------:|:------------:|
|   1    |    1     |     1     |    1    |     0.0      |     0.0      |     4.0      |     4.0      |
|   1    |    1     |     1     |    2    |     0.0      |     0.0      |     4.0      |     4.0      |
|   1    |    1     |     2     |    1    |     0.0      |     0.0      |     4.0      |     4.0      |
|   1    |    1     |     2     |    2    |     0.0      |     0.0      |     4.0      |     4.0      |
|   1    |    2     |     1     |    1    |     0.0      |     0.0      |     4.0      |     4.0      |
|   1    |    2     |     1     |    2    |     0.0      |     0.0      |     4.0      |     4.0      |
|   1    |    2     |     2     |    1    |     0.0      |     0.0      |     4.0      |     4.0      |
|   1    |    2     |     2     |    2    |     0.0      |     0.0      |     4.0      |     4.0      |



### Virtual reservoir bids:
Virtual Reservoir bids have neither quantities nor prices varying per subperiod, as the decisions associated with the virtual reservoir bids are intended to drive the target reservoir storage level at the end of the period (for which it is not necessary to include per-subperiod granularity). Virtual reservoir bids can be parameterized using the following syntax: `link_time_series_to_file(db,"BiddingGroup"; virtual_reservoir_quantity_bid = "q", virtual_reservoir_price_bid = "p")`, where `"q"` and `"p"` are the names of the CSV files containing the time series data for the quantity and price bids, respectively. The expected structure of these files is shown in the table below:

#### Price bid


| period | scenario | bid_segment | virtual_reservoir_1 - asset_owner_1 | virtual_reservoir_1 - asset_owner_2 |
|:------:|:--------:|:-----------:|:----------------------------------:|:----------------------------------:|
|   1    |    1     |      1      |             491.198334            |             491.198334            |
|   1    |    2     |      1      |             368.398743            |             368.398743            |



#### Quantity bid


| period | scenario | bid_segment | virtual_reservoir_1 - asset_owner_1 | virtual_reservoir_1 - asset_owner_2 |
|:------:|:--------:|:-----------:|:----------------------------------:|:----------------------------------:|
|   1    |    1     |      1      |               1.5                 |               6.0                 |
|   1    |    2     |      1      |               1.5                 |               6.0                 |



## Bid segments

As seen in independent bids and virtual reservoir bids there is an entry for `bid_segment`, which allows for the bid bid to be broken down into segments. This is useful for representing a single bid divided into multiple bids, each with its own price and quantity.

!!! note "Note"
    Although each bid segment counts as a separate bid, for the same subperiod, the total quantity of its segments cannot exceed the maximum quantity of the bidding group. 

In the following table we show an example of a segmented bid for independent bids quantity bids, where the maximum generation of the bidding group is 100 MW.



| period | scenario | subperiod | bid_segment | bg_1 - bus_1 |
|:------:|:--------:|:---------:|:-----------:|:------------:|
|   1    |    1     |     1     |      1      |    50.0      |
|   1    |    1     |     1     |      2      |    50.0      |
|   1    |    1     |     2     |      1      |    50.0      |
|   1    |    1     |     2     |      2      |    50.0      |




## Profile bids

Although the representation introduced earlier of independent bids, profile bids, and virtual reservoir bids is quite powerful, it is insufficient for properly representing all possible types of interdependence between the decisions at multiple subperiods that would be needed to actually emulate realistic constraints of various types of physical units. In order to extend the model and truly allow for all types of interplay (synergies and anti-synergies) between possible dispatch choices at different hours, we introduce three additional features tied to the profile bids structure: precedence constraints, complementarity constraints, and minimum activation constraints.
All three of these features work with a coefficient $ 0 \leq \lambda \leq 1$ that indicates the fraction of the profile bid that was accepted.
We will now describe these three constraints in more detail.

### Precedence constraints

It is possible to model precedence constraints between two profile bids, which are constraints that impose that the activation of one profile bid (say, $A$) is a necessary condition for the activation of another profile bid (say, $B$). Thus if $B$ has $A$ as a _parent_, then the constraint $\lambda_B \leq \lambda_A$ must hold. This is represented in the database by the `parent_profile` time series file, which can be attached to the case using the [`IARA.link_time_series_to_file`](@ref) function. 

In the following example of a `parent_profile.csv` file, we have have bids for the Bidding Groups `bg_1` and `bg_2`, with three profiles each. 
For `bg_2`, its first profile is a _parent_ of its second profile, while for `bg_1`, its second profile is a _parent_ of its third profile. 



| period | profile |  bg_1  |  bg_2  |
|:------:|:-------:|:------:|:------:|
|   1    |    1    |  0.0   |  0.0   |
|   1    |    2    |  0.0   |  1.0   |
|   1    |    3    |  2.0   |  0.0   |
|   2    |    1    |  0.0   |  0.0   |
|   2    |    2    |  0.0   |  1.0   |
|   2    |    3    |  2.0   |  0.0   |




### Complementarity constraints

Complementarity constraints impose that the sum of the activation coefficients of a complementary group must be less than or equal to 1. 
This is represented in the database by the `complementary_grouping_profile` time series file, which can be attached to the case using the [`IARA.link_time_series_to_file`](@ref) function.


In the following example of a `complementary_grouping_profile.csv` file, we have two bidding groups, `bg_1` and `bg_2`, with 2 profiles and 3 complementary groups each.
The columns `bg_1` and `bg_2` contain boolean values that indicate whether the profile is part of the complementary group or not.

Observing the table, we can draw the following conclusions:
- The first profile of `bg_2` is part of the complementary group 1, along with its second profile.
- The first profile of  `bg_2` is also part of the complementary group 2, but no other profile is part of this group.
- The second profile of `bg_2` is part of the complementary group 3, with no other profile being part of this group.
- No profile of `bg_1` is part of any complementary group.

If a profile is not part of any complementary group, its coefficient keeps its original constraint of being between 0 and 1.
The same applies for profiles that are the only ones in a complementary group.




| period | profile | complementary_group |  bg_1  |  bg_2  |
|:------:|:-------:|:-------------------:|:------:|:------:|
|   1    |    1    |          1          |  0.0   |  1.0   |
|   1    |    1    |          2          |  0.0   |  1.0   |
|   1    |    1    |          3          |  0.0   |  0.0   |
|   1    |    2    |          1          |  0.0   |  1.0   |
|   1    |    2    |          2          |  0.0   |  0.0   |
|   1    |    2    |          3          |  0.0   |  1.0   |




### Minimum activation constraints

Minimum activation constraints establish that, for a profile bid to be accepted, the bid quantity must be at least a certain threshold, expressed as a percentage of the total bid volume.
This is represented in the database by the `minimum_activation_level_profile` time series file, which can be attached to the case using the [`IARA.link_time_series_to_file`](@ref) function.

In the following example of a `minimum_activation_level_profile.csv` file, we have two bidding groups, `bg_1` and `bg_2`, with two profiles each.
All `bg_2` profiles have a minimum activation level of 0.8, while `bg_1` has a minimum activation level of 0.0 for both profiles.



| period | scenario | profile | bg_1 | bg_2 |
|:------:|:--------:|:-------:|:----:|:----:|
|   1    |    1     |    1    | 0.0  | 0.8  |
|   1    |    1     |    2    | 0.0  | 0.8  |



These three types of constraints associated with the profile bids are analogous to the "block bid" functionalities extensively used in Europe, and they represent a technology-neutral way to express any possible technological feature leading to interdependence relations between the operational choices at different hours. It is possible to demonstrate that, with only the three types of constraints above and assuming that the number of profiles and constraints that can be used is sufficiently large, it is possible to represent virtually any possible shape of interdependencies.
Also, it is worth noting that, once a profile bid is accepted, the quantities for each subperiod are proportional to the activation coefficient $\lambda$ and the quantity bid of the profile bid. 

## Heuristic bids

As mentioned above, during the market clearing process, IARA can automatically generate bids for the decision-making agents using a heuristic approach. 

The heuristic bid generation differs based on the type of assets that an agent's bidding group contains.
In this documentation we provide [examples](heuristic_bid_examples.md) of how the heuristic bid is generated.
For the mathematical formulation of the heuristic bid, please refer to the [Heuristic Bid](heuristic_bids.md) chapter. The heuristic bid for virtual reservoirs is described in the [Virtual Reservoir Bids](heuristic_bids_vr.md) chapter.

## Practical examples

The tutorials below highlight the construction and execution of studies using different types of bids:

- [A simple introduction to profile bids](tutorial/case_03_build_profile_base_case.md)
- [A case with minimum activation and integer variables](tutorial/case_04_build_multi_min_activation.md)
- [A case with reservoir hydro bids](tutorial/case_05_build_reservoir_case.md)
