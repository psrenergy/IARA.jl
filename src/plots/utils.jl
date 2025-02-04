function get_offer_file_paths(inputs::AbstractInputs)
    offer_files = String[]
    if is_market_clearing(inputs) && any_elements(inputs, BiddingGroup)
        if read_bids_from_file(inputs)
            push!(offer_files, joinpath(path_case(inputs), bidding_group_quantity_offer_file(inputs) * ".csv"))
            push!(offer_files, joinpath(path_case(inputs), bidding_group_price_offer_file(inputs) * ".csv"))
        elseif generate_heuristic_bids_for_clearing(inputs)
            push!(offer_files, joinpath(output_path(inputs), "bidding_group_energy_offer_period_$(inputs.args.period).csv"))
            push!(offer_files, joinpath(output_path(inputs), "bidding_group_price_offer_period_$(inputs.args.period).csv"))
        end
    end

    @assert all(isfile.(offer_files)) "Offer files not found: $(offer_files)"

    return offer_files
end
