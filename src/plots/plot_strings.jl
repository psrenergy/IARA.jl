function fill_plot_strings_dict!(inputs::AbstractInputs)
    complete_dict = Dict(
        "period" => Dict(
            "en" => "Period",
            "pt" => "Período",
        ),
        "scenario" => Dict(
            "en" => "Scenario",
            "pt" => "Cenário",
        ),
        "subperiod" => Dict(
            "en" => "Subperiod",
            "pt" => "Subperíodo",
        ),
        "subscenario" => Dict(
            "en" => "Subscenario",
            "pt" => "Subcenário",
        ),
        "demand" => Dict(
            "en" => "Demand",
            "pt" => "Demanda",
        ),
        "total_demand" => Dict(
            "en" => "Total Demand",
            "pt" => "Demanda Total",
        ),
        "net_demand" => Dict(
            "en" => "Net Demand",
            "pt" => "Demanda Líquida",
        ),
        "maximum_demand" => Dict(
            "en" => "Maximum Demand",
            "pt" => "Demanda Máxima",
        ),
        "maximum_total_demand" => Dict(
            "en" => "Maximum Total Demand",
            "pt" => "Demanda Total Máxima",
        ),
        "maximum_net_demand" => Dict(
            "en" => "Maximum Net Demand",
            "pt" => "Demanda Líquida Máxima",
        ),
        "minimum_demand" => Dict(
            "en" => "Minimum Demand",
            "pt" => "Demanda Mínima",
        ),
        "minimum_total_demand" => Dict(
            "en" => "Minimum Total Demand",
            "pt" => "Demanda Total Mínima",
        ),
        "minimum_net_demand" => Dict(
            "en" => "Minimum Net Demand",
            "pt" => "Demanda Líquida Mínima",
        ),
        "average_demand" => Dict(
            "en" => "Average Demand",
            "pt" => "Demanda Média",
        ),
        "average_total_demand" => Dict(
            "en" => "Average Total Demand",
            "pt" => "Demanda Total Média",
        ),
        "average_net_demand" => Dict(
            "en" => "Average Net Demand",
            "pt" => "Demanda Líquida Média",
        ),
        "renewable_generation" => Dict(
            "en" => "Renewable Generation",
            "pt" => "Geração Renovável",
        ),
        "maximum_renewable_generation" => Dict(
            "en" => "Maximum Renewable Generation",
            "pt" => "Geração Renovável Máxima",
        ),
        "minimum_renewable_generation" => Dict(
            "en" => "Minimum Renewable Generation",
            "pt" => "Geração Renovável Mínima",
        ),
        "average_renewable_generation" => Dict(
            "en" => "Average Renewable Generation",
            "pt" => "Geração Renovável Média",
        ),
        "total_profit" => Dict(
            "en" => "Total Profit",
            "pt" => "Lucro Total",
        ),
        "total_revenue" => Dict(
            "en" => "Total Revenue",
            "pt" => "Receita Total",
        ),
        "ex_ante_revenue" => Dict(
            "en" => "Ex-ante Revenue",
            "pt" => "Receita Ex-ante",
        ),
        "ex_post_revenue" => Dict(
            "en" => "Ex-post Revenue",
            "pt" => "Receita Ex-post",
        ),
        "total_generation" => Dict(
            "en" => "Total Generation",
            "pt" => "Geração Total",
        ),
        "ex_ante_generation" => Dict(
            "en" => "Ex-ante Generation",
            "pt" => "Geração Ex-ante",
        ),
        "ex_post_generation" => Dict(
            "en" => "Ex-post Generation",
            "pt" => "Geração Ex-post",
        ),
        "spot_price" => Dict(
            "en" => "Spot Price",
            "pt" => "Preço Spot",
        ),
        "ex_ante_spot_price" => Dict(
            "en" => "Ex-ante Spot Price",
            "pt" => "Preço Spot Ex-ante",
        ),
        "ex_post_spot_price" => Dict(
            "en" => "Ex-post Spot Price",
            "pt" => "Preço Spot Ex-post",
        ),
        "generation_by_technology" => Dict(
            "en" => "Generation by Technology",
            "pt" => "Geração por Tecnologia",
        ),
        "deficit" => Dict(
            "en" => "Deficit",
            "pt" => "Déficit",
        ),
        "available_offers" => Dict(
            "en" => "Available Offers",
            "pt" => "Ofertas Disponíveis",
        ),
        "offers" => Dict(
            "en" => "Offers",
            "pt" => "Ofertas",
        ),
        "operating_cost" => Dict(
            "en" => "Operating Cost",
            "pt" => "Custo Variável Unitário",
        ),
        "quantity" => Dict(
            "en" => "Quantity",
            "pt" => "Quantidade",
        ),
        "price" => Dict(
            "en" => "Price",
            "pt" => "Preço",
        ),
    )

    for (key, value) in complete_dict
        inputs.collections.configurations.plot_strings_dict[key] = value[language(inputs)]
    end

    return nothing
end

function get_name(inputs::AbstractInputs, key::String)
    return inputs.collections.configurations.plot_strings_dict[key]
end
