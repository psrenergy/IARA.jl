# Bid Price Limit

If the bidding group bid validation is enabled, the system will enforce limits on bid prices based on some input parameters. These parameters help ensure that bids are within acceptable ranges and are justified according to the type of bid.

Input parameters for bid price limits include:
- ``P^{ref}_{low}`` and ``P^{ref}_{high}``: These are the reference prices used to calculate the bid price limits. $P^{ref}_{low} < P^{ref}_{high}$.
- ``M^{n}_p``: The maximum markup without justification for profile bids.
- ``M^{n}_i``: The maximum markup without justification for independent bids.
- ``M^{j}_p``: The maximum markup with justification for profile bids.
- ``M^{j}_i``: The maximum markup with justification for independent bids.

## Reference Prices

The reference price for a bidding group is calculated according to the types of units in the group.

### Bidding Group with Thermal Units

For a bidding group that contains thermal units, the reference price is the maximum between the O&M costs of the thermal units and the low reference price parameter: 

```math
P^{ref} = \max(C^T \cup \{P^{ref}_{low}\})
```

### Bidding Group with Renewable Units and no Thermal Units

For a bidding group that contains renewable units and does not contain any thermal units, the reference price is the low reference price parameter:

```math
P^{ref} = P^{ref}_{low}
```

### Bidding Group with no Renewable or Thermal Units
For a bidding group that does not contain any renewable or thermal units, the reference price is the high reference price parameter:

```math
P^{ref} = P^{ref}_{high}
```

## Maximum Markup over Reference Price
The maximum markup over the reference price, with and withot justification, varies based on the type of bid.

### Independent Bids

```math
M^n = M^{n}_i \\
M^j = M^{j}_i
```
### Profile Bids

```math
M^n = M^{n}_p \\
M^j = M^{j}_p
```

## Bid Price Limits


Given the reference price, the maximum markup without justification, and the maximum markup with justification, the price offers are validated as follows:

1. If the bid price is not greater than maximum the markup without justification applied to the reference price ($P \le P^{ref} \cdot (1 + M^n)$) , the bid is considered valid.
2. If the bid price is greater than the maximum markup without justification applied to the reference price, but not greater than the maximum markup with justification applied to the reference price ($ P^{ref} \cdot (1+M^n) \le P \le P^{ref} \cdot (1 + M^j)$), the bid is considered valid if it has a justification.
3. If the bid price is greater than the maximum markup with justification applied to the reference price ($P > P^{ref} \cdot (1 + M^j)$), the bid is automatically considered invalid.
