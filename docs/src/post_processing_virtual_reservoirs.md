# Pre and post processing virtual reservoirs
The virtual reservoir representation at the market clearing problem require some pre calculation at the beginning of the run, as well at the beginning and at the ending of each period. This calculations can use input data and results from optimizing the market clearing subproblem of a previous period, and are utilized to fill and update some parameters used at the subproblem.

## Curveguide points

## Water to energy factors
The parameter $\zeta_{r,h}$ represents the ammount of energy (MWh) that each hm³ of water at the hydro unit $h$ can generate considering the set $J^H_{VR}(r)$ of hydro units at virtual reservoir $r$. It is calculated at the beggining of the run, based on the turbine efficiencies $\rho$ and the topology of the cascade, defined by the turbining relations (to which hydro unit each hydro unit turbine water).

$J^{H_{jus}}_{VR}(r, h) = \{ j \in J^H_{VR}(r) | \exists (j_1, j_2, \dots, j_n), h \in J^H_U(j_1), j_i \in J^H_U(j_{i+1}) \forall i = 1,\dots, n-1, j_n \in J^H_U(j) \}$

## Energy account at beggining of period

## Post processing energy account