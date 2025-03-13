# From Physical Data to Bid Offers

This document describes the process of transforming physical data from asset owners into bid offers for various unit types, including thermal, renewable, and hydro units. 
Bid offers are calculated using predefined formulas that incorporate operational parameters, risk factors, and specific bidding approaches.


## Asset Owner attributes

- ``I``: Set of assets owners
- ``BG(i)``: Set of Bidding Groups of asset owner $i$
- ``J^T(b, n)``: Set of thermal units of bidding group $b$ and network node $n$.
- ``J^H(b, n)``: Set of hydro units of bidding group $b$ and network node $n$.
- ``J^R(b, n)``: Set of renewable units of bidding group $b$ and network node $n$.
- ``J^{VR}``: Set of virtual reservoirs.
- ``J^H_{VR}(r)``: Set of hydro units associated with virtual reservoir $r$.
- ``I_{VR}(r)``: Set of asset owners associated with virtual reservoir $r$.
- ``K^{VR}(r, i)``: Set of segment offers at virtual reservoir $r$ for the asset owner $i$.
- ``E^{VR}_{r,i}(\omega)``: Energy stock of asset owner $i$ on virtual reservoir $r$ at scenario $\omega$.
- ``F(b)`` Set of risk factors for bidding group $b$.
- ``F^{AO}(i)`` Set of risk factors for asset owner $i$.
- ``p_f``: Risk factor.
- ``s_f``: proportion of the risk factor $r$ in the bidding group $b$.
- ``e_{r,i}``: participation of asset owner $i$ in virtual reservoir $r$.
- ``B(t)``: Set of subperiods in period $t$.

## Thermal Units

The thermal units maximum generation $\overline{G}^T_j$ and om cost $\overline{C}^T_j$ are converted to bid offers by using the following formula:

```math
\begin{align}
Q_{i, n, \tau, k}(\omega) &= s_f \cdot \overline{G}^T_j \cdot d(\tau) &\quad \forall k = (j - 1) \cdot |F(b)| + f, f \in F(b), j \in J^T(b, n)  \\
P_{i, n, \tau, k}(\omega) &= (1 + p_f) \cdot \overline{C}^T_j &\quad \forall k = (j - 1) \cdot |F(b)| + f, f \in F(b), j \in J^T(b, n)
\end{align}
```

Note: Other thermal unit attributes are not considered when forming these bid offers.

## Renewable Units

For renewable units, the conversion incorporates the maximum generation $G^R_j$, the realized generation ``G^R_{j, \tau}(\omega)`` and om cost $\overline{C}^R_j$ are converted to bid offers by using the following formula:

```math
\begin{align}
Q_{i, n, \tau, k}(\omega) &= s_f \cdot G^R_{j, \tau}(\omega)\cdot G^R_j \cdot d(\tau) &\quad \forall k = (j - 1) \cdot |F(b)| + f, f \in F(b), j \in J^R(b, n)  \\
P_{i, n, \tau, k}(\omega) &= (1 + p_f) \cdot \overline{C}^R_j &\quad \forall k = (j - 1) \cdot |F(b)| + f, f \in F(b), j \in J^R(b, n)
\end{align}
```

## Hydro Units

Hydro unit bid offers are derived from a Minimum Cost Run, where the generation output $g^H_{j, \tau}$ and opportunity cost $\pi^H_{j, \tau}$ are converted into bids. Two approaches are available:

### Indepedent Bids

For hydro units submitting independent bids, the conversion is performed using the following formulas:

```math
\begin{align}
Q_{j, n, \tau, k}(\omega) &= s_f \cdot g^H_{j, \tau}(\omega) &\quad \forall k = (j - 1) \cdot |F(b)| + f, f \in F(b), j \in J^H(b, n)  \\
P_{j, n, \tau, k}(\omega) &= (1 + p_f) \cdot \pi^H_{j, \tau} &\quad \forall k = (j - 1) \cdot |F(b)| + f, f \in F(b), j \in J^H(b, n)
\end{align}
```

### Virtual Reservoirs

For hydro units in a virtual reservoir, the conversion is performed using the following formulas:

```math
\begin{align}
e_{r,i} &= \frac{E^{VR}_{r,i}(\omega)}{\sum_{l \in I_{VR}(r)} E^{VR}_{r,l}(\omega)} &\quad \forall i \in I_{VR}(r), r \in J^{VR}\\
Q^{VR}_{r, i, k}(\omega) &= e_{r,i} \cdot s_f \cdot \sum_{\tau \in B(t)} g^H_{j, \tau}(\omega) &\quad \forall k = (j - 1) \cdot |F^{AO}(i)| + f, f \in F^{AO}(a), j \in J^H_{VR}(r), i \in I_{VR}(r), r \in J^{VR}  \\
P^{VR}_{r, i, k}(\omega) &= (1 + p_f) \cdot  \frac{1}{|B(t)|} \sum_{\tau \in B(t)} \pi^H_{j, \tau} &\quad \forall k = (j - 1) \cdot |F^{AO}(i)| + f, f \in F^{AO}(a), j \in J^H_{VR}(r), i \in I_{VR}(r), r \in J^{VR}  \\
\end{align}
```