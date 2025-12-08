# Supply Function Equilibrium

## Introduction

Supply Function Equilibrium (SFE) is a methodology for computing strategic bidding curves in electricity markets. In IARA.jl, SFE is enabled by setting `bid_processing = ITERATED_BIDS_FROM_SUPPLY_FUNCTION_EQUILIBRIUM`.

### Theoretical Foundation

SFE theory (Klemperer & Meyer, 1989) models competition where firms submit complete supply schedules rather than single price-quantity pairs. Each market participant recognizes that their bid curve influences market prices, and strategic agents adjust curves to maximize payoff. At equilibrium, no agent can improve by unilaterally changing their supply function.

### Input Data Sources

**Virtual Reservoirs:** Reference curves are based on marginal water values from the hydro reference curve algorithm (see [Heuristic bids for virtual reservoirs](heuristic_bids_vr.md)). These curves represent the opportunity cost of water use across different operating conditions.

**Bidding Groups:** Reference curves come from unit generation offers for thermal, renewable, and battery assets.

## Configuration

### Required Parameter

```julia
IARA.update_configuration!(db;
    bid_processing = IARA.Configurations_BidProcessing.ITERATED_BIDS_FROM_SUPPLY_FUNCTION_EQUILIBRIUM,
)
```

### SFE Parameters

- **`supply_function_equilibrium_extra_bid_quantity`** (Float64, default: 1.0)
  Determines the quantity value for the artificial bid added during SFE preprocessing.

- **`supply_function_equilibrium_max_iterations`** (Int, default: 20)
  Maximum iterations for equilibrium computation within each period/scenario.

- **`supply_function_equilibrium_tolerance`** (Float64, default: 0.000001)
  Minimum slope tolerance. Curves with slopes below this value trigger errors.

- **`supply_function_equilibrium_max_cost_multiplier`** (Float64, default: 2.0)
  Maximum price cap as multiplier of deficit cost.

**Example:**
```julia
IARA.update_configuration!(db;
    bid_processing = IARA.Configurations_BidProcessing.ITERATED_BIDS_FROM_SUPPLY_FUNCTION_EQUILIBRIUM,
    reference_curve_number_of_segments = 10,
    supply_function_equilibrium_extra_bid_quantity = 1.0,
    supply_function_equilibrium_max_iterations = 20,
    supply_function_equilibrium_tolerance = 0.000001,
    supply_function_equilibrium_max_cost_multiplier = 2.0,
    demand_deficit_cost = 3000.0,
)
```

## Mathematical Formulation

### Execution Flow

```
STEP 1: Prepare Reference Curves
    - Virtual Reservoirs: Generate from marginal water values
    - Bidding Groups: Use unit generation offers
    - Allocate to asset owners and serialize

STEP 2: Apply Supply Function Equilibrium
    FOR each period and scenario:
        - Read reference curves and initial bids
        - Apply slope adjustment formula iteratively
        - Compute equilibrium bid curves
        - Write to outputs

STEP 3: Market Clearing
    - Use equilibrium bids for clearing
    - Generate spot prices and settlement
```

### SFE Algorithm

#### Notation

**Sets:**
- ``\mathcal{A}``: Set of agents (VR-AssetOwner pairs + BG-Bus pairs)
- ``K_i``: Set of segments for agent ``i``
- ``B(t)``: Set of subperiods in period ``t``

**Indices:**
- ``i \in \mathcal{A}``: Agent index
- ``k \in K_i``: Segment index for agent ``i``
- ``\tau \in B(t)``: Subperiod index

**Parameters:**
- ``C^{max}``: Maximum cost multiplier
- ``C^\delta``: Demand deficit cost (``\$/MWh``)
- ``Q_{i,\tau}``: Quantity for agent ``i`` at subperiod ``\tau``
- ``P_{i,\tau}``: Price for agent ``i`` at subperiod ``\tau``

**Variables:**
- ``q_i(k)``: Cumulative quantity for agent ``i`` at segment ``k``
- ``p_i(k)``: Price for agent ``i`` at segment ``k``
- ``b_i(k)``: Slope ``\frac{dp}{dq}`` for agent ``i`` at segment ``k``
- ``q_i^0(k), p_i^0(k), b_i^0(k)``: Original reference curve data
- ``q_i^*(k), p_i^*(k), b_i^*(k)``: Equilibrium curve data
- ``p^*(k)``: Market price at segment ``k`` (common to all agents)

#### Data Preprocessing

1. **Bidding Groups**: Aggregate bids across subperiods before equilibrium
   ```math
   Q_{i,agg} = \sum_{\tau \in B(t)} Q_{i,\tau}
   ```
   ```math
   P_{i,agg} = \frac{\sum_{\tau \in B(t)} P_{i,\tau} \cdot Q_{i,\tau}}{Q_{i,agg}}
   ```

2. **All Agents**: Convert segment quantities to cumulative points

3. **All Agents**: Reverse to descending price order and add high-price point at deficit cost

4. **All Agents**: Calculate slopes: ``b_i(k) = \frac{p_i(k+1) - p_i(k)}{q_i(k+1) - q_i(k)}`` for all ``i \in \mathcal{A}``

#### Iteration Algorithm

**Initialization** (segment ``k=1``):

```math
q_i^*(1) = q_i^0(1) \quad \forall i \in \mathcal{A}
```
```math
p^*(1) = C^{max} \cdot C^\delta
```
```math
p_i^*(1) = p^*(1) \quad \forall i \in \mathcal{A}
```
```math
b_i^*(1) = b_i^0(1) \quad \forall i \in \mathcal{A}
```

**Iteration** for segments ``k = 1, 2, \ldots`` until all agents reach minimum quantity:

1. Get available quantities: ``\bar{q}_i(k) = \max(q_i^*(k) - q_i^0(k^+), 0)`` where ``k^+`` is the next segment index for agent ``i``

2. Calculate price decrement: ``\Delta p = \min\{\bar{q}_i(k) \cdot b_i^*(k) \mid \bar{q}_i(k) > 0, i \in \mathcal{A}\}``

3. Update quantities and market price:
   ```math
   q_i^*(k+1) = q_i^*(k) - \frac{\Delta p}{b_i^*(k)} \quad \forall i \in \mathcal{A}
   ```
   ```math
   p^*(k+1) = p^*(k) - \Delta p
   ```
   ```math
   p_i^*(k+1) = p^*(k+1) \quad \forall i \in \mathcal{A}
   ```

4. Update slopes using equilibrium formula

### Slope Update Formula

For segment ``k`` with all agents in ``\mathcal{A}``:

```math
B_k = \sum_{i \in \mathcal{A}} \frac{1}{b_i^0(k)}
```

```math
b_i^*(k) = \frac{b_i^0(k)}{2} + \frac{1}{B_k} + \sqrt{\left(\frac{b_i^0(k)}{2}\right)^2 + \left(\frac{1}{B_k}\right)^2} \quad \forall i \in \mathcal{A}
```

**Economic Interpretation:**

Each agent's optimal slope ``b_i^*(k)`` balances:
1. Cost structure: ``\frac{b_i^0(k)}{2}`` (marginal cost component)
2. Market responsiveness: ``\frac{1}{B_k}`` (aggregate inverse slope)
3. Quadratic adjustment ensuring stability

In competitive markets (large ``|\mathcal{A}|``, high ``B_k``), slopes approach marginal costs. In concentrated markets, markups are substantial.

## Virtual Reservoirs vs Bidding Groups

The SFE algorithm treats both entity types in a unified framework with key differences:

**Virtual Reservoirs:**
- Period-level aggregates (no subperiod dimension)
- Reference curves from marginal water values
- Each VR-AssetOwner pair is an agent

**Bidding Groups:**
- Have subperiod dimension (intra-period variation)
- Reference curves from unit offers
- Aggregated across subperiods before SFE
- Results disaggregated back proportionally after equilibrium
- Each BG-Bus pair is an agent

**Unified Treatment:**
All agents processed together in same iteration loop, ensuring simultaneous equilibrium regardless of technology type.

## Output Files

SFE generates equilibrium curves for each period/scenario:

**Virtual Reservoir Outputs:**
- `virtual_reservoir_sfe_quantity.csv` - Equilibrium quantities (GWh)
- `virtual_reservoir_sfe_price.csv` - Equilibrium prices (\$/MWh)
- `virtual_reservoir_sfe_slope.csv` - Equilibrium slopes (\$/MWh²)

**Bidding Group Outputs:**
- `bidding_group_sfe_quantity.csv` - Equilibrium quantities (MWh)
- `bidding_group_sfe_price.csv` - Equilibrium prices (\$/MWh)
- `bidding_group_sfe_slope.csv` - Equilibrium slopes (\$/MWh²)

All outputs include dimensions for agents, sfe\_iteration, and sfe\_curve\_segment.

## Usage Example

### Setting Up a Case with SFE

```julia
using IARA
using Dates
using DataFrames

# Create study with SFE configuration
db = IARA.create_study!("path/to/case";
    number_of_periods = 3,
    number_of_scenarios = 2,
    number_of_subperiods = 4,
    initial_date_time = "2020",
    subperiod_duration_in_hours = [250.0, 250.0, 250.0, 250.0],
    demand_deficit_cost = 500.0,
    # Enable Supply Function Equilibrium
    bid_processing = IARA.Configurations_BidProcessing.ITERATED_BIDS_FROM_SUPPLY_FUNCTION_EQUILIBRIUM,
    reference_curve_number_of_segments = 10,
)

# Add buses and zones
IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")

# Add hydro units
IARA.add_hydro_unit!(db;
    label = "hydro_1",
    initial_volume = 900.0,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 3.6,
        max_generation = 400.0,
        max_turbining = 0.4,
        min_volume = 0.0,
        max_volume = 2000.0,
        om_cost = 10.0,
    ),
)

IARA.add_hydro_unit!(db;
    label = "hydro_2",
    initial_volume = 0.0,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 3.6,
        max_generation = 700.0,
        max_turbining = 0.7,
        min_volume = 0.0,
        max_volume = 0.0,
        om_cost = 10.0,
    ),
)

IARA.set_hydro_turbine_to!(db, "hydro_1", "hydro_2")

# Add asset owners (for SFE competition)
IARA.add_asset_owner!(db;
    label = "utility_A",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)

IARA.add_asset_owner!(db;
    label = "utility_B",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)

IARA.add_asset_owner!(db;
    label = "utility_C",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)

# Create virtual reservoir with multiple owners
IARA.add_virtual_reservoir!(db;
    label = "reservoir_1",
    assetowner_id = ["utility_A", "utility_B", "utility_C"],
    inflow_allocation = [0.4, 0.3, 0.3],
    initial_energy_account_share = [0.4, 0.3, 0.3],
    hydrounit_id = ["hydro_1", "hydro_2"],
)

IARA.close_study!(db)

# Run training and market clearing
IARA.train_min_cost("path/to/case")
IARA.market_clearing("path/to/case")
```

### Modifying an Existing Case

```julia
# Load existing case
db = IARA.load_study("path/to/case"; read_only = false)

# Enable SFE
IARA.update_configuration!(db;
    bid_processing = IARA.Configurations_BidProcessing.ITERATED_BIDS_FROM_SUPPLY_FUNCTION_EQUILIBRIUM,
    reference_curve_number_of_segments = 10,
)

# Add more asset owners to existing virtual reservoir
IARA.add_asset_owner!(db;
    label = "utility_D",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)

# Update virtual reservoir to include new owner
IARA.delete_element!(db, "VirtualReservoir", "reservoir_1")
IARA.add_virtual_reservoir!(db;
    label = "reservoir_1",
    assetowner_id = ["utility_A", "utility_B", "utility_C", "utility_D"],
    inflow_allocation = [0.3, 0.3, 0.2, 0.2],
    initial_energy_account_share = [0.3, 0.3, 0.2, 0.2],
    hydrounit_id = ["hydro_1", "hydro_2"],
)

IARA.close_study!(db)

# Run market clearing with SFE
IARA.market_clearing("path/to/case")
```

## References

- Klemperer, P., & Meyer, M. (1989). "Supply Function Equilibria in Oligopoly under Uncertainty." *Econometrica*, 57(6), 1243-1277.
- Green, R. J., & Newbery, D. M. (1992). "Competition in the British Electricity Spot Market." *Journal of Political Economy*, 100(5), 929-953.
- Holmberg, P. (2008). "Unique Supply Function Equilibrium with Capacity Constraints." *Energy Economics*, 30(1), 148-172.
- Resende, M. M. *Equilíbrio de Nash em Mercados de Energia Elétrica com Formação de Preços por Ofertas*. Master's Dissertation. (Portuguese)
- Peixoto, B. *Arcabouço Iterativo para Resolução do Equilíbrio de Funções de Oferta em Mercados de Energia Elétrica*. Master's Dissertation. (Portuguese)
