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
        "first_scenario_demand" => Dict(
            "en" => "First Scenario Demand",
            "pt" => "Demanda do Primeiro Cenário",
        ),
        "first_scenario_total_demand" => Dict(
            "en" => "First Scenario Total Demand",
            "pt" => "Demanda Total do Primeiro Cenário",
        ),
        "first_scenario_net_demand" => Dict(
            "en" => "First Scenario Net Demand",
            "pt" => "Demanda Líquida do Primeiro Cenário",
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
        "inflow_energy" => Dict(
            "en" => "Inflow Energy",
            "pt" => "Energia Afluente",
        ),
        "maximum_inflow_energy" => Dict(
            "en" => "Maximum Inflow Energy",
            "pt" => "Energia Afluente Máxima",
        ),
        "minimum_inflow_energy" => Dict(
            "en" => "Minimum Inflow Energy",
            "pt" => "Energia Afluente Mínima",
        ),
        "average_inflow_energy" => Dict(
            "en" => "Average Inflow Energy",
            "pt" => "Energia Afluente Média",
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
            "en" => "Ex-Ante Revenue",
            "pt" => "Receita Ex-Ante",
        ),
        "ex_post_revenue" => Dict(
            "en" => "Ex-Post Revenue",
            "pt" => "Receita Ex-Post",
        ),
        "total_generation" => Dict(
            "en" => "Total Generation",
            "pt" => "Geração Total",
        ),
        "ex_ante_generation" => Dict(
            "en" => "Ex-Ante Generation",
            "pt" => "Geração Ex-Ante",
        ),
        "ex_post_generation" => Dict(
            "en" => "Ex-Post Generation",
            "pt" => "Geração Ex-Post",
        ),
        "spot_price" => Dict(
            "en" => "Spot Price",
            "pt" => "Preço Spot",
        ),
        "ex_ante_spot_price" => Dict(
            "en" => "Ex-Ante Spot Price",
            "pt" => "Preço Spot Ex-Ante",
        ),
        "ex_post_spot_price" => Dict(
            "en" => "Ex-Post Spot Price",
            "pt" => "Preço Spot Ex-Post",
        ),
        "generation_by_technology" => Dict(
            "en" => "Generation by Technology",
            "pt" => "Geração por Tecnologia",
        ),
        "deficit" => Dict(
            "en" => "Deficit",
            "pt" => "Déficit",
        ),
        "available_bids" => Dict(
            "en" => "Available Bids",
            "pt" => "Ofertas Disponíveis",
        ),
        "bids" => Dict(
            "en" => "Bids",
            "pt" => "Ofertas",
        ),
        "sell_bids" => Dict(
            "en" => "Sell Bids",
            "pt" => "Ofertas de Venda",
        ),
        "purchase_bids" => Dict(
            "en" => "Purchase Bids",
            "pt" => "Ofertas de Compra",
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
        "variable_cost" => Dict(
            "en" => "Variable Cost",
            "pt" => "Custo Variável",
        ),
        "fixed_cost" => Dict(
            "en" => "Fixed Cost",
            "pt" => "Custo Fixo",
        ),
        "total_cost" => Dict(
            "en" => "Total Cost",
            "pt" => "Custo Total",
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
