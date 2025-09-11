function nash_bids_from_hydro_reference_curve(inputs::AbstractInputs, period::Int = 1, scenario::Int = 1)

    quantity_bid, price_bid = read_serialized_virtual_reservoir_heuristic_bids(inputs; period, scenario)

    @show period, scenario
    @show quantity_bid
    @show price_bid


    return nothing
end