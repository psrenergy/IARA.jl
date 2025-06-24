# Bid Price Limit

If the bid data source is set to read from a file, and the bidding group bid validation is enabled, the system will enforce limits on bid prices based on some input parameters. These parameters help ensure that bids are within acceptable ranges and are justified according to the type of bid.

The parameters ``bid_price_limit_low_reference`` and ``bid_price_limit_high_reference`` are used to define the base reference prices used to calculate the price limits. The parameters ``bid_price_limit_markup_non_justified_profile``, ``bid_price_limit_markup_justified_profile``, ``bid_price_limit_markup_non_justified_independent``, and ``bid_price_limit_markup_justified_independent`` define the maximum allowed markup over the reference price for different types of bids.

Given the reference price, the maximum markup without justification, and the maximum markup with justification, the price offers are validated as follows:

1. If the bid price is less than or equal to the reference price multiplied by the maximum markup without justification, the bid is considered valid.
2. If the bid price is greater than the reference price multiplied by the maximum markup without justification, but less than or equal to the reference price multiplied by the maximum markup with justification, the bid is considered valid if it has a justification. <!-- Dizer aqui como que justifica? pop-up no market game, json no julia?  -->
3. If the bid price is greater than the reference price multiplied by the maximum markup with justification, the bid is automatically considered invalid.

## Reference Prices

The reference price for a bidding group is calculated according to the types of units in the group.

### Bidding Group with Thermal Units

For a bidding group that contains thermal units, the reference price is the maximum between the O&M costs of the thermal units and the ``bid_price_limit_low_reference`` parameter. 

### Bidding Group with Renewable Units and no Thermal Units

For a bidding group that contains renewable units and does not contain any thermal units, the reference price is the ``bid_price_limit_low_reference`` parameter.

### Bidding Group with no Renewable or Thermal Units
For a bidding group that does not contain any renewable or thermal units, the reference price is the ``bid_price_limit_high_reference`` parameter.

## Maximum Markup over Reference Price
The maximum markup over the reference price varies based on the type of bid and whether there is justification for the bid.

- ``bid_price_limit_markup_non_justified_independent``: the maximum markup without justification for independent bids.
- ``bid_price_limit_markup_justified_independent``: the maximum markup with justification for independent bids.
- ``bid_price_limit_markup_non_justified_profile``: the maximum markup without justification for profile bids.
- ``bid_price_limit_markup_justified_profile``: the maximum markup with justification for profile bids. 

