# Use Guides

## Editing the Cyclic Policy Graph Representation

- **Ncycles**: Number of cycles to represent.
- **Repeat Probability**: Probability of repeating cycles.
- **Hours per Subproblem vs. Hours in Year**: 
- **Discount Rate**: How to apply the discount rate in multi-cycle scenarios.

### Discuss and Indicate How to Change Cycle Representation

- Transition from a 2-cycle representation to a 4-cycle, 12-cycle, or 52-cycle model.
- **Probability Distributions**: Define the necessary probability distributions for each cycle. **More detailed instructions are required here.**

## Using the Sampler Module

- **Inputs**:
  - **nseries**: Number of series.
  - **nsubseries**: Number of subseries.

- **Types of Sampling**:
  - **History**: 
  - **iid**: 
  - **PAR-p(A)**: 

## [LONG-TERM] Network vs. De-Networked Representations

- **General Consideration**: This is not required for the initial deliverable (e6s), but it will likely be requested by ONS and CCEE in the future.
- **Simultaneous Representation**: Consider using both networked and de-networked representations within the same market clearing process (networked dispatch, de-networked pricing).
  - **Separate Bases**: Should the networked and de-networked representations be kept in two different folders? Think about the implications of this paradigm.

### Validators

- **Responsibilities**: The software should not be responsible for ensuring that networked and de-networked bases are consistent (e.g., in terms of interchange vs. circuits).
- **Single or Multiple Bases**: If two separate bases are used, validation becomes less crucial. However, if a single base supports multiple networks, improved validation may be possible.
  - **Entity List Validation**: Ensure at least that the list of entities is consistent across representations.
  - **Visualization Tools**: Consider creating a tool to contrast and compare the two representations.
  - **Zonal Representation**: CCEE may combine losses in its zonal representation. Should this be accounted for?

## [LONG-TERM] Interpreting Price Formation Paradigms

The model offers three main options for pricing paradigms in terms of timing:

1. **Ex ante pricing only**: A model unique to Brazil (p^1 q^2).
2. **Ex post pricing only**: Traditional ex post pricing (p^2 q^2).
3. **Two-Settlement Mechanism**: A hybrid approach (p^1 q^1 + p^2(q^2 - q^1)).

### Pricing Limits

- **Price Cap**: If the marginal price exceeds this cap, substitute the cap in the asset owners' revenue calculation.
- **Price Floor**: If the marginal price falls below this floor, substitute the floor in the asset owners' revenue calculation.
  - **Zonal Pricing vs. Nodal Dispatch**: Reference the other use guide for more details on zonal versus nodal pricing.

### Asset owner Strategy and Revenue Adjustment

- Asset owners will use their expected aggregate revenue (from the Clearing process) to adjust their strategy. The mechanism design significantly influences these price signals.

### [Meta Considerations]

- **Dual Settlement**: Explore dual settlement (versus ex post only, or Brazil's ex ante only model).
- **Price Cap and Price Floor**:
- **Pre-Offer Validation Period**: 
- **De-Networked Price Formation**: 
