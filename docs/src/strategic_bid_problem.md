# Strategic Bid Problem

This problem is defined at period $t$ and scenario $\omega$ for an asset owner $i$.

## Sets

Lists new or modified sets, not present in the centralized operation or price taker subproblems.

- ``I``: Set of asset owners.
- ``J^V(n, \tau)``: Set of vertices in the convex hull of the hypograph of the asset owner's revenue curve. One curve is defined for each network node $n$ and subperiod $\tau$.

### The revenue curve

To obtain $J^V(n, \tau)$, a preprocessing step is required, where the inputs are:

- The other asset owners' offers $(P_{i, n, \tau}(\omega), Q_{i, n, \tau}(\omega)) \forall j \in I | j \neq i$.
- The demand $D_{j, \tau, \omega} \forall j \in J^D(n)$.
- The deficit cost $C_\delta$.

## Parameters

Lists new or modified parameters, not present in the centralized operation or price taker subproblems.

- ``E^R_{v, n, \tau}(\omega)``: Revenue of vertice $v \in J^V(n, \tau)$.
- ``E^Q_{v, n, \tau}(\omega)``: Quantity of vertice $v \in J^V(n, \tau)$.
- ``P_{i, n, \tau}(\omega)``: Price offer of asset owner $i$ on network node $n$ during subperiod $\tau$ and scenario $\omega$.
- ``Q_{i, n, \tau}(\omega)``: Quantity offer of asset owner $i$ on network node $n$ during subperiod $\tau$ and scenario $\omega$.

## Variables

Lists new variables, not present in the centralized operation or price taker subproblems.

- ``\lambda_{v, n, \tau}``: Convex combination coefficients for vertice $v \in J^V(n, \tau)$.

## Subproblem Constraints

The following constraints are defined for a subproblem at period $t$ and scenario $\omega$ for an asset owner $i$.

### Revenue Curve: convex hull representation

A configuration parameter named ``aggregate buses for strategic bidding'' is defined to aggregate the other asset owners' offers $(P_{i, n, \tau}(\omega), Q_{i, n, \tau}(\omega))$ and the demand into a single bus to calculate the revenue curve. The equations below are presented for both the aggregated and non-aggregated cases. When the parameter is set to $true$, the following elements lose their bus dimension:

- The parameters $E^R_{v, n, \tau}(\omega)$ and $E^Q_{v, n, \tau}(\omega)$
- The set $J^V(n, \tau)$
- The variables $\lambda_{v, n, \tau}$

#### Non-aggregated revenue curve

```math
    \sum_{v \in J^V(n, \tau)}{E^Q_{v, n, \tau}(\omega) \lambda_{v, n, \tau}} = e_{n, \tau}
    \quad \forall n \in N, \tau \in B(t)
```

```math
    \sum_{v \in J^V(n, \tau)}{\lambda_{v, n, \tau}} = 1
    \quad \forall n \in N, \tau \in B(t)
```

```math
    \lambda_{v, n, \tau} \geq 0
    \quad \forall v \in J^V(n, \tau), n \in N, \tau \in B(t)
```

#### Aggregated revenue curve

```math
    \sum_{v \in J^V(\tau)}{E^Q_{v, \tau}(\omega) \lambda_{v, n, \tau}} = \sum_{n \in N}e_{n, \tau}
    \quad \forall \tau \in B(t)
```

```math
    \sum_{v \in J^V(\tau)}{\lambda_{v, \tau}} = 1
    \quad \forall \tau \in B(t)
```

```math
    \lambda_{v, \tau} \geq 0
    \quad \forall v \in J^V(\tau), \tau \in B(t)
```

The remaining constraints are copied from the price taker problem.

### Asset owner's total generation

```math
    e_{n, \tau} =
    \sum_{j \in J^T_i(n)}{g^T_{j, \tau}}
    + \sum_{j \in J^H_i(n)}{\rho_j (u_{j, \tau})}
    + \sum_{j \in J^R_i(n)}{g^R_{j, \tau}}
    + \sum_{j \in J^B_i(n)}{g^B_{j, \tau}} \\
    \quad \forall n \in N, \tau \in B(t)
```

### Hydro Balance

#### Intra-period balance

```math
    v_{j, \tau+1} = v_{j, \tau}
    - u_{j, \tau} - z_{j, \tau}
    + \sum_{n \in J^H_U(j)}{u_{n, \tau}}
    + \sum_{n \in J^H_Z(j)}{z_{n, \tau}} + a_{j, \tau}
    \quad \forall j \in J^H_i, \tau \in B(t)
```

#### Inter-period balance

```math
    v^{S_{in}}_j = v_{j, 1}
    \quad \forall j \in J^H_i
```

```math
    v^{S_{out}}_j = v_{j, |B(t)| + 1}
    \quad \forall j \in J^H_i
```

### Renewable Balance

```math
    g^R_{j, \tau} + y^r_{j, \tau} = G^R_{j, \tau}(\omega)
    \quad \forall j \in J^R_i, \tau \in B(t)
```

### Battery Unit Balance

#### Intra-period balance

```math
    s^b_{j, \tau+1} = s^b_{j, \tau} - g^B_{j, \tau}
    \quad \forall j \in J^B_i, \tau \in B(t)
```

#### Inter-period balance

```math
    s^{B_{in}}_j = s^b_{j, 1}
    \quad \forall j \in J^B_i
```

```math
    s^{B_{out}}_j = s^b_{j, |B(t)| + 1}
    \quad \forall j \in J^B_i
```

### Hydro Bounds

#### Volume bounds

```math
    0 \leq v_{j, \tau} \leq V_j, \quad
    \forall j \in J^H_i, \tau = 1, ..., |B(t)| + 1
```

#### Other bounds

```math
    0 \leq u_{j, \tau} \leq U_j, \quad
    0 \leq z_{j, \tau} , \quad
    \forall j \in J^H_i, \tau \in B(t)
```

### Thermal Bounds
```math
    0 \leq g^T_{j, \tau} \leq G^T_j, \quad
    \forall j \in J^T_i, \tau \in B(t)
```

### Renewable bounds

```math
    0 \leq g^R_{j, \tau} \leq G^R_j, \quad
    0 \leq y^r_{j, \tau} \leq G^R_j, \quad
    \forall j \in J^R_i
```

### Battery Unit bounds

```math
    -G^B_j \leq g^B_{j, \tau} \leq G^B_j, \quad
    0 \leq s^b_{j, \tau} \leq S^B_j, \quad
    \forall j \in J^B_i, \tau \in B(t)
```

## Objective Function

The objective function is similar to the price taker problem, but replaces the exogenous spot price $\pi_{n, \tau}(\omega)$ with the convex revenue representation. The equation presented below is for the non-aggregated case.

```math
    min{
    \sum_{\tau \in B(t)}{\left(
    - \sum_{n \in N}{\left(
    \sum_{v \in J^V(n, \tau)}{\lambda_{v, n, \tau} E^R_{v, n, \tau}(\omega)}
    \right)}
    + \sum_{j \in J^T_i}{C^T_j g^T_{j, \tau}}
    + \sum_{j \in J^R_i}{C^R_j y^r_{j, \tau}}
    \right)}
    }
```

When aggregating buses to calculate the revenue curve, the objective function becomes:

```math
    min{
    \sum_{\tau \in B(t)}{\left(
    - \sum_{v \in J^V(\tau)}{\lambda_{v, \tau} E^R_{v, \tau}(\omega)}
    + \sum_{j \in J^T_i}{C^T_j g^T_{j, \tau}}
    + \sum_{j \in J^R_i}{C^R_j y^r_{j, \tau}}
    \right)}
    }
```

