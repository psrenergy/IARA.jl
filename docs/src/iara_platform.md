# IARA Platform

As discussed in this documentation, IARA.jl uses several concepts from electricity markets, which can be complex to understand.
That said, along with IARA.jl, we have developed a web platform called [IARA Platform](https://iara.psr-inc.com/) that allows users to participante in an energy market simulation, where they can play the role of an Asset Owner or System Operator.
For now, the IARA Platform is only available in Portuguese.

![IARA Platform Screenshot](assets/iara_platform.gif)

In a game, each user is assigned to an Asset Owner by the System Operator, who is responsible for executing the optimization problem after all users have submitted their bids.
A user bid is comprised of a quantity and price offer, and its values should be chosen by the user based on their knowledge of the market and their assets.

![IARA Platform Bidding](assets/bidding.gif)

## Single Period Market Clearing

In the [Key Features](key_features.md#the-market-clearing-process) section, we explained IARA.jl's Market Clearing Process, which optimizes the dispatch of assets based on the bids submitted by asset owners.
In this case, the time horizon of the problem varies by case, and can have multiple time steps, which are depicted by the `period` and `subperiod` dimensions.
Additionally, the `subperiod` duration can vary and is defined by the `subperiod_duration` parameter during the formulation of the problem.

This single period is then divided into subperiods, each representing one hour of the day.
As our goal is to introduce users to the concepts of electricity markets, a round (period) can have only one subperiod.

When executing a round, IARA.jl performs the single period market clearing process by calling the [`IARA.single_period_market_clearing`](@ref) function, which considers the bids submitted by the users for the current round and outputs specialized plots for the web platform.
The results of the market clearing process are then displayed to the users, allowing them to visualize the dispatch of assets and the prices determined by the market.

![IARA Platform Bidding](assets/running.gif)

## Features

### Price Violation

The IARA Platform includes a validation routine that checks if the price offers submitted by the users are within the allowed range for their assets.
In this documentation you can find more information about how the price limits are calculated by IARA.jl.

There are two main price thresholds that are considered in the validations routine:
1. **Non justified offer**: If the price offer is below this limit, the user is not required to justify their offer. 
However, if the price offer is above this limit, the user must provide a justification for their offer in a text box.

![IARA Platform Bidding](assets/justification.gif)


2. **Justified offer**: If the price offer is above this limit, the user cannot submit their offer, even if they provide a justification.

![IARA Platform Bidding](assets/no_justification.gif)


After the round is executed, the System Operator can review the justifications provided by the users in the results section.

![IARA Platform Bidding](assets/reading_justification.gif)
