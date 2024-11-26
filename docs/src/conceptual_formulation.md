# Conceptual Formulation

There are [four possible representations](key_features.md#optimization-problem-structure) for how the individual units can be represented within each optimization problem:

- The cost-based paradigm
- The bid-based paradigm
- The hybrid paradigm
- The virtual reservoir hybrid paradigm

This page describes conceptually each of these paradigms, by first introducing the notation and then gradually building up intuition:

- First, we present a simple contrast between the cost-based paradigm representation and the bid-based paradigm representation, in a simplified version of the optimization problem
- Then, we introduce a more general version, in which each bidding group in the system can be classified between bid-based, cost-based, or hybrid in terms of its representation
- Then, we introduce additional complexities and show that most intuitions from the previous representation remain valid
- Finally, we introduce the virtual reservoir representation.

Note that the formulations presented in this page abstract away the specific features of the [cost-based representation of units](centralized_operation_problem.md), which involve (for example) reservoir management decision variables for hydro power plants and startup decision variables for thermal power plants; as well as the specific features of the [bid-based representation of bidding groups](centralized_operation_problem.md), which are characterized by independent bids, profile bids, complementarity sets, minimum activation constraints, and precedence constraints. More detailed information is available in the linked pages.

## Base notation

The following notation will be used throughout the problems introduced in this page:

- **Indices and associated sets:**
     - Physical units $i \in \mathcal{I}$
     - Bidding groups $j \in \mathcal{J}$
     - Decision-making agents $a \in \mathcal{A}$
     - Virtual reservoirs $r \in \mathcal{R}$
     - Network buses $n \in \mathcal{N}$
     - Subperiods $t \in \mathcal{T}$
- **Primal decision variables and associated feasibility sets:**
     - General system operator's flexible choices $x \in \mathcal{X}$
     - Physical unit's operating decisions ${y}_{i} \in \mathcal{Y}_{i}$
     - Bidding Group's activation decisions ${q}_{j} \in \mathcal{Q}_{j}$
     - Virtual reservoir account's activation decisions ${w}_{ra} \in \mathcal{W}_{ra}$
- **Other input data:**
     - Unit production function ${Q}_{i}({y}_{i})$
     - Unit cost function ${C}^{Y}_{i}({y}_{i})$
     - Bidding group cost function ${C}^{Q}_{j}({q}_{j})$
     - Virtual reservoir cost function ${C}^{W}_{ra}({w}_{ra})$
     - A small weighing parameter $\epsilon$
     - Virtual reservoir aggregation function $W$
- **Dual variables:**
  - Demand marginal price $\pi$
  - Virtual reservoir marginal price $\mu$


Note that the information that is submitted by a bidding agent to the system operator (in a bid-based or in a hybrid representation) constitutes of a feasibility set $\mathcal{Q}$ and a cost function ${C}^{Q}$, in each case for each of the bidding groups that are under the control of agent $a$. In a virtual reservoir hydrid representation, information is submitted per "virtual reservoir account", which is characterized by both a virtual reservoir $r$ and a bidding agent $a$.

## A simple contrast

### The cost-based representation

For an initial exercise, we will write two problem formulations, one cost-based and one bid-based, and highlight the contrasts between the two. In addition to assuming fully coherent representations (i.e. all units are represented as bid-based or all units are represented as cost-based), for the moment we will also consider that there is only one bus and only one subperiod represented, thus omitting the indices $n$ and $t$.

First we introduce the standard formulation for the cost-based problem. Note that the decision variables are $y_i$ for each unit $i \in \mathcal{I}$, and that the production function $Q_i$ is used to represent both produced quantities (if $Q_i>0$) and consumed quantities (if $Q_i<0$). Therefore, the last constraint represented in the optimization problem below represents the supply-demand balance, and the associated dual variable $\pi$ represents the marginal cost of demand.

$$ \min_y  \sum_{i \in \mathcal{I}} {C}^{Y}_{i}(y_i) $$
$$ s.t. \quad y_i \in \mathcal{Y}_i \quad \forall i \in \mathcal{I} $$
$$ \sum_{i \in \mathcal{I}} {Q}_{i}(y_i) = 0 \quad : \space \pi $$

### The bid-based representation

The structure of the bid-based problem, as shown below, is similar to the previous version at first glance. Now the decision variables are $q_j$ for each bidding group $j \in \mathcal{J}$, and the production function is no longer necessary as the balance equation uses quantities $q_j$ directly (although the convention $q_j>0$ for generation and $q_j<0$ for consumption persists). Fundamentally, there are two key distinctions from the previous formulation: the first one is that the agent is now responsible for actively informing $\mathcal{Q}_j$ and ${C}^{Q}_{j}$ rather than assuming a more passive role. The second distinction is that some information could become unavailable to the system operator: not only because $y$ may incorporate richer information than $q$, but also because multiple units $i$ might be grouped into a single bidding group $j$.

$$ \min_q  \sum_{j \in \mathcal{J}} {C}^{Q}_{j}(q_i) $$
$$ s.t. \quad q_j \in \mathcal{Q}_j \quad \forall j \in \mathcal{J} $$
$$ \sum_{j \in \mathcal{J}} q_j = 0 \quad : \space \pi $$

Even with these differences, as long as agents do not have market power and there are no exernalities involved (i.e. the operating decisions from different units only interact to the extent that they influence the balance equation), one can expect that the incentive represented by the price signal $\pi$ will encourage the decentralized agents to find the same equilibrium solution as the direct cost-based minimization problem. This is a classic result from the economic literature, although more refined assessments require exploring results without the assumption of no market power.

### The hybrid representation

Finally, we can introduce the hybrid representation, as shown below. The defining feature of the hybrid representation is that both sets of decision variables, $y$ and $q$, are present - and as a consequence, there is an additional constraint ensuring the compatibility between the produced quantities as indicated by the two sets of variables. For this additional constraint, we introduce the notation $\mathcal{I}^J(j)$ to represent the units that belong to the bidding group $j$.

$$ \min_{q,y}  \sum_{j \in \mathcal{J}} {C}^{Q}_{j}(q_i) + \epsilon \cdot \sum_{i \in \mathcal{I}} {C}^{Y}_{i}(y_i) $$
$$ s.t. \quad q_j \in \mathcal{Q}_j \quad \forall j \in \mathcal{J} $$
$$ \quad y_i \in \mathcal{Y}_i \quad \forall i \in \mathcal{I} $$
$$ \sum_{j \in \mathcal{J}} q_j = 0 \quad : \space \pi $$
$$ \sum_{i \in \mathcal{I}^J(j)} Q_i(y_i) = q_j \quad \forall j \in \mathcal{J} $$

It's also worth noting the role of the parameter $\epsilon$ in the formulation above: because $\epsilon$ is small, it indicates that the bid-based cost function representation ${C}^{Q}_{j}$ is the chief driver of the objective function, with ${C}^{Y}_{i}$ playing the role of a "tiebreaker" between units that are not distinguished otherwise.

## A mixed representation

In practice, it is possible for multiple representations (cost-based, bid-based, and hybrid) to coexist in the same optimization problem. In order to represent this properly, we introduce the following notation:

- A partition of the set of all bidding groups can be written as $\mathcal{J} =\mathcal{J}^C \cup \mathcal{J}^B \cup \mathcal{J}^H$: that is, all bidding groups are represented as either cost-based, bid-based, or hybrid.
- We also define the shorthands $\mathcal{I}^C = \bigcup_{j \in \mathcal{J}^C} \mathcal{I}^J(j)$ and $\mathcal{I}^H = \bigcup_{j \in \mathcal{J}^H} \mathcal{I}^J(j)$: in practice, the sets of all units with a cost-based or hybrid representation are fully determined by $\mathcal{J}^C$ or $\mathcal{J}^H$ respectively.

With this, we reach the following version of the optimization problem:

$$ \min_{q,y}  \sum_{j \in \mathcal{J}^B \cup \mathcal{J}^H} {C}^{Q}_{j}(q_i) + \sum_{i \in \mathcal{I}^C} {C}^{Y}_{i}(y_i) + \epsilon \cdot \sum_{i \in \mathcal{I}^H} {C}^{Y}_{i}(y_i) $$
$$ s.t. \quad q_j \in \mathcal{Q}_j \quad \forall j \in \mathcal{J}^B \cup \mathcal{J}^H $$
$$ \quad y_i \in \mathcal{Y}_i \quad \forall i \in \mathcal{I}^C \cup \mathcal{I}^H $$
$$ \sum_{j \in \mathcal{J}^B \cup \mathcal{J}^H} q_j + \sum_{i \in \mathcal{I}^C} Q_i(y_i)= 0 \quad : \space \pi $$
$$ \sum_{i \in \mathcal{I}^J(j)} Q_i(y_i) = q_j \quad \forall j \in \mathcal{J}^H $$

## The virtual reservoir representation

The virtual reservoir representation is a "specialized" version of the hybrid representation, which was designed with [features of hydro cascades](hydro_challenges.md) in mind. When dealing with virtual reservoirs, all units that are associated with virtual reservoirs are automatically removed from their corresponding bidding groups - and therefore the partition of the set of bidding groups remains unchanged, $\mathcal{J} =\mathcal{J}^C \cup \mathcal{J}^B \cup \mathcal{J}^H$. It is, however, necessary to introduce $\mathcal{I}^W$ the set of units that are tied to a virtual reservoir (and note that $\mathcal{I}^W \cap \mathcal{I}^J(j) = \emptyset \space \forall j \in \mathcal{J}$).

The representation of the optimization problem shown below introduces a single virtual reservoir (thus ommitting the index $r \in \mathcal{R}$) into the flexible problem representation introduced previously. In addition to introducing a new decision variable $w$ associated with the virtual reservoir decisions (note that each agent $a \in \mathcal{A}$ can potentially make one such decision), we introduce a new constraint to guarantee the compatibility between the virtual reservoir decisions and the physical decisions $y_i$, governed by the aggregation function $W$. This equality constraint is analogous to the constraint used for hybrid representations in general, but because it plays a role in the financial settlements associated with the virtual reservoir mechanism it is highlighted here (with its dual variable $\mu$).

$$ \min_{q,y,w}  \sum_{j \in \mathcal{J}^B \cup \mathcal{J}^H} {C}^{Q}_{j}(q_i) + \sum_{i \in \mathcal{I}^C} {C}^{Y}_{i}(y_i) + \sum_{a \in \mathcal{A}} {C}^{W}_{a}(w_a) + \epsilon \cdot \sum_{i \in \mathcal{I}^H \cup \mathcal{I}^W} {C}^{Y}_{i}(y_i) $$
$$ s.t. \quad q_j \in \mathcal{Q}_j \quad \forall j \in \mathcal{J}^B \cup \mathcal{J}^H $$
$$ \quad y_i \in \mathcal{Y}_i \quad \forall i \in \mathcal{I}^C \cup \mathcal{I}^H \cup \mathcal{I}^W$$
$$ \quad w_a \in \mathcal{W}_a \quad \forall a \in \mathcal{A}$$
$$ \sum_{j \in \mathcal{J}^B \cup \mathcal{J}^H} q_j + \sum_{i \in \mathcal{I}^C \cup \mathcal{I}^W} Q_i(y_i)= 0 \quad : \space \pi $$
$$ \sum_{i \in \mathcal{I}^J(j)} Q_i(y_i) = q_j \quad \forall j \in \mathcal{J}^H $$

$$ W( \{y_i \}_{i \in \mathcal{I}} ) = \sum_a w_a \quad : \space \mu $$

