# Key features of IARA

IARA is a sophisticated piece of software intended to model realistic electricity markets. IARA's core usage is the "market clearing" execution mode, which will calculate dispatch decisions and marginal prices associated with the particular market design choices initialized (conceptualized as the regulator's decisionmaking) and, when applicable, also affected by the bidding strategies of individual agents operating in the market.

## Optimization problem structure

Electricity system dispatch and price formation typically relies on building and solving optimization problems. In order to accomodate different electricity market designs, IARA contemplates multiple "types" of representation of the underlying physical reality, as discussed in a [dedicated page](conceptual_formulation.md). In particular, there are four key ways to represent physical units in the system:

- In a **cost-based representation**, physical units are modeled directly as parameterized. The underlying assumption is that the system operator has all of this relevant information and no further input from the asset owner is needed.
- In a **bid-based representation**, physical units are represented abstractly by a set of bid segments submitted by the asset owners. The only decision variable available to the operator is how much of each bid segment to activate.
- In a **hybrid representation**, each physical unit is represented by two sets of variables, one representing bid segment activations and another representing physical decision variables.
- The **virtual reservoir hybrid representation** is a modified version of the hybrid representation which was designed specifically to tackle the [challenges of hydro cascades](hydro_challenges.md).

## The market clearing process

Each time IARA is run, it will create a number of scenarios $S$ (parallel trajectories to simulate), each of which will involve modeling a number of sequential periods $T$ (with the possibility of using the results of the previous period within each scenario to affect the curent period). The "market clearing process" run for each $S$ and each $T$ is described in detail in a separate [dedicated page](clearing_procedure.md), but it can be summarized as follows:

- Market clearing begins by the **collection of ex ante physical data**. This is intended to represent the best information available when the system operator is making key decisions (i.e. the "ex ante process") which cannot easily be changed in real time.

- The second step is the **bidding phase**, in which market agents submit their bids to the system operator. Note that bids are only submitted ex ante, and that the process of bidding can be automated by a heuristic bid process.

- The third step is **solving the ex ante subproblem**, which is built according to the optimization problem structure defined earlier and parameterized according to the data and/or bids collected in the previous steps.

- The following step is the **collection of ex post physical data**. Ex post physical data usually represents possible realizations of relevant random variables, and they vary per "subscenario" $s$ - but otherwise have a similar structure to ex ante data.

- The next step is **solving the ex post subproblems**, which once again involves building the optimization problems (one per subscenario) and solving it using information from bids and ex post physical data.

- Finally, the **post-processing** step involves a final calculation of revenue flows for each asset owner based on the ex ante and ex post subproblems and the structure of the market design.

## IARA's physical system data

In order to execute the clearing process detailed above, IARA must contain relevant information about the [physical units](build_a_case_from_scratch.md#building-the-unit-structure) in the system. The IARA database can be thought of as composed by the following components:

- The **temporal structure** is used to describe underlying features such as the number of "subperiods" modeled in each "period", as well as the seasonal and/or cyclic nature of the "periods" represented in the simulation.

- The **spatial structure** describes locations (or "buses") available for the physical units to be connected to, in addition to a physical description of available links connecting these buses (which are assumed to be under the control of the system operator).

- The **ownership structure** describes the asset owners that control each of the physical units, as well as the "bidding groups" according to which different units are grouped together for the purpose of submitting bids. Note that, in a bid-based representation, the system operator will be unable to distinguish between the output of different units in the same bidding group.

- The **unit structure** describes the actual physical parameters of each of the available units, which can be represented directly (in a cost-based scheme) or replaced by bids (in a bid-based scheme). This is the most complex structure, with individual parameterizations for each type of physical unit - which includes thermal plants, renewable plants, hydro plants, and demand units. Note that conceptually there is no obstacle to representing demand-side bids in the same structure as other bidding units.

- The **external data structure** represents additional supporting data tying into the structures above and which is usually read in the data collection stages of the market clearing process. Most prominently, we have **physical time series data** which link to the unit structure and the temporal structure and **bid time series data** which link to the ownership structure, the spatial structure, and the temporal structure.

## Glossary

IARA uses some special terminology to describe the components of the [clearing process](clearing_procedure.md) and of the [time series files](build_a_case_from_scratch.md#building-external-data-structures) which might be unfamiliar for some users initially. Key points of this nomenclature are summarized below, and are used consistently througout these guides:

- **Related to the clearing process**:
     - **Ex ante**: The default interpretation of the ex ante process should be a "day-ahead" market, in which agents submit their bids under partial information (with additional information arriving ex post). More generally, this ex ante process can represent other moments in time, such as an intraday auction. 
     - **Ex post**: In the nomenclature of many electricity market designs, if the ex ante process is likened to a day-ahead market, the ex post process corresponds to the "real-time market" for valuing deviations between day-ahead and real-time.
     - **Commercial**: In some market designs, there is a distinction between the system representation that is used for determining the marginal price and the physical reality of the system. The "commercial" representation refers to the subproblem structure that ought to be utilized for the purpose of electricity price formation.
     - **Physical**: In case a separate "commercial" representation is used for determining the system marginal price, it is still important to have a representation that better follows the physical reality. The "physical" representation has this purpose, and is used for actual physical production decisions (considering that the system operator would be forced to redispatch units accordingly).
- **Related to the clearing process's subproblems**:
     - **Subproblem type**: Along the clearing process, there are in practice four types of subproblem that are built and solved: the ex ante physical subproblem, the ex ante commercial subproblem, the ex post physical subproblem, and the ex post commercial subproblem. In the context of describing market design choices that might be different for each of these, we will sometimes refer to the four "subproblems" (rather than "subproblem types") of the clearing process.
     - **Subproblem instances**: One "instance" of the subproblem represents a particular choice of parameters (depending on the ex ante and/or ex post physical data in addition to bid data) that leads to an optimization problem to be solved. Each of the ex ante subproblem types will yield one instance per period $P$ and scenario $S$, whereas each of the ex post subproblem types will yield additional instances per subscenario $s$.
     - **Subproblem structure**: The "structure" refers to the exact characterization of the subproblem type for a particular case execution, which involves defining whether physical units will be represented as cost-based, bid-based, hybrid, or virtual reservoir hybrid according to the standard IARA [formulation](conceptual_formulation.md). Note that while the subproblem structure can be complex, it is fully defined by the IARA case options and the subproblem type (with all instances of a given subproblem type having the same structure).
- **Related to time series dimensions**:
     - **Period**: Each "period" refers to one round of the market clearing process (including a set of optimization problems) that is solved *sequentially*. Note that the duration of each period is a parameter of the database, and therefore while the standard use case would be to represent one "period" as one day, it is possible to have each period representing one week or one month, for example. 
     - **Subperiod**: Periods are broken down into "subperiods", and the optimization problems involving the various units will in practice have constraints associated with the electricity supply-demand balance for each subperiod. As a consequence, physical unit data usually will have a subperiod dimension as well.
     - **Scenario**: Each "scenario" refers to one round of the market clearing process (including a set of optimization problems) that is solved *independently*. Because *periods* of each *scenario* are linked, scenarios can be understood as parallel trajectories simulated.
     - **Subscenario**: A "subscenario" represents an individual realization of ex post uncertainty. Note that, within each round of the market clearing process, each of the *ex post subproblems* will be evaluated once per subscenario (but not the *ex ante subproblems*), and in this sense scenarios can be thought of as being broken down into "subscenarios". 
     - **Cycle**: A "cycle" is used to represent the fact that periods tend to repeat cyclically (i.e. they start to display the same probability distributions of possible occurrences), usually after one year. It is generally desirable for the simulation to be run for a number of periods greater than the duration of the cycle.
     - **Season**: The cycle is broken down into "seasons" in order to describe the cyclical nature of the problem (with more or less granularity). IARA allows, for example, the representation of 12 "seasons" per cycle (typical months) or 52 "seasons" per cycle (typical weeks).
