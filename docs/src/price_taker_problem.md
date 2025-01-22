# Price Taker Problem

This problem is defined at period $t$ and scenario $\omega$ for an asset owner $i$.

## Sets

Lists new or modified sets, not present in the centralized operation subproblem.

- ``J^T_i``: Set of thermal units owned by asset owner $i$.
- ``J^H_i``: Set of hydro units owned by asset owner $i$.
- ``J^R_i``: Set of renewable units owned by asset owner $i$.
- ``J^B_i``: Set of battery units owned by asset owner $i$.

## Parameters

Lists new or modified parameters, not present in the centralized operation subproblem.

- ``\pi_{n, \tau}(\omega)``: Price of electricity on network node $n$ during subperiod $\tau$ and scenario $\omega$.

## Variables

Lists new variables, not present in the centralized operation subproblem.

- ``e_{n, \tau}``: Asset owner's total generation on network node $n$ during subperiod $\tau$.

## Subproblem Constraints

The following constraints are defined for a subproblem at period $t$ and scenario $\omega$ for an asset owner $i$.

### Asset owner's total generation

```math
    e_{n, \tau} =
    \sum_{j \in J^T_i(n)}{g^T_{j, \tau}}
    + \sum_{j \in J^H_i(n)}{\rho_j (u_{j, \tau})}
    + \sum_{j \in J^R_i(n)}{g^R_{j, \tau}}
    + \sum_{j \in J^B_i(n)}{g^B_{j, \tau}} \\
    \quad \forall n \in N, \tau \in B(t)
```

The remaining constraints are a subset of the centralized operation problem, but only for the asset owner's assets. Notably, network, demand balance and deficit constraints are not included.

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
    g^R_{j, \tau} + z^r_{j, \tau} = G^R_{j, \tau}(\omega)
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
    \underline{G}^T_j\cdot d(\tau) \leq g^T_{j, \tau} \leq \overline{G}^T_j\cdot d(\tau), \quad
    \forall j \in J^T_i, \tau \in B(t)
```

### Renewable bounds

```math
    0 \leq g^R_{j, \tau}, \quad
    0 \leq z^r_{j, \tau}, \quad
    \forall j \in J^R_i, \tau \in B(t)
```

### Battery Unit bounds

```math
    -G^B_j \cdot d(\tau) \leq g^B_{j, \tau} \leq G^B_j \cdot d(\tau), \quad
    \underline{s}^B_j \leq s^B_{j, \tau} \leq \overline{s}^B_j, \quad
    \forall j \in J^B_i, \tau \in B(t)
```

## Objective Function

```math
    min{
    \sum_{\tau \in B(t)}{(
    - \sum_{n \in N}{\pi_{n, \tau}(\omega) e_{n, \tau}}
    + \sum_{j \in J^T_i}{C^T_j g^T_{j, \tau}}
    + \sum_{j \in J^R_i}{C^R_j z^r_{j, \tau}}
    )}
    }
```

