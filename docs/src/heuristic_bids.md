# From Physical Data to Bid Offers

This document describes the process of transforming physical data from asset owners into bid offers for various unit types, including thermal, renewable, and hydro units. 
Bid offers are calculated using predefined formulas that incorporate operational parameters, risk factors, and specific bidding approaches.


## Asset Owner attributes

- ``I``: Set of assets owners
- ``BG(i)``: Set of Bidding Groups of asset owner $i$
- ``J^T(b)``: Set of thermal units of bidding group $b$.
- ``J^{TC}(b)``: Set of commitment thermal units of bidding group $b$.
- ``J^H(b)``: Set of hydro units of bidding group $b$.
- ``J^{HC}(b)``: Set of commitment hydro units of bidding group $b$.
- ``J^{HR}(b)``: Set of hydro units that operate with a reservoir of bidding group $b$.
- ``J^{HRR}(b)``: Set of hydro units that operate with as run-of-the-river of bidding group $b$.
- ``J^R(b)``: Set of renewable units of bidding group $b$.
- ``J^B(b)``: Set of battery units of bidding group $b$.
- ``R(b)`` Set of risk factors for bidding group $b$.
- ``p_r``: Risk factor.
- ``s_r``: proportion of the risk factor $r$ in the bidding group $b$.

## Thermal Units

The thermal units maximum generation $\overline{G}^T_j$ and om cost $\overline{C}^T_j$ are converted to bid offers by using the following formula:

```math
\begin{align}
Q_{i, n, \tau, k}(\omega) &= s_r \cdot \overline{G}^T_j \cdot d(\tau) &\quad \forall k = (j - 1) \cdot |R(b)| + r, r \in R(b), j \in J^T(b)  \\
P_{i, n, \tau, k}(\omega) &= (1 + p_r) \cdot \overline{C}^T_j &\quad \forall k = (j - 1) \cdot |R(b)| + r, r \in R(b), j \in J^T(b)
\end{align}
```

Note: Other thermal unit attributes are not considered when forming these bid offers.

## Renewable Units

For renewable units, the conversion incorporates the maximum generation $G^R_j$, the realized generation ``G^R_{j, \tau}(\omega)`` and om cost $\overline{C}^R_j$ are converted to bid offers by using the following formula:

```math
\begin{align}
Q_{i, n, \tau, k}(\omega) &= s_r \cdot G^R_{j, \tau}(\omega)\cdot G^R_j \cdot d(\tau) &\quad \forall k = (j - 1) \cdot |R(b)| + r, r \in R(b), j \in J^R(b)  \\
P_{i, n, \tau, k}(\omega) &= (1 + p_r) \cdot \overline{C}^R_j &\quad \forall k = (j - 1) \cdot |R(b)| + r, r \in R(b), j \in J^R(b)
\end{align}
```

## Hydro Units

Hydro unit bid offers are derived from a Minimum Cost Run, where the generation output $g^H_{j, \tau}$ and opportunity cost $\pi^H_{j, \tau}$ are converted into bids. Two approaches are available:

### Indepedent Bids

For hydro units submitting independent bids, the conversion is performed using the following formulas:

```math
\begin{align}
Q_{i, n, \tau, k}(\omega) &= s_r \cdot g^H_{j, \tau}(\omega) \cdot d(\tau) &\quad \forall k = (j - 1) \cdot |R(b)| + r, r \in R(b), j \in J^H(b)  \\
P_{i, n, \tau, k}(\omega) &= (1 + p_r) \cdot \pi^H_{j, \tau} &\quad \forall k = (j - 1) \cdot |R(b)| + r, r \in R(b), j \in J^H(b)
\end{align}
```

### Profile Bids

When using profile bids, it is assumed that the bidding group is subject to a single risk factor. 
Let's consider two sets of bid profiles:
 - ``K^M(j)``: Set of main profiles
 - ``K^C(j)``: Set of child profiles

The main profile captures only the generation and opportunity cost of hydro unit $j$.
The child profile allows the hydro unit to shift energy between different subperiods.

#### Main Profile

The main profile is defined as:

```math
\begin{align}
Q^M_{i, n, \tau, k}(\omega) &= g^H_{j, \tau}(\omega) &\quad \forall k \in  K^M(j), j \in J^H(b)  \\
P^M_{i, n, k}(\omega) &= \frac{1}{ \sum_{\tau \in B(t)} d(\tau)} \sum_{\tau \in B(t)} \pi^H_{j, \tau} d(\tau) &\quad \forall k \in K^M(j), j \in J^H(b)
\end{align}
```

#### Child Profile

The child profile enables hydro unit $j$ to shift energy from one subperiod $\tau_1$ to another $\tau_2$ (i.e., intra-period energy transfers).
Since shift a energy to the same subperiod won't change the main offer, there are $|B(t)| \cdot (|B(t)| - 1)$ possible child profiles.
It is defined as:

```math
\begin{align}
Q^M_{i, n, \tau_1, k}(\omega) &= \min \{ g^H_{j, \tau_2}(\omega), \rho_j U_j  - g^H_{j, \tau_1}(\omega) \} &\quad \forall \tau_1 \neq \tau_2, k \in  K^C(j), \tau_1 \in B(t), \tau_2 \in B(t), j \in J^H(b) \\
P^M_{i, n, k}(\omega) &= 0 &\quad \forall k \in K^C(j), j \in J^H(b)
\end{align}
```

Notes:
- The minimum operator ensures that the energy shifted does not exceed the feasible generation in subperiod $\tau_2$ or beyond its remaining capacity $\rho_j U_j$ in subperiod $\tau_1$.
- The opportunity cost of the child profile is zero, because no additional cost is incurred for transferring energy between subperiods.