# Centralized Operation Problem

## Sets

- ``J^T``: Set of thermal units.
- ``J^{TC}``: Set of commitment thermal units.
- ``J^H``: Set of hydro units.
- ``J^{HC}``: Set of commitment hydro units.
- ``J^{HR}``: Set of hydro units that operate with a reservoir.
- ``J^{HRR}``: Set of hydro units that operate with as run-of-the-river.
- ``J^R``: Set of renewable units.
- ``J^B``: Set of battery units.
- ``J^D``: Set of demands.
- ``J^{DI}``: Set of inelastic demands.
- ``J^{DE}``: Set of elastic demands. $J^{DE} \cap J^{DI} = \emptyset$.
- ``J^{DF}``: Set of flexible demands. $J^{DF} \cap J^{DE} = J^{DF} \cap J^{DI} = \emptyset$.
- ``L``: Set of transmission lines.
- ``N``: Set of network nodes (a.k.a. buses).
- ``N^{-ref}``: Set of network nodes, except for the angle reference node.
- ``B(t)``: Set of subperiods in period $t$.
- ``L^{in}(n)``: Set of lines entering node $n$.
- ``L^{out}(n)``: Set of lines exiting node $n$.
- ``J^H_U(j)``: Set of hydro units that turbine water to hydro unit $j$.
- ``J^H_Z(j)``: Set of hydro units that spill water to hydro unit $j$.
- ``B(j, t, w)``: Set of subperiods in window $w$ of flexible demand $j$ at period $t$.
- ``L^{DC}``: Set of DC lines. $L^{DC} \subseteq L$.
- ``L^{AC}``: Set of branches. $L^{AC} = L \setminus L^{DC}$.

Some branches may have a flag indicating that they are modeled as DC lines.

## Parameters

- ``d(\tau)``: Duration in hours of subperiod $\tau$.
- ``C_{u \rightarrow v}``: Conversion factor from unit $u$ to unit $v$.

### Hydro Units

- ``V_j``: Maximum volume of water ($hm^3$) in the reservoir of hydro unit $j$.
- ``U_j``: Maximum amount of water ($m^3/s$) that can be turbined from the hydro unit $j$.
- ``\rho_j``: Turbine efficiency ($MW/m^3/s$) of hydro unit $j$.
- ``a_{j, \tau}``: Inflow of water ($hm^3$) into the reservoir of hydro unit $j$ at the start of subperiod $\tau$.
- ``O_j``: Minimum outflow of water ($m^3/s$) from the reservoir of hydro unit $j$.
- ``C^\eta``: Cost ($\$/hm^3$) of minimum outflow violation.
- ``C^z_j``: Cost ($\$/hm^3$) of spilling water from hydro unit $j$.
- ``\overline{G}^H_j``: Maximum generation ($MW$) of hydro unit $j$.
- ``\underline{G}^H_j``: Minimum generation ($MW$) of hydro unit $j$.

### Thermal Units

- ``\overline{G}^T_j``: Maximum generation ($MW$) of thermal unit $j$.
- ``\underline{G}^T_j``: Minimum generation ($MW$) of thermal unit $j$.
- ``C^T_j``: Cost of generation ($\$/MWh$) of thermal unit $j$.
- ``C^{T_{up}}_j``: Cost of startup ($\$$) of thermal unit $j$.
- ``C^{T_{down}}_j``: Cost of shutdown ($\$$) of thermal unit $j$.
- ``x^T_{j, 0}``: Commitment of thermal unit $j$ at the start of the period.
- ``\Delta^{up}_j``: Ramp-up limit ($MW/min$) of thermal unit $j$.
- ``\Delta^{down}_j``: Ramp-down limit ($MW/min$) of thermal unit $j$.
- ``g^T_{j, 0}``: Generation ($MW$) of thermal unit $j$ at the start of the period.
- ``UT^{max}_j``: Maximum uptime ($h$) of thermal unit $j$.
- ``UT^{min}_j``: Minimum uptime ($h$) of thermal unit $j$.
- ``DT^{min}_j``: Minimum downtime ($h$) of thermal unit $j$.
- ``t^{up}_{j,0}``: Uptime ($h$) of thermal unit $j$ at the start of the period.
- ``t^{down}_{j,0}``: Downtime ($h$) of thermal unit $j$ at the start of the period.

### Renewable Units

- ``G^R_j``: Maximum generation ($MW$) of renewable unit $j$.
- ``G^R_{j, \tau}(\omega)``: Realized generation ($p.u.$, as a fraction of the maximum generation) of renewable unit $j$ during subperiod $\tau$ and scenario $\omega$.
- ``C^R_j``: Cost of curtailment ($\$/MWh$) of renewable unit $j$.

### Battery Units

- ``G^B_j``: Maximum generation ($MW$) of battery unit $j$.
- ``\overline{s}^B_j``: Maximum state ($MWh$) of charge of battery unit $j$.
- ``\underline{s}^B_j``: Minimum state ($MWh$) of charge of battery unit $j$.

### Demands

- ``D_{j, \tau}(\omega)``: Load ($GWh$) of demand $j$ during subperiod $\tau$ and scenario $\omega$.
- ``C^\delta``: Cost of demand deficit ($\$/MWh$).
- ``C^{\delta^F}_{j, \tau}``: Cost demand curtailment ($\$/MWh$) of demand $j$ during subperiod $\tau$.
- ``P_{j, \tau}(\omega)``: Maximum price ($\$/MWh$) of elastic demand $j$ during subperiod $\tau$ and scenario $\omega$.
- ``W_{j, t}``: Window of demand $j$ at period $t$, if $j \in J^{DF}$.
- ``\underline{d}^F_j``: Maximum fraction of flexible demand $j$ to be under attended at some subperiod.
- ``\overline{d}^F_j``: Maximum fraction of flexible demand $j$ to be over attended at some subperiod.
- ``\overline{\delta}^F_j``: Maximum fraction of flexible demand $j$ to be curtailed at a window.

### DC Lines

- ``n^{from}_j``: Node where line $j$ starts.
- ``n^{to}_j``: Node where line $j$ ends.
- ``\overline{f}^{from}_j``: Maximum flow ($MW$) from node $n^{to}_j$ to node $n^{from}_j$.
- ``\overline{f}^{to}_j``: Maximum flow ($MW$) from node $n^{from}_j$ to node $n^{to}_j$.


### Branches

- ``n^{from}_j``: Node where line $j$ starts.
- ``n^{to}_j``: Node where line $j$ ends.
- ``\overline{f}_j``: Maximum flow ($MW$) of line $j$.
- ``X_j``: Reactance ($p.u.$) of line $j$.


## Variables

### Hydro Units

- ``g^H_{j, \tau}``: Generation ($MWh$) of hydro unit $j$ during subperiod $\tau$.
- ``v_{j, \tau}``: Volume of water ($hm^3$) in the reservoir at the start of subperiod $\tau$.
- ``u_{j, \tau}``: Turbined water ($hm^3$) from the reservoir during subperiod $\tau$.
- ``z_{j, \tau}``: Spilled water ($hm^3$) from the reservoir during subperiod $\tau$.
- ``v^{S_{in}}_j``: Volume of water ($hm^3$) in the reservoir at the start of the period.
- ``v^{S_{out}}_j``: Volume of water ($hm^3$) in the reservoir at the end of the period.
- ``\eta_{j, \tau}``: Hydro minimum outflow violation ($hm^3$) during subperiod $\tau$.
- ``x^H_{j, \tau}``: Commitment of hydro unit $j$ during subperiod $\tau$.

### Thermal Units

- ``g^T_{j, \tau}``: Generation ($MWh$) of thermal unit $j$ during subperiod $\tau$.
- ``x^T_{j, \tau}``: Commitment of thermal unit $j$ during subperiod $\tau$.
- ``y^T_{j, \tau}``: Startup of thermal unit $j$ during subperiod $\tau$.
- ``w^T_{j, \tau}``: Shutdown of thermal unit $j$ during subperiod $\tau$.

### Renewable Units

- ``g^R_{j, \tau}``: Generation ($MWh$) of renewable unit $j$ during subperiod $\tau$.
- ``z^r_{j, \tau}``: Spilled generation ($MWh$) of renewable unit $j$ during subperiod $\tau$.


### Battery Units

- ``s^B_{j, \tau}``: State of charge ($MWh$) of battery unit $j$ at the start of subperiod $\tau$.
- ``g^B_{j, \tau}``: Generation ($MWh$) of battery unit $j$ at the end of subperiod $\tau$.
- ``s^{B_{in}}_j``: State of charge ($MWh$) of battery unit $j$ at the start of the period.
- ``s^{B_{out}}_j``: State of charge ($MWh$) of battery unit $j$ at the end of the period.

### Demands

- ``\delta_{j, \tau}``: Demand deficit ($GWh$) of demand $j$ during subperiod $\tau$.
- ``\delta^F_{j, \tau}``: Demand curtailment ($GWh$) of demand $j$ during subperiod $\tau$.
- ``d^F_{j, \tau}``: Flexible demand to be attended ($GWh$) of demand $j$ during subperiod $\tau$.
- ``d^E_{j, \tau}``: Elastic demand to be attended ($GWh$) of demand $j$ during subperiod $\tau$.

### Transmission Lines

- ``f_{j, \tau}``: Flow ($MW$) of line $j$ during subperiod $\tau$.

### Network Nodes

- ``\theta_{n, \tau}``: Voltage angle ($rad$) at node $n$ during subperiod $\tau$.

## Subproblem Constraints

The following constraints are defined for a subproblem at period $t$ and scenario $\omega$.

### Demand Balance

```math
    C_{MW \rightarrow GW}  \bigg(
    \sum_{j \in J^T(n)}{g^T_{j, \tau}}
    + \sum_{j \in J^H(n)}{g^H_{j, \tau}}
    + \sum_{j \in J^R(n)}{g^R_{j, \tau}}
    + \sum_{j \in J^B(n)}{g^B_{j, \tau}} 
    + \sum_{l \in L^{in}(n)}{f_{j, \tau} \cdot d(\tau)} \\
    - \sum_{l \in L^{out}(n)}{f_{j, \tau} \cdot d(\tau)} \bigg)
    + \sum_{j \in J^{DI}(n)}{\delta_{j, \tau}}
    = \sum_{j \in J^{DI}(n)}{D_{j, \tau, \omega}}
    + \sum_{j \in J^{DF}(n)}{d^F_{j, \tau}} \\
    + \sum_{j \in J^{DE}(n)}{d^E_{j, \tau}}
    \quad \forall n \in N, \tau \in B(t)
```

### Demand shift bounds

```math
    (1 - \underline{d}^F_j) \cdot D_{j, \tau, \omega}
    \leq d^F_{j, \tau} + \delta_{j, \tau}
    \leq (1 + \overline{d}^F_j) \cdot D_{j, \tau, \omega}
    \quad \forall j \in J^{DF}, \tau \in B(t)
```

### Demand window sum

```math
    \sum_{\tau \in B(j, t, w)} (d^F_{j, \tau} + \delta^F_{j, \tau})
    = \sum_{\tau \in B(j, t, w)} ( D_{j, \tau, \omega} - \delta_{j, \tau} )
    \quad \forall j \in J^{DF}, w \in W_{j, t}
```

### Demand window maximum curtailment

```math
    \sum_{\tau \in B(j, t, w)} \delta^F_{j, \tau}
    \leq \sum_{\tau \in B(j, t, w)} \overline{\delta}^F_j D_{j, \tau, \omega}
    \quad \forall j \in J^{DF}, w \in W_{j, t}
```

### Hydro Balance

#### Intra-period balance

```math
    v_{j, \tau+1} = v_{j, \tau} - u_{j, \tau} - z_{j, \tau}
    + \sum_{n \in J^H_U(j)}{u_{n, \tau}} 
    + \sum_{n \in J^H_Z(j)}{z_{n, \tau}} +  a_{j, \tau} \\
    \quad \forall j \in J^H, \tau \in B(t)
```

#### Inter-period balance

```math
    v^{S_{in}}_j = v_{j, 1}
    \quad \forall j \in J^H
```

```math
    v^{S_{out}}_j = v_{j, |B(t)| + 1}
    \quad \forall j \in J^H
```

#### Initial and final volume of run of river hydro units

```math
    v_{j, 1} = v_{j, |B(t)| + 1}
    \quad \forall j \in J^{HRR}
```

### Hydro Generation
    
```math
    g^H_{j, \tau} = \rho_j u_{j, \tau} C_{hm^3/h \rightarrow m^3/s}
\quad \forall j \in J^H, \tau \in B(t)
```

### Hydro Minimum Outflow

```math
    u_{j, \tau} + z_{j, \tau} + \eta_{j, \tau} \geq O_j \cdot d(\tau) \cdot C_{m^3/s \rightarrow hm^3/h}
    \quad \forall j \in J^H, \tau \in B(t)
```

### Thermal Commitment

```math
    y^T_{j, \tau} - w^T_{j, \tau} = x^T_{j, \tau} - x^T_{j, \tau-1}
    \quad \forall j \in J^{TC}, \tau \in B(t)
```

```math
    y^T_{j, \tau} + w^T_{j, \tau} \leq x^T_{j, \tau} + x^T_{j, \tau-1}
    \quad \forall j \in J^{TC}, \tau \in B(t)
```

```math
    y^T_{j, \tau} + w^T_{j, \tau} + x^T_{j, \tau} + x^T_{j, \tau-1} \leq 2
    \quad \forall j \in J^{TC}, \tau \in B(t)
```

### Thermal Ramping

```math
    \frac{g^T_{j, \tau}}{d(\tau)} - \frac{g^T_{j, \tau-1}}{d(\tau-1)} \leq \Delta^{up}_j \cdot C_{1/h \rightarrow 1/min} \cdot \frac{d(\tau)+d(\tau-1)}{2}
    \quad \forall j \in J^T, \tau \in B(t)
```

```math
    \frac{g^T_{j, \tau-1}}{d(\tau-1)} - \frac{g^T_{j, \tau}}{d(\tau)} \leq \Delta^{down}_j \cdot C_{1/h \rightarrow 1/min} \cdot \frac{d(\tau)+d(\tau-1)}{2}
    \quad \forall j \in J^T, \tau \in B(t)
```

### Thermal Minimum Up/Down Time

Based on the initial conditions $t^{up}_{j,0}$ and $t^{down}_{j,0}$, the following terms are defined:

```math
    I^{up}_{j, \tau} =
    \begin{cases}
        1 & \text{if } t = 1 \text{ and } t^{up}_{j, 0} + \sum_{\gamma = 1}^{\tau - 1}{d(\gamma)} < UT^{min}_j \\
        0 & \text{otherwise}
    \end{cases}
    \quad \forall j \in J^{TC}, \tau \in B(t)
```

```math
    I^{down}_{j, \tau} =
    \begin{cases}
        1 & \text{if } t = 1 \text{ and } t^{down}_{j, 0} + \sum_{\gamma = 1}^{\tau - 1}{d(\gamma)}  < DT^{min}_j \\
        0 & \text{otherwise}
    \end{cases}
    \quad \forall j \in J^{TC}, \tau \in B(t)
```
The indicators $I^{up}$ and $I^{down}$ represent whether the plant started/stopped in the previous period AND has yet to reach the minimum uptime/downtime.
Also, the following auxiliar terms are defined:

```math
    \Gamma^{UT^{min}}_{j, \tau} = min \left\{ \gamma \in B(t) \Big\vert \sum_{\kappa = \gamma}^{\tau-1}{d(\kappa) < UT^{min}_j } \right\}
```
```math
    \Gamma^{DT^{min}}_{j, \tau} = min \left\{ \gamma \in B(t) \Big\vert \sum_{\kappa = \gamma}^{\tau-1}{d(\kappa) < DT^{min}_j } \right\}
```

With these terms, the following constraints are defined:

```math
    \left(\sum_{\gamma = \Gamma^{UT^{min}}_{j, \tau}}^{\tau}{y^T_{j, \gamma}}\right) + I^{up}_{j, \tau} \leq x^T_{j, \tau} , 
    \quad \forall j \in J^{TC}, \tau \in B(t)
```

```math
    \left(\sum_{\gamma= \Gamma^{DT^{min}}_{j, \tau}}^{\tau}{w^T_{j, \gamma}}\right) + I^{down}_{j, \tau} \leq 1 - x^T_{j, \tau}, 
    \quad \forall j \in J^{TC}, \tau \in B(t)
```

For the uptime, the constraint states that if the plant started in the last $UT^{min}_j$ hours or if the indicator $I^{up}_{j, \tau}$ is active, then the plant must remain active.
The same logic applies to the downtime.

### Thermal Maximum Uptime

Based on the initial condition $t^{up}_{j,0}$ and the $UT^{max}$ parameter, the following terms are defined:

```math
    T^{up}_{j, \tau} =
    \begin{cases}
        t^{up}_{j, 0}     & \text{if } t^{up}_{j, 0} + \sum_{\gamma = 1}^{\tau - 1}{d(\gamma)} \leq UT^{max}_j \\
        UT^{max}_j - \sum_{\gamma = 1}^{\tau - 1}{d(\gamma)} & \text{if } \sum_{\gamma = 1}^{\tau - 1}{d(\gamma)} \leq UT^{max}_j               \\
        0                 & \text{otherwise}
    \end{cases}
    \quad \forall j \in J^{TC}, \tau \in B(t)
```

```math
     \Gamma^{UT^{max}}_{j, \tau} = min \left\{ \gamma \in B(t) \Big\vert \sum_{\kappa = \gamma}^{\tau-1}{d(\kappa) \leq UT^{max}_j } \right\}
```
For a time window of $UT^{max}_j$ hours before the beginning of subperiod $\tau$, the term $T^{up}_{j, \tau}$ represents the amount of hours that the plant has been active in the period before. The term $\Gamma^{UT^{max}}_{j, \tau}$ indicates the first subperiod in the current period that is within the time window of $UT^{max}_j$ hours before the current subperiod $\tau$. 

With these terms, the following constraint is defined:

```math
    \left(\sum_{\gamma=\Gamma^{UT^{max}}_{j, \tau}}^{\tau}{d(\tau) \cdot x^T_{j, \gamma}}\right) + T^{up}_{j, \tau} \leq UT^{max}_j
    \quad \forall j \in J^{TC}, \tau \in B(t)
```
The constraint states that the amount of time that the plant has been active in the last $UT^{max}_j$ hours plus the time that the plant is active in the current subperiod must be less than or equal to $UT^{max}_j$.


### Renewable Balance

```math
    g^R_{j, \tau} + z^r_{j, \tau} = G^R_{j, \tau}(\omega)\cdot G^R_j \cdot d(\tau)
    \quad \forall j \in J^R, \tau \in B(t)
```

### Battery Unit Balance

#### Intra-period balance

```math
    s^B_{j, \tau+1} = s^B_{j, \tau} - g^B_{j, \tau}
    \quad \forall j \in J^B, \tau \in B(t)
```

#### Inter-period balance

```math
    s^{B_{in}}_j = s^B_{j, 1}
    \quad \forall j \in J^B
```

```math
    s^{B_{out}}_j = s^B_{j, |B(t)| + 1}
    \quad \forall j \in J^B
```

### Kirchhoff's Voltage Law

When considering the compact version of the power flow, the following constraints can be omitted and the voltage angles are not decision variables.

```math
    \frac{-1}{X_j} (\theta_{n^{to}_j, \tau} - \theta_{n^{from}_j, \tau}) = f_{j, \tau}, \quad
    \forall j \in L^{AC}, \tau \in B(t)
```

### Hydro Bounds

#### Volume bounds

```math
    0 \leq v_{j, \tau} \leq V_j, \quad
    \forall j \in J^H, \tau = 1, ..., |B(t)| + 1
```

#### Commitment plants

```math
    \underline{G}^H_j x^H_{j, \tau}\cdot d(\tau) \leq g^H_{j, \tau} \leq \overline{G}^H_j x^H_{j, \tau}\cdot d(\tau)
    , \quad \forall j \in J^{HC}, \tau \in B(t)
```

#### Other bounds

```math
    0 \leq u_{j, \tau} \leq U_j \cdot d(\tau) \cdot C_{m^3/s \rightarrow hm^3/h}, \quad
    z_{j, \tau} \geq 0 , \quad
    \eta_{j, \tau} \geq 0, \quad
    0 \leq g^H_{j, \tau} \leq \overline{G}^H_j\cdot d(\tau), \\
    \forall j \in J^H, \tau \in B(t)
```

### Thermal Bounds

#### Commitment plants

```math
    \underline{G}^T_j x^T_{j, \tau}\cdot d(\tau) \leq g^T_{j, \tau} \leq \overline{G}^T_j x^T_{j, \tau}\cdot d(\tau)
    , \quad \forall j \in J^{TC}, \tau \in B(t)
```

#### Other plants

```math
    \underline{G}^T_j\cdot d(\tau) \leq g^T_{j, \tau} \leq \overline{G}^T_j\cdot d(\tau), \quad
    \forall j \in J^T \setminus J^{TC}, \tau \in B(t)
```

### Renewable bounds

```math
    0 \leq g^R_{j, \tau}, \quad
    0 \leq z^r_{j, \tau}, \quad
    \forall j \in J^R, \tau \in B(t)
```

### Battery Unit bounds

```math
    -G^B_j \cdot d(\tau) \leq g^B_{j, \tau} \leq G^B_j \cdot d(\tau), \quad
    \underline{s}^B_j \leq s^B_{j, \tau} \leq \overline{s}^B_j, \quad
    \forall j \in J^B, \tau \in B(t)
```

### Transmission Bounds

#### DC Lines

```math
    -\overline{f}^{from}_j \leq f_{j, \tau} \leq \overline{f}^{to}_j, \quad
    \forall j \in L^{DC}, \tau \in B(t)
```

#### Branches

When the complete DC power flow formulation is considered, the flow limits are given by:

```math
    -\overline{f}_j \leq f_{j, \tau} \leq \overline{f}_j, \quad
    \forall j \in L^{AC}, \tau \in B(t)
```

Whereas the compact form of the power flow considers the flow limits as:

```math
    -\overline{f}_j \leq \sum_{n \in N^{-ref}}{\beta_{j, n} \cdot (\sum_{l \in L^{out}(n)}f_{l, \tau} - \sum_{l \in L^{in}(n)}f_{l, \tau})} \leq \overline{f}_j, \quad
    \forall j \in L^{AC}, \tau \in B(t)
```

Where $\beta$ is the branch flow sensitivity matrix, that can be calculated using the data from the nodes and branches.

```math
    \beta = \Gamma A^T(A \Gamma A^T)^{-1}
```

The matrix $A$ is the reduced incidence matrix and $\Gamma$ is the diagonal matrix with the susceptance of each branch of the system.

The incidence matrix defines the connections between the network nodes and branches. It has the node indices as the matrix rows, and the branch indices as the matrix columns. The elements are $1$ in the intersection of a `from` node row and the branch column, $-1$ in the intersection of a `to` node row and the branch column, and $0$ otherwise, i.e., when the node column does not belong to the branch column. Finally, the reduced incidence matrix is given by the elimination of the row corresponding to the reference node in the original incidence matrix.

### Demand Deficit Bounds

```math
    \delta_{j, \tau} \geq 0, \quad
    \forall j \in J^D, \tau \in B(t)
```

### Attended Elastic Demand Bounds

```math
    0 \leq d^E_{j, \tau} \leq D_{j, \tau, \omega}, \quad
    \forall j \in J^{DE}, \tau \in B(t)
```

## Objective Function

```math
\text{min} \quad C_{\$ \rightarrow k\$} \sum_{\tau \in B(t)} \Bigg(
    C_{GW \rightarrow MW} \bigg( \sum_{j \in J^D} C^\delta \delta_{j, \tau}
    + \sum_{j \in J^{DF}} C^{\delta^F}_{j, \tau} \delta^F_{j, \tau}
    - \sum_{j \in J^{DE}} P_{j, \tau}(\omega) d^E_{j, \tau} \bigg) 
    
    + \sum_{j \in J^H} \left( C^\eta \eta_{j, \tau}  + C^z z_{j, \tau} \right) \\
    + \sum_{j \in J^T} \left( C^{T_{up}}_j y^T_{j, \tau}
    + C^{T_{down}}_j w^T_{j, \tau} \right) 

    +  \bigg( \sum_{j \in J^T} C^T_j g^T_{j, \tau}
    + \sum_{j \in J^R} C^R_j z^r_{j, \tau} + \sum_{r \in R} C^\varphi_r \varphi_{r, \tau}  
    \bigg)
    \Bigg)
```
