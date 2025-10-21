# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About IARA.jl

IARA (Interaction Assessment between Regulators and Agents) is a comprehensive Julia-based computational model for simulating economic dispatch and price formation in electricity markets. It provides hourly simulations of large-scale systems with detailed representation of generation, transmission, storage, and consumption, enabling assessment of price formation mechanisms based on "cost," "bid," or hybrid models.

**Project:** PSR/CCEE (Brazilian Electricity Trading Chamber) with World Bank funding
**License:** Mozilla Public License 2.0

## Development Commands

### Package Management
```bash
# Activate the IARA.jl environment
julia --project=.

# Install/update dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Testing
```bash
# Run all tests
julia --project=. test/runtests.jl

# Update test results (when expected outputs change)
julia --project=. test/runtests.jl update_test_results

# Run big (computationally expensive) tests
julia --project=. test/runtests.jl run_big_tests

# Run specific test case
julia --project=. test/case_01/base_case/test_case.jl
```

### Code Formatting
```bash
# Format code using JuliaFormatter
julia --project=. -e 'using JuliaFormatter; format(".")'
```

Configuration in `.JuliaFormatter.toml`:
- Indent: 4 spaces
- Margin: 120 characters
- Always use `return` keyword
- Trailing commas enabled
- Semicolon-separated kwargs

### Running IARA
```bash
# Typical execution with a case directory
julia --project=. -e 'using IARA; IARA.main(["path/to/case"])'

# With Docker
docker pull ghcr.io/psrenergy/iara:latest
```

## Architecture Overview

### Core Module Structure ([src/IARA.jl](src/IARA.jl))

The module loads in a specific order representing dependency layers:

1. **Foundations**: Enumerations (`enumx.jl`), utilities, path handling
2. **Collections**: 16 data model types (see below)
3. **I/O**: Input loading, output writing, time series views
4. **Mathematical Model**: Variables, constraints, objective functions
5. **Algorithms**: SDDP, Nash equilibrium, market clearing, bidding strategies
6. **Post-processing**: Revenue, profit calculations, visualization

### Collections System ([src/collections/](src/collections/))

All entity types inherit from `AbstractCollection` and follow a common pattern:

**Generation Assets:**
- `HydroUnit` - Hydroelectric with cascading, volume tracking, minimum outflow
- `ThermalUnit` - Thermal generation with unit commitment, ramp constraints
- `RenewableUnit` - Wind/solar with curtailment, O&M costs
- `BatteryUnit` - Energy storage with charge/discharge cycles

**Network:**
- `Bus` - Electrical buses with voltage levels
- `Branch` - AC transmission lines with flow limits
- `DCLine` - DC interconnections
- `Interconnection` - Inter-regional connections

**Market Entities:**
- `BiddingGroup` - Strategic bidding entities (market participants)
- `AssetOwner` - Asset ownership for revenue/profit tracking
- `VirtualReservoir` - Aggregated hydro reservoirs for market modeling
- `DemandUnit` - Load centers with elastic/flexible demand support

**Other:**
- `Configurations` - Study parameters and run settings
- `GaugingStation` - Inflow measurement points
- `Zone` - Zonal aggregations

### Run Modes ([src/enumx.jl](src/enumx.jl))

The system supports multiple operational modes via `RunMode` enum:

- **`TRAIN_MIN_COST`** - Train SDDP model, save cuts for later use
- **`MIN_COST`** - Load saved cuts, run fast simulation
- **`MARKET_CLEARING`** - Full market clearing with bidding
- **`SINGLE_PERIOD_MARKET_CLEARING`** - Single period clearing (debugging)
- **`SINGLE_PERIOD_HEURISTIC_BID`** - Generate heuristic bids for one period

### Mathematical Model ([src/mathematical_model.jl](src/mathematical_model.jl))

Uses **action-based dispatch pattern**:
- `AbstractAction` - Base type for all model operations
- `SubproblemAction` - Actions per SDDP node (build/update)
- `ProblemAction` - Actions once per problem (output init/write)

**Model Action Types:**
1. `train_min_cost_model_action` - System cost minimization
2. `price_taker_bid_model_action` - Price-taking bidding agents
3. `price_maker_bid_model_action` - Strategic bidding (convex hull)
4. `market_clearing_model_action` - Full market clearing (hybrid/cost/bid-based)
5. `reference_curve_model_action` - Hydro reference curve generation

Variables and constraints are defined in:
- [src/model_variables/](src/model_variables/) - ~27 variable types
- [src/model_constraints/](src/model_constraints/) - ~31 constraint types

### External Time Series ([src/external_time_series/](src/external_time_series/))

Flexible time series reading system:
- `TimeSeriesView` - Generic time series with period/scenario/subperiod mapping
- `BidsView` - Strategic bid curves and quantities
- `ExAntePostViews` - Handles ex-ante (forecast) vs ex-post (actual) data
- `HourSubperiodMapping` - Aggregation between hourly and subperiod resolution
- Caching for flexible demand

### Data Flow

```
Case Files → load_study() → Database (SQLite via PSRClassesInterface)
    ↓
initialize_collections() → Load time series
    ↓
validate(inputs) → Error checking
    ↓
[By Run Mode]
├─ TRAIN_MIN_COST: build_model() → train_model!() → simulate()
├─ MIN_COST: build_model() → read_cuts() → simulate()
├─ MARKET_CLEARING: Multiple clearing models (ex-ante/ex-post)
└─ HEURISTIC_BID: Reference curve → Heuristic bids
    ↓
simulate() → Extract results
    ↓
write_outputs() → CSV/Quiver format
    ↓
post_process() → Revenue, profits, generation aggregates
    ↓
plot_outputs() → PlotlyLight visualizations
```

## Key Dependencies

- **JuMP** (=1.23.1) - Mathematical programming (pinned version)
- **HiGHS** (=1.9.2) - MIP solver (pinned version)
- **SDDP** (=1.8.1) - Stochastic dynamic programming (pinned version)
- **PSRClassesInterface** (0.17) - Database interface (SQLite)
- **DataFrames**, **CSV** - Data manipulation
- **ParametricOptInterface** - Parametric optimization
- **PeriodicAutoregressive** (=0.1.0) - PAR(p) model for inflow scenarios
- **Quiver** (0.1.13) - Efficient time series output writing
- **PlotlyLight** - Interactive visualizations

**Note:** Several dependencies are pinned to specific versions for stability.

## Test Organization

Tests follow pattern: `test/case_XX/subcase_name/test_case.jl`

**22 Major Test Categories:**
- `case_01` - Base physics (hydro cascading, thermal commitment, renewable curtailment)
- `case_04` - Strategic bidding
- `case_07` - Settlement (ex-ante/ex-post)
- `case_08` - Virtual reservoirs
- `case_09` - Seasonal modeling
- `case_10` - Heuristic bid generation
- `case_20` - Market clearing & bid justification

**Test Modes:**
- Set `UPDATE_RESULTS = true` to update expected outputs
- Set `RUN_BIG_TESTS = true` for computationally expensive tests
- Random seed fixed at 1234 for reproducibility

**Reduced Testing:**
Edit `reduced_test_list` dict in [test/runtests.jl](test/runtests.jl) to run specific subcases during development.

## Important Patterns

### Collection Pattern
All collections follow this interface:
- Time-varying attributes sync with specific periods via `update!()` methods
- Database read/write via PSRClassesInterface
- Asset owner filtering for multi-agent scenarios
- Validation and filtering capabilities

### Action Dispatch
Model building uses type-based dispatch:
- Define actions as subtypes of `AbstractAction`
- Implement methods for specific action types
- Centralized dispatcher selects model structure based on run mode and agent type

### View Pattern
Time series access uses view abstractions:
- Decouple data storage from access patterns
- Support ex-ante (forecast) vs ex-post (actual) data
- Enable hourly-to-subperiod aggregation
- Cache for flexible demand calculations

### Database Migrations
Schema versioning in [database/migrations/](database/migrations/) (30 versions) ensures backward compatibility.

## Special Features

- **Multi-Settlement**: Ex-ante (forecast) vs ex-post (actual) market clearing
- **Game Theory**: Nash equilibrium iteration for strategic bidding ([src/nash_equilibrium.jl](src/nash_equilibrium.jl))
- **Hydro Reference Curves**: Supply curve generation for virtual reservoirs ([src/reference_curve_nash.jl](src/reference_curve_nash.jl))
- **Stochastic Inflow**: PAR(p) model for scenario generation ([src/inflow.jl](src/inflow.jl))
- **Virtual Reservoirs**: Aggregate hydro modeling for market simulation
- **Flexible Demand**: Elastic and time-shiftable load profiles
- **Parametric Optimization**: Dynamic parameter sensitivity via ParametricOptInterface

## Common File Locations

- Main entry: [src/main.jl](src/main.jl)
- SDDP implementation: [src/sddp.jl](src/sddp.jl)
- Bidding logic: [src/bids.jl](src/bids.jl), [src/bid_validations.jl](src/bid_validations.jl)
- Market clearing: [src/clearing_utils.jl](src/clearing_utils.jl)
- Post-processing: [src/post_processing/](src/post_processing/)
- Plotting: [src/plots/](src/plots/)
- Example cases: [src/example_cases_builder.jl](src/example_cases_builder.jl)

## Development Notes

- Julia 1.9+ required
- CI runs on Windows/Ubuntu with Julia 1.11
- Code formatting enforced via JuliaFormatter
- All contributions require passing tests
- Database schema changes require new migration in `database/migrations/`
