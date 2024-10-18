# Clearing Formulation

The Market Clearing is subdivided into four steps: Ex-Ante Physical, Ex-Ante Commercial, Ex-post Physical, and Ex-post Commercial.

## Ex-Ante

The Ex-Ante step is responsible for calculating the physical and commercial dispatches one day before the actual operation. The Ex-Ante step is divided into two steps: Ex-Ante Physical and Ex-Ante Commercial. 
In the Virtual Reservoir, the allocation of predicted inflows for this agent is added to its balance.

## Ex-Ante Physical

The Ex-Ante Physical step is responsible for calculating the physical generation amount that will be dispatched a day before the actual operation. The physical units are calculated based on the bids submitted by the agents and the constraints of the system. In the Virtual Reservoir, the allocation of predicted inflows for this agent is added to its balance.
In this problem, the Market Clearing is calculated with all integer variables, and the result will generally be used in other subsequent problems.

## Ex-Ante Commercial

The Ex-Ante Commercial step is responsible for calculating the clearing prices of the day-ahead market.

To calculate the prices there are three options:

1. MIP that fixes variables and then runs with them fixed.
2. LP that receives variables to be fixed from a previous problem: it can only receive the binary variables from the ex-ante physical problem.
3. LP that runs relaxed.

## Ex-Post

In ex-post problems, a set of sub-scenarios is created for each scenario verified in the ex-ante, representing shocks that simulate real-time variations.

The first sub-scenario calculated in the ex-post is used to transmit the state variable information and the virtual reservoir balance to the next stage.

At a given stage, the Virtual Reservoir balance is added to the ex-post inflow allocation for this agent in its balance, and the offers accepted by the Operator are debited. After this operation, an adjustment can be made so that the Virtual Reservoir balance equals the Available Energy of the hydros that make up this reservoir.

## Ex-Post Physical

The Ex-Post Physical step is responsible for calculating the physical generation amount that will be dispatched in real-time. The physical units are calculated based on the bids submitted by the agents and the constraints of the system. In the Virtual Reservoir, the allocation of inflows for this agent is added to its balance.

The binary variable can be treated as follows:

1. MIP that fixes variables and then runs with them fixed.
2. LP that receives variables to be fixed from a previous problem: the binary variables from the ex-ante physical or commercial problem.
3. LP that runs relaxed.

## Ex-Post Commercial

The Ex-Post Commercial step is responsible for calculating the clearing prices of the real-time market.

To calculate the prices there are three options:

1. MIP that fixes variables and then runs with them fixed.
2. LP that receives variables to be fixed from a previous problem: it can receive the binary variables from the ex-ante or ex-post physical problems.
3. LP that runs relaxed.

In all procedures, it's possible to add the FCF from the MinCost module and a wave-guide curve as a tie-break for the Virtual Reservoir bids.

## Model Clearing model types

The Market Clearing can be calculated in three ways:

1. Cost Based Dispatch: The dispatch is calculated based only on the physical attributes of the system. The objective is to minimize the total cost of the system. No bids are considered in this case.
2. Bid Based Dispatch: The dispatch is calculated based only on the bids submitted by the agents. The objective is to minimize the total cost of the bids accepted by the Operator. The physical constraints are not considered in this case.
3. Hybrid Dispatch: The dispatch is calculated based on the bids submitted by the agents and the physical constraints of the system serve as a limit for the accepted bids and a tie-break for the bids with the same cost. The objective is to minimize the total cost of the bids accepted by the Operator.

Any step of the Market Clearing can be calculated with any of the three model types described above.
