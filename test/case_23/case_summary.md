# Case 23: 
- 8 agents, thermal only, 2 agent types. 
- IARA-UI case.
- No expected outputs.

## Variations:
- virtual_reservoir_case: 
    - from base_case.
    - 1 subscenario, adds one virtual reservoir to each agent.
- multiple_subscenarios_case: 
    - from virtual_reservoir_case.
    - modifies the case to have 3 subscenarios.
- renewables_case: 
    - from base_case.
    - removes two of each thermal agent type, replaces with two pairs of renewables.
- elastic_demand_and_renewables_case: 
    - from base_case.
    - removes two of each thermal agent type, adds two identical solar agents and two identical elastic demand agents.
    - 4 subscenarios: inelastic and elastic demand are perfectly correlated ([0.5, 0.5, 1.0, 1.0] p.u.), while solar is uncorrelated with them ([0.8, 0.2, 0.8, 0.2] p.u.), so net demand increases with the subscenario.
- elastic_demand_and_renewables_6_periods_case:
    - from elastic_demand_and_renewables_case.
    - extends the horizon from 4 to 6 periods; all time series are constant across periods, so the new periods repeat the existing ones.