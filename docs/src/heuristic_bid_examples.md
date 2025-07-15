# Heuristic Bid Examples

This section is a follow-up of the [Introduction: Bid structures and bid data](bidding_formats.md) chapter, where we introduced different bid formats.

The heuristic bid generation differs based on the type of assets that an agent's bidding group contains.
Here, we will present examples of how the heuristic bid is generated for different types of bidding groups.
For the mathematical formulation of the heuristic bid, please refer to the [Heuristic Bid](heuristic_bids.md) chapter.

## Only thermal units

When considering a bidding group with only thermal units, the heuristic bid is evaluated based on the operational cost and maximum generation of the assets that compose it.

The resulting bid will divided into segments, where the price for each segment corresponds to the operational cost of a thermal unit in the bidding group, always orderd from the cheapest to the most expensive, and the quantity for each segment corresponds to the maximum generation of the thermal unit in the bidding group.

For instance, consider that we have two thermal units witht the following characteristics:

| Thermal Unit | Max Generation (MW) | Operational Cost ($/MWh) |
|:------------:|:-------------------:|:------------------------:|
|     T1       |         50          |           30.0           |
|     T2       |         100         |           40.0           |

The heuristic bid will have the following structure:

#### Price bid

| period | scenario | subperiod | bid_segment | bg_1 - bus_1 |
|:------:|:--------:|:---------:|:-----------:|:------------:|
|   1    |    1     |     1     |      1      |    30.0     |
|   1    |    1     |     1     |      2      |    40.0     |


#### Quantity bid

| period | scenario | subperiod | bid_segment | bg_1 - bus_1 |
|:------:|:--------:|:---------:|:-----------:|:------------:|
|   1    |    1     |     1     |      1      |     50      |
|   1    |    1     |     1     |      2      |     100      |


## Using markup factors

When using markup factors, the price bid is calculated by increasing the operational cost of the thermal unit by the markup factor (_cost * (1 + markup factor)_). 
The markup factor is a global parameter for all assets in a bidding group.
It can be used to make more complex bidding strategies, by dividing the bids originated from a single asset into multiple segments, each with a different markup factor.
Also, each segment is assigned a different portion of the generation, which is used to calculate the quantity bid.

Using the same example as before, consider that we have the following markup factors:

| bid_segment | Portion of the generation (%) | Markup factor (%) |
|:-----------:|:-----------------:| :-----------------:|
|      1      |        40.0       |    20.0          |
|      2      |        60.0       |   30.0          |


Then, for example, T1 will be biding 40% of its generation in the first segment for a price of 36.0 \$/MWh and 60%  of its generation in the second segment for a price of 39.0 \$/MWh.


The heuristic bid will have the following structure:


#### Price bid

| period | scenario | subperiod | bid_segment | bg_1 - bus_1 |
|:------:|:--------:|:---------:|:-----------:|:------------:|
|   1    |    1     |     1     |      1      |    36.0 (T1) |
|   1    |    1     |     1     |      2      |    39.0 (T1) |
|   1    |    1     |     1     |      3      |    48.0 (T2) |
|   1    |    1     |     1     |      4      |    52.0 (T2) |


#### Quantity bid

| period | scenario | subperiod | bid_segment | bg_1 - bus_1 |
|:------:|:--------:|:---------:|:-----------:|:------------:|
|   1    |    1     |     1     |      1      |    20.0 (T1) |
|   1    |    1     |     1     |      2      |    30.0 (T1) |
|   1    |    1     |     1     |      3      |    40.0 (T2) |
|   1    |    1     |     1     |      4      |    60.0 (T2) |


!!! note "Code snippet"
    In order to create a bidding group with markup bids, you can use the following code example:
    ```julia
    IARA.add_bidding_group!(
        db;
        label = "Thermal Owner",
        assetowner_id = "Thermal Owner",
        risk_factor = [0.2, 0.3],
        segment_fraction = [0.4, 0.6],
    )
    ```


## Only renewable units

When considering a bidding group with only renewable units, the heuristic bid is evaluated based on the maximum generation, operational cost and the expected generation of the assets that compose it.

The expected generation, which is given in p.u., is a forecast of the generation that the renewable unit will produce in the next period.
For our example, we will be working with a time horizon of 1 period, 2 scenarios and 2 subperiods.
Consider the following forecast of expected generation for the renewable units `Renewable1` and `Renewable2`:


| period | scenario | subperiod |  R1  | R2   |
|:------:|:--------:|:---------:|:------------:|:------------:|
|   1    |    1     |     1     |     0.5      |     0.7      |
|   1    |    1     |     2     |     0.4      |     0.6      |
|   1    |    2     |     1     |     0.6      |     0.8      |
|   1    |    2     |     2     |     0.3      |     0.5      |

Also, consider the following characteristics of the renewable units:

| Renewable Unit | Max Generation (MW) | Operational Cost ($/MWh) |
|:-------------:|:-------------------:|:------------------------:|
|     R1        |         100          |           30.0           |
|     R2        |         100          |           40.0           |


As seen in the previous example for thermal units, the heuristic bid for this case will also be divided into segments, where the price for each segment corresponds to the operational cost of a renewable unit in the bidding group and the quantity for each segment corresponds to the expected generation of the renewable unit (in p.u.) multiplied by the maximum generation of the renewable unit.


#### Price bid


| period | scenario | subperiod | bid_segment | bg_1 - bus_1 |
|:------:|:--------:|:---------:|:-----------:|:------------:|
|   1    |    1     |     1     |      1      |     30      |
|   1    |    1     |     1     |      2      |     40      |
|   1    |    1     |     2     |      1      |     30      |
|   1    |    1     |     2     |      2      |     40      |
|   1    |    2     |     1     |      1      |     30      |
|   1    |    2     |     1     |      2      |     40      |
|   1    |    2     |     2     |      1      |     30      |
|   1    |    2     |     2     |      2      |     40      |


#### Quantity bid

| period | scenario | subperiod | bid_segment | bg_1 - bus_1 |
|:------:|:--------:|:---------:|:-----------:|:------------:|
|   1    |    1     |     1     |      1      |    50.0     |
|   1    |    1     |     1     |      2      |    70.0     |
|   1    |    1     |     2     |      1      |    40.0     |
|   1    |    1     |     2     |      2      |    60.0     |
|   1    |    2     |     1     |      1      |    60.0     |
|   1    |    2     |     1     |      2      |    80.0     |
|   1    |    2     |     2     |      1      |    30.0     |
|   1    |    2     |     2     |      2      |    50.0     |

