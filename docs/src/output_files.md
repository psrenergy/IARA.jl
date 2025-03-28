# **Output files**

Here is a table of all the output files generated by the model related to the variables:

| **Collection**     | **Filename**                 | **Description**                           | **Variable**               | **Unit**   | **Dimensions**                                   |
| -------------- | ------------------------ | ------------------------------------- | ---------------------- | ------ | -------------------------------------------- |
| BatteryUnit    | battery\_generation       | Battery unit generation               | $g^B_{j, \tau}$        | $GWh$  | `period`, `scenario`, `subperiod`            |
| BatteryUnit    | battery\_storage          | Battery unit storage                  |  $s^B_{j, \tau}$       | $GWh$  | `period`, `scenario`, `subperiod`            |
| BatteryUnit    | battery\_om\_costs         | Battery total O&M costs               |                        | ``\$``     | `period`, `scenario`, `subperiod`            |
| BiddingGroup   | bidding\_group\_generation | Bidding group generation              | $q_{i, n, \tau, k}$    | $GWh$ | `period`, `scenario`, `subperiod`, `bid_segment` |
| BiddingGroup   | bidding\_group\_generation\_profile | Bidding group generation profile | $q^M_{i, n, \tau, k}$    | $GWh$ | `period`, `scenario`, `subperiod`, `profile` |
| Branch         | branch\_flow              | Branch flow                           | $f_{j, \tau}$          | $MW$     | `period`, `scenario`, `subperiod`            |
| Bus            | bus\_voltage\_angle        | Bus voltage angle                     | $\theta_{n, \tau}$ | $rad$  | `period`, `scenario`, `subperiod`            |
| DCLine         | dc\_flow                  | DC flow                               | $f_{j, \tau}$  | $MW$     | `period`, `scenario`, `subperiod`            |
| DemandUnit     | demand                   | Demand                                | $D_{j, \tau}(\omega)$    | $GWh$  | `period`, `scenario`, `subperiod`            |
| DemandUnit     | attended\_elastic\_demand  | Attended elastic demand               | $d^E_{j, \tau}$  | $GWh$  | `period`, `scenario`, `subperiod`            |
| DemandUnit     | attended\_flexible\_demand | Attended flexible demand              | $d^F_{j, \tau}$  | $GWh$  | `period`, `scenario`, `subperiod`            |
| DemandUnit     | demand\_curtailment       | Demand curtailment                    | $\delta^F_{j, \tau}$  | $GWh$  | `period`, `scenario`, `subperiod`            |
| DemandUnit     | deficit                  | Deficit                               | $\delta_{j, \tau}$    | $GWh$  | `period`, `scenario`, `subperiod`            |
| HydroUnit      | hydro\_turbining          | Hydro unit turbinig                   | $u_{j, \tau}$  | $m^3/s$ | `period`, `scenario`, `subperiod`            |
| HydroUnit      | hydro\_generation         | Hydro generation                      | $g^H_{j, \tau}$  | $GWh$  | `period`, `scenario`, `subperiod`            |
| HydroUnit      | hydro\_initial\_volume     | Hydro initial volume                  | $v^{S_{in}}_j$  | $hm^3$ | `period`, `scenario`, `subperiod`            |
| HydroUnit      | hydro\_final\_volume       | Hydro final volume                    | $v^{S_{out}}_j$  | $hm^3$ | `period`, `scenario`, `subperiod`            |
| HydroUnit      | hydro\_commitment         | Hydro unit commitment                 | $x^H_{j, \tau}$  | -      | `period`, `scenario`, `subperiod`            |
| HydroUnit      | hydro\_spillage           | Hydro spillage                        | $z_{j, \tau}$  | $m^3/s$ | `period`, `scenario`, `subperiod`            |
| HydroUnit      | hydro\_spillage\_penalty   | Hydro spillage penalty                |                  | ``\$``     | `period`, `scenario`, `subperiod`            |
| HydroUnit      | hydro\_om\_costs           | Hydro O&M costs                       |                  | ``\$``     | `period`, `scenario`, `subperiod`            |
| HydroUnit      | inflow                   | Inflow                                | $a_{j, \tau}$    | $m^3/s$ | `period`, `scenario`, `subperiod`            |
| HydroUnit      | inflow\_slack             | Inflow slack                          | $a^S_{j, \tau}$    | $m^3/s$ | `period`, `scenario`, `subperiod`            |
| HydroUnit      | hydro\_om\_costs           | Hydro O&M costs                       |  | ``\$``     | `period`, `scenario`, `subperiod`            |
| Interconnection| interconnection\_flow     | Interconnection flow                  |    | MW     | `period`, `scenario`, `subperiod`            |
| RenewableUnit  | renewable\_generation     | Renewable generation                  | $g^R_{j, \tau}$  | $GWh$  | `period`, `scenario`, `subperiod`            |
| RenewableUnit  | renewable\_curtailment    | Renewable curtailment                 | $z^r_{j, \tau}$  | $GWh$  | `period`, `scenario`, `subperiod`            |
| RenewableUnit  | renewable\_om\_costs       | Renewable O&M costs                   |  | ``\$``     | `period`, `scenario`, `subperiod`            |
| RenewableUnit  | renewable\_curtailment\_costs| Renewable curtailment costs          |  | ``\$``     | `period`, `scenario`, `subperiod`            |
| ThermalUnit    | thermal\_generation       | Thermal generation                    | $g^T_{j, \tau}$  | $GWh$  | `period`, `scenario`, `subperiod`            |
| ThermalUnit    | thermal\_om\_costs         | Thermal O&M costs                     |   |      | `period`, `scenario`, `subperiod`            |
| ThermalUnit    | thermal\_commitment       | Thermal unit commitment               | $x^T_{j, \tau}$  | -      | `period`, `scenario`, `subperiod`            |
| VirtualReservoir| virtual\_reservoir\_generation| Virtual reservoir generation         | $q^{VR}_{r, i, k}$| $GWh$  | `period`, `scenario`, `bid_segment`          |

Here is a table of all the output files generated by the model related to the constraints:

| Collection     | Output Name                         | Description                          | Unit   | Dimensions                                   |
| -------------- | ----------------------------------- | ------------------------------------ | ------ | -------------------------------------------- |
| HydroUnit      | hydro\_opportunity\_cost              | Hydro opportunity cost               | ``\$/MWh`` | `period`, `scenario`, `subperiod`            |
| Load           | load\_marginal\_cost                  | Load marginal cost                   | ``\$/MWh`` | `period`, `scenario`, `subperiod`            |

Here is a table of all the output files generated by the model related to the heuristic bids:

| **Collection**     | **Output Name**                                   | **Description**                                     | **Parameter**                      | **Unit**   | **Dimensions**                                      |
| -------------- | --------------------------------------------- | ----------------------------------------------- | ------------------------------ | ------ | ----------------------------------------------- |
| BiddingGroup   | bidding\_group\_energy\_offer                    | Bidding group quantity offer                    | $Q_{i, n, \tau, k}(\omega)$        | $GWh$    | `period`, `scenario`, `subperiod`, `bid_segment`  |
| BiddingGroup   | bidding\_group\_price\_offer                     | Bidding group price offer                       | $P_{i, n, \tau, k}(\omega)$        | ``\$/MWh`` | `period`, `scenario`, `subperiod`, `bid_segment`  |
| BiddingGroup   | bidding\_group\_no\_markup\_price\_offer           | Bidding group price offer without markup on agents |         | ``\$/MWh`` | `period`, `scenario`, `subperiod`, `bid_segment`  |
| VirtualReservoir| virtual\_reservoir\_energy\_offer                 | Virtual reservoir energy offer                  | $Q^{VR}_{r, i, k}(\omega)$  | $GWh$   | `period`, `scenario`, `bid_segment`             |
| VirtualReservoir| virtual\_reservoir\_price\_offer                  | Virtual reservoir price offer                   | $P^{VR}_{r, i, k}(\omega)$       | ``\$/MWh`` | `period`, `scenario`, `bid_segment`             |