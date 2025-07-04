# Market Clearing Problem

This problem is defined at period $t$ and scenario $\omega$.

## Sets

Lists new sets, not present in the centralized operation subproblems.

- ``K(i, n)``: Set of segment offers at node $n$ for the asset owner $i$.
- ``K^M(i)``: Set of bid profiles for the asset owner $i$.
- ``\mathcal{K}_m(i)``: Complementary grouping $m$ for the asset owner $i$.
- ``J^{VR}``: Set of virtual reservoirs.
- ``J^H_VR``: Set of hydro units associated with some virtual reservoir.
- ``J^H_{VR}(r)``: Set of hydro units associated with virtual reservoir $r$.
- ``I^{VR}(r)``: Set of asset owners associated with virtual reservoir $r$.
- ``K^{VR}(r, i)``: Set of segment offers at virtual reservoir $r$ for the asset owner $i$.
- ``P^{WG}(r)``: Set of waveguide points for virtual reservoir $r$. 

## Parameters

We add the following parameters to the list of parameters of the strategic subproblem:

### Flexible Bids

- ``P_{i, n, \tau, k}(\omega)``: Price offer of asset owner $i$ on network node $n$ during subperiod $\tau$, segment $k$ and scenario $\omega$.
- ``Q_{i, n, \tau, k}(\omega)``: Quantity offer of asset owner $i$ on network node $n$ during subperiod $\tau$, segment $k$ and scenario $\omega$.

### Profile Bids

- ``P^M_{i, n, k}(\omega)``: Price offer of asset owner $i$ on network node $n$, profile $k$ and scenario $\omega$.
- ``Q^M_{i, n, \tau, k}(\omega)``: Quantity offer of asset owner $i$ on network node $n$ during subperiod $\tau$, profile $k$ and scenario $\omega$.
- ``\mathcal{p}(k)``: Parent profile of profile $k$.
- ``X_{i, k}(\omega)``: Minimum activation level of profile $k$ of asset owner $i$ on network node $n$ and scenario $\omega$.

### Virtual Reservoirs
- ``P^{VR}_{r, i, k}(\omega)``: Price offer of asset owner $i$ on virtual reservoir $r$ for segment $k$ at scenario $\omega$.
- ``Q^{VR}_{r, i, k}(\omega)``: Quantity offer of asset owner $i$ on virtual reservoir $r$ for segment $k$ at scenario $\omega$.
- ``v^{WG}_{r, h, p}``: Hydro $h$ volume at waveguide point $p$ of virtual reservoir $r$.
- ``E^{in}_{r,i}``: Energy account of asset owner $i$ on virtual reservoir $r$ at beginning of period.
- ``\zeta_{r,h}``: Factor that converts the water volume at hydro unit $h$, where $h \in J^H_{VR}(r)$, into energy. 
- ``e^{inflow}_r``: Additional energy from inflow water, at virtual reservoir $r$.
- ``\gamma^{VR}_{r,i}``: Inflow shares of asset owner $i$ at virtual reservoir $r$. $\sum_{i \in I^{VR}(r)} \gamma^{VR}_{r,i} = 1 \; \forall r \in J^{VR}$.


## Variables

Lists new variables, not present in the centralized operation subproblems.

### Flexible Bids

- ``\lambda_{i, n, \tau, k}``: Linear combination coefficients for segment offer $k$ of asset owner $i$ on network node $n$ during subperiod $\tau$.
- ``q_{i, n, \tau, k}``: Total energy generated by asset owner $i$ on network node $n$ during subperiod $\tau$ related to the segment offer $k$.

### Multi-hour Bids

- ``\lambda^M_{i, k}``: Convex combination coefficients for profile $k$ of asset owner $i$.
- ``\lambda^X_{i, k}``: Activation of profile $k$ of asset owner $i$.
- ``q^M_{i, n, \tau, k}``: Total energy generated by asset owner $i$ on network node $n$ during subperiod $\tau$ related to the profile $k$.

### Virtual Reservoirs

- ``q^{VR}_{r, i, k}``: Total energy generated by asset owner $i$ on virtual reservoir $r$ related to segment offer $k$.
- ``\lambda^{WG}_{r, p}``: Convex combination coefficients for the waveguide point $p$ of virtual reservoir $r$.
- ``\delta^{WG}_{r, h}``: Hydro $h$ volume distance to waveguide points of virtual reservoir $r$.
- ``E^{out}_{r,i}``: Energy account of asset owner $i$ at virtual reservoir $r$ at the end of the period.

## Subproblem Constraints

### Offer bounds

Flexible Bids

```math
    0 \leq \lambda_{i, n , \tau, k} \leq 1 \quad \forall i \in I, n \in N, \tau \in B(t), k \in K(i, n) \\
```

Profile Bids

```math
    0 \leq \lambda^M_{i, k} \leq 1 \quad \forall i \in I, k \in K^M(i) \\
```

```math
    \lambda^X_{i, k} \in \{0, 1\} \quad \forall i \in I, k \in K^M(i) \\
```

Virtual Reservoirs

```math
    0 \leq q^{VR}_{r, i, k} \leq Q^{VR}_{r, i, k}(\omega) \quad \forall r \in J^{VR}, i \in I^{VR}(r), k \in K^{VR}(r, i) \\
```

### Bids Segment Curve

Flexible Bids

```math
    q_{i, n, \tau, k} = \lambda_{i, n , \tau, k} Q_{i, n, \tau, k}(\omega) \quad \forall i \in I, n \in N, \tau \in B(t), k \in K(i, n) \\
```

Profile Bids
    
```math
    q^M_{i, n, \tau, k} = \lambda^M_{i, k} Q^M_{i, n, \tau, k}(\omega) \quad \forall i \in I, n \in N, \tau \in B(t), k \in K^M(i) \\
```

### Complementarity Constraints

```math
    \sum_{k \in K}{\lambda^M_{i, k}} \leq 1 \quad \forall K \in \mathcal{K}_m(i), i \in I, m \in M \\
```

### Precedence Relationship

```math
    \lambda^M_{i, k} \leq \lambda^M_{i, \mathcal{p}(k)} \quad \forall i \in I, k \in K^M(i) \\
```

### Minimum Acceptance

```math
   \lambda^X_{i, k} X_{i, k}(\omega) \leq \lambda^M_{i, k} \leq \lambda^X_{i, k} \quad \forall i \in I, k \in K^M(i) \\
```

### Positive Final Account
```math
E^{out}_{r,i} = E^{in}_{r,i} + e^{inflow}_r \cdot \gamma^{VR}_{r,i} - \sum_{k \in K^{VR}(r, i)}{q^{VR}_{r, i, k}} \quad \forall i \in I^{VR}(r), \forall r \in J^{VR} \\
E^{out}_{r,i} \ge 0 \quad \forall i \in I^{VR}(r), \forall r \in J^{VR}
```


### Physical-Virtual Coupling

The physical-virtual coupling can be done by generation:
```math
    \sum_{\tau \in B(t)}{\sum_{h \in J^H_{VR}(r)}{(u_{h, \tau} + s_{h, \tau}) \cdot \rho_h \cdot C_{hm^3/h \rightarrow m^3/s}}} = \sum_{i \in I^{VR}(r)}{\sum_{k \in K^{VR}(r, i)}{q^{VR}_{r, i, k}}} \quad \forall r \in J^{VR}
```
or by volume:
```math
    \sum_{h \in J^H_{VR}(r)} v_{h, \tau^{end}} \cdot \zeta_{r,h} = \sum_{i \in I^{VR}(r)} \left(E^{out}_{r,i} - \sum_{k \in K^{VR}(r,i)} q^{VR}_{r,i,k}\right) \quad \forall r \in J^{VR}

```


### Waveguide Convex Combination

```math
    \sum_{p \in P^{WG}(r)}{\lambda^{WG}_{r, p}} = 1 \quad \forall r \in J^{VR}
```

### Waveguide Volume Distance

```math
    \delta^{WG}_{r, h} \geq v_{h, \tau^{end}} - \sum_{p \in P^{WG}(r)}{\lambda^{WG}_{r, p} v^{WG}_{r, h, p}} \quad \forall r \in J^{VR}, h \in J^H_{VR}(r)  \\

    \delta^{WG}_{r, h} \geq \sum_{p \in P^{WG}(r)}{\lambda^{WG}_{r, p} v^{WG}_{r, h, p}} - v_{h, \tau^{end}} \quad \forall r \in J^{VR}, h \in J^H_{VR}(r) 
```


### Demand Balance

```math
    \sum_{i \in I} \sum_{k \in K(i, n)}{q_{i, n, \tau, k}}
    + \sum_{i \in I} \sum_{k \in K^M(i, n)}{q^M_{i, n, \tau, k}}
    + \sum_{h \in J^H_{VR}}{g^H_{h, \tau}}
    + \sum_{l \in L^{in}(n)}{f_{l, \tau}}
    - \sum_{l \in L^{out}(n)}{f_{l, \tau}}
    + \sum_{j \in J^D(n)}{\delta_{j, \tau}} \\
    = \sum_{j \in J^D(n)}{D_{j, \tau, \omega}}
    \quad \forall n \in N, \tau \in B(t)
```

### Transmission Bounds

```math
    -F_{j, \tau} \leq f_{j, \tau} \leq F_{j, \tau}, \quad
    \forall j \in L, \tau \in B(t)
```

### Demand Deficit Bounds

```math
    0 \leq \delta_{j, \tau}, \quad
    \forall j \in J^D, \tau \in B(t)
```

### Convex combination bounds

```math
    0 \leq \lambda^{WG}_{r, p} \leq 1 \quad \forall r \in J^{VR}, p \in P^{WG}(r)
```

## Objective Function

Flexible Bids

```math
    min{
    \sum_{\tau \in B(t)}{
        \sum_{n \in N}{
            \sum_{i \in I} \sum_{k \in K(i, n)}{P_{i, n, \tau, k}(\omega) q_{i, n, \tau, k}}
        }
    }
    }
```
Multi-hour Bids

```math
    min{
    \sum_{\tau \in B(t)}{
        \sum_{n \in N}{
            \sum_{i \in I} \sum_{k \in K^M(i)}{P^M_{i, k}(\omega) q^M_{i, n, \tau, k}}
        }
    }
    }
```

Virtual Reservoirs

```math
    min{
    \sum_{r \in J^{VR}}{
        \sum_{i \in I_{VR}(r)}{
            \sum_{k \in K^{VR}(r, i)}{P^{VR}_{r, i, k}(\omega) q^{VR}_{r, i, k}}
        }
    }
    }
```

Hydro Units related to Virtual Reservoirs

```math
    min{
    \sum_{\tau \in B(t)} \sum_{h \in J^{H}_{VR}}{
        C^H g^H_{h, \tau}
    }
    }
```

Waveguide distance penalty

```math
    min{ \quad \varepsilon \cdot
    \sum_{r \in J^{VR}}{
        \sum_{h \in J^H_{VR}(r)} \delta^{WG}_{r, h}
    }
    }
```

Hydro constraints penalty

```math
    min{
    \sum_{\tau \in B(t)}{
        \sum_{j \in J^H} C^\eta \eta_{j, \tau}
    }
    }
```

