# Clearing Formulation

One of the [key features](key_features.md) of IARA is the organization of the Market Clearing process into four subproblems: Ex-Ante Physical, Ex-Ante Commercial, Ex-post Physical, and Ex-post Commercial.

The typical structure according to which these four subproblems are structured is illustrated in the image below. Note that each iteration of the market clearing process involves solving all four subproblems (one instance of each of the ex ante subproblems and several instances of each of the ex post subproblems, one for each subscenario). The ending state of the previous period's optimization problem ($T-1$) is an input for all four subproblems, and the present period ($T$)'s ending state is also passed on to the next iteration of the market clearing process. Note that it is the final state of one of the instances of the ex post physical optimization problem that will typically be the driver of this ending state.

Other arrows in the diagram below represent other input data (physical random variables and submitted bids) that are collected as part of [IARA's main market clearing process](key_features.md#the-market-clearing-process), as well as output variables (assigned quantities and marginal costs). Converting the assigned quantities and marginal costs into a price signal is part of IARA's post-processing feature.

![Diagram](./assets/Picture_Subproblems.png)

Even though the above diagram is the "default" structure for the market clearing process, which is quite flexible and able to accommodate a number of market designs, some market design choices might either omit some of these steps or introduce relationships between the subproblems. You can [get started](first_execution.md) by exploring IARA's features for representing market design options that will affect the clearing process.

