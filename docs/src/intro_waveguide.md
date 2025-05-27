# Introduction: Waveguide

Sometimes, the operator of a system may want to operate a set of Hydro Units following a specific sequence of dispatch decisions. This is where the concept of a "waveguide" comes into play. A waveguide is a structured approach to managing the percentage of water that will be dispatched from each Hydro Unit at each decision step.

From the [Waveguide Convex Combination](market_clearing_problem.md#waveguide-convex-combination) section, we know that the waveguide is defined as a convex combination of the Hydro Units' dispatch decisions. This means that the operator can specify how much water they would like to maintain from each unit at each step.
It is worth noting that the waveguide is not introduced as a hard constraint in the optimization problem. Instead, it is coupled with a penalty term in the [objective function](market_clearing_problem.md#objective-function). This allows the operator to control the dispatch decisions without imposing strict limits, providing flexibility in the optimization process.

## Simple Example

Consider two Hydro Units, $H_1$ and $H_2$, where $H_1$ is located upstream of $H_2$. The operator wants to ensure that the volume contained in $H_1$ is emptied before the volume in $H_2$. The waveguide can be defined as follows:

<center>

| **Plant**   | **$P_1$** | **$P_2$** | **$P_3$** |
|:-----------:|:---------:|:---------:|:---------:|
|  **$H_1$**  |    1.0    |    0.0    |    0.0    |
|  **$H_2$**  |    1.0    |    1.0    |    0.0    |

</center>

In this example we have three waveguide points, $P_1$, $P_2$, and $P_3$. The waveguide ensures that the remaining volumes in $H_1$ and $H_2$ is within the convex combination of the waveguide points $P_i$ and $P_{i+1}$, where $i$ is the index of the waveguide point. 

Thus, after the first decision step, the ratio of the remaining volume in $H_1$ and $H_2$ is given by:

$$
(0,1)\leq \left( \frac{V_{H_1} - V_{H_1}^{min}}{V_{H_1}^{max}} , \frac{V_{H_2} - V_{H_2}^{min}}{V_{H_2}^{max}} \right) \leq (1,1)
$$

