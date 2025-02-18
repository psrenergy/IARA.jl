# **Input files**

Here is a table of the model attributes that need a external file:

| **Collection** | **Atribute** | **Description** | **Parameter** | **Unit** | **Dimensions** |
|----------------|--------------|-----------------|-------------- |----------|----------------|
| BiddingGroup | quantity\_offer_file | Quantity of offers for independent segement bids | $Q_{i, n, \tau, k}(\omega)$ | $GWh$ | `period`, `scenario`, `subperiod`, `bid_segment` |
| BiddingGroup | price\_offer\_file | Price of offers for independent segement bids | $P_{i, n, \tau, k}(\omega)$ | ``\$/MWh`` | `period`, `scenario`, `subperiod`, `bid_segment` |
| BiddingGroup | quantity\_offer\_profile_file | Quantity of offers for profile bids | $Q^M_{i, n, \tau, k}(\omega)$ | $GWh$ | `period`, `scenario`, `subperiod`, `profile` |
| BiddingGroup | price\_offer\_profile\_file | Price of offers for profile bids | $P^M_{i, n, k}(\omega)$ | ``\$/MWh`` | `period`, `scenario`, `profile` |
| BiddingGroup | parent\_profile\_file | Parent profile of profile $k$ | $\mathcal{p}(k)$ |  | `period`, `profile` |
| BiddingGroup | minimum\_activation\_level\_file | Minimum activation level of profile $k$ | $X_{i, k}(\omega)$ |  | `period`, `scenario`, `profile` |
| BiddingGroup | complementary\_grouping\_file | Complementary grouping $m$ for the asset owner $i$ | $\mathcal{K}_m(i)$ |  | `period`, `profile`, `complementary_group` |
| Configuration | hour\_subperiod\_map\_file | Mapping of hours to subperiods | $d(\tau)$ |  | `period`, `hour` |
| Configuration | fcf\_cuts\_file | FCF cuts for the model, it's a file read from SDDP.jl in JSON format | | | |
| DemandUnit | demand\_ex\_ante\_file | Demand data for the model in ex-ante, also used in the min cost module | $D_{j, \tau}(\omega)$ | $p.u.$ | `period`, `scenario`, `subperiod` |
| DemandUnit | demand\_ex\_post\_file | Demand data for the model in ex-post | $D_{j, \tau}(\omega)$ | $p.u.$ | `period`, `scenario`, `subscenario`, `subperiod` |
| DemandUnit | elastic\_demand\_price\_file | Elastic demand price data | $P_{j, \tau}(\omega)$ | ``\$/MWh`` | `period`, `scenario`, `subperiod` |
| DemandUnit | window\_file | Window of demand | $W_{j, \tau}(\omega)$ | $h$ | `period`, `scenario`, `subperiod` |
| HydroUnit | inflow\_ex\_ante\_file | Inflow data for the model in ex-ante, also used in the min cost module | $a_{j, \tau}$ | $hm^3$ | `period`, `scenario`, `subperiod` |
| HydroUnit | inflow\_ex\_post\_file | Inflow data for the model in ex-post | $a_{j, \tau}$ | $hm^3$ | `period`, `scenario`, `subscenario`, `subperiod` |
| RenewableUnit | generation\_ex\_ante\_file | Realized generation for the model in ex-ante, also used in the min cost module | $G^R_{j, \tau}(\omega)$ | $p.u.$ | `period`, `scenario`, `subperiod` |
| RenewableUnit | generation\_ex\_post\_file | Realized generation for the model in ex-post | $G^R_{j, \tau}(\omega)$ | $p.u.$ | `period`, `scenario`, `subscenario`, `subperiod` |
| VirtualReservoir | quantity\_offer\_file | Quantity of offers for virtual reservoirs | $Q^{VR}_{r, i, k}(\omega)$ | $GWh$ | `period`, `scenario`, `bid_segment` |
| VirtualReservoir | price\_offer\_file | Price of offers for virtual reservoirs | $P^{VR}_{r, i, k}(\omega)$ | ``\$/MWh`` | `period`, `scenario`, `bid_segment` |

