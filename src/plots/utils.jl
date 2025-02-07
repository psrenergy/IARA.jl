function get_offer_file_paths(inputs::AbstractInputs)
    offer_files = String[]
    if is_market_clearing(inputs) && any_elements(inputs, BiddingGroup)
        if read_bids_from_file(inputs)
            push!(offer_files, joinpath(path_case(inputs), bidding_group_quantity_offer_file(inputs) * ".csv"))
            push!(offer_files, joinpath(path_case(inputs), bidding_group_price_offer_file(inputs) * ".csv"))
        elseif generate_heuristic_bids_for_clearing(inputs)
            push!(
                offer_files,
                joinpath(output_path(inputs), "bidding_group_energy_offer_period_$(inputs.args.period).csv"),
            )
            push!(
                offer_files,
                joinpath(output_path(inputs), "bidding_group_price_offer_period_$(inputs.args.period).csv"),
            )
        end
    end

    @assert all(isfile.(offer_files)) "Offer files not found: $(offer_files)"

    return offer_files
end

function plot_title_from_filename(inputs::AbstractInputs, filename::String)
    title = replace(filename, "_period_$(inputs.args.period)" => "")
    title = _snake_to_regular(title)
    title = replace(title, "Ex Post" => "Ex-Post")
    title = replace(title, "Ex Ante" => "Ex-Ante")
    return title
end

function get_revenue_file(inputs::AbstractInputs)
    filename = if settlement_type(inputs) == IARA.Configurations_SettlementType.EX_ANTE
        "bidding_group_revenue_ex_ante"
    elseif settlement_type(inputs) == IARA.Configurations_SettlementType.EX_POST
        "bidding_group_revenue_ex_post"
    elseif settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
        "bidding_group_total_revenue"
    elseif settlement_type(inputs) == IARA.Configurations_SettlementType.NONE
        ""
    end
    filename *= ".csv"

    return joinpath(post_processing_path(inputs), filename)
end
