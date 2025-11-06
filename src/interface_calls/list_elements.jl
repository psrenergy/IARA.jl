#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function write_elements_to_json(inputs::IARA.AbstractInputs)
    file_path = joinpath(IARA.output_path(inputs), "iara_elements.json")

    # List case configurations
    configurations_list = list_case_configurations(inputs)

    # List all asset owners and their bidding groups
    asset_onwer_list = list_asset_owners_and_their_bidding_groups(inputs)

    # List the bidding groups and the list of assets in each one.
    bidding_groups_list = list_bidding_groups_and_their_assets(inputs)

    # List virtual reservoirs and the assets in each one
    virtual_reservoirs_list = list_virtual_reservoirs(inputs)

    # List buses
    buses_list = list_buses(inputs)

    # List assets and minimal characteristics (maximum and minimum generation, etc.)
    assets_list = list_assets(inputs)

    data = Dict(
        "configurations" => configurations_list,
        "asset_owners" => asset_onwer_list,
        "bidding_groups" => bidding_groups_list,
        "virtual_reservoirs" => virtual_reservoirs_list,
        "assets" => assets_list,
        "buses" => buses_list,
    )
    @info("Writing case elements to file $(abspath(file_path))")
    io = open(file_path, "w")
    JSON.print(io, data, 4)
    close(io)
    return nothing
end

function list_case_configurations(inputs::IARA.AbstractInputs)
    return Dict(
        "number_of_periods" => IARA.number_of_periods(inputs),
        "number_of_scenarios" => IARA.number_of_scenarios(inputs),
        "number_of_subperiods" => IARA.number_of_subperiods(inputs),
        "initial_date_time" => replace(string(IARA.initial_date_time(inputs)), "T" => " "),
        "period_type" => IARA.period_type_string(IARA.time_series_step(inputs)),
        "price_bid_file" => IARA.bidding_group_price_bid_file(inputs),
        "quantity_bid_file" => IARA.bidding_group_quantity_bid_file(inputs),
        "demand_deficit_cost" => IARA.demand_deficit_cost(inputs),
    )
end

function list_asset_owners_and_their_bidding_groups(inputs::IARA.AbstractInputs)
    asset_onwer_list = []
    for (asset_onwer_index, asset_onwer_label) in enumerate(IARA.asset_owner_label(inputs))
        bidding_group_indexes = IARA.bidding_group_asset_owner_index(inputs) .== asset_onwer_index
        is_supply_security_agent =
            asset_owner_price_type(inputs, asset_onwer_index) == AssetOwner_PriceType.SupplySecurityAgent
        asset_owner_dict = Dict(
            "label" => asset_onwer_label,
            "bidding_groups" => IARA.bidding_group_label(inputs)[bidding_group_indexes],
            "is_supply_security_agent" => is_supply_security_agent,
        )
        push!(asset_onwer_list, asset_owner_dict)
    end
    return asset_onwer_list
end

function list_bidding_groups_and_their_assets(inputs::IARA.AbstractInputs)
    bidding_groups_list = []
    for (bidding_group_index, bidding_group_label) in enumerate(IARA.bidding_group_label(inputs))
        assets_of_bidding_group = String[]
        for (hydro_unit_index, hydro_unit_label) in enumerate(IARA.hydro_unit_label(inputs))
            if IARA.hydro_unit_bidding_group_index(inputs)[hydro_unit_index] == bidding_group_index
                push!(assets_of_bidding_group, hydro_unit_label)
            end
        end
        for (thermal_unit_index, thermal_unit_label) in enumerate(IARA.thermal_unit_label(inputs))
            if IARA.thermal_unit_bidding_group_index(inputs)[thermal_unit_index] == bidding_group_index
                push!(assets_of_bidding_group, thermal_unit_label)
            end
        end
        for (renewable_unit_index, renewable_unit_label) in enumerate(IARA.renewable_unit_label(inputs))
            if IARA.renewable_unit_bidding_group_index(inputs)[renewable_unit_index] == bidding_group_index
                push!(assets_of_bidding_group, renewable_unit_label)
            end
        end
        bidding_group_dict = Dict(
            "label" => bidding_group_label,
            "assets" => assets_of_bidding_group,
        )
        push!(bidding_groups_list, bidding_group_dict)
    end
    return bidding_groups_list
end

function list_virtual_reservoirs(inputs::IARA.AbstractInputs)
    virtual_reservoirs_list = []
    for (virtual_reservoir_index, virtual_reservoir_label) in enumerate(IARA.virtual_reservoir_label(inputs))
        list_of_hydros = String[]
        list_of_asset_owners = String[]
        for (hydro_unit_index, hydro_unit_label) in enumerate(IARA.hydro_unit_label(inputs))
            if hydro_unit_index in IARA.virtual_reservoir_hydro_unit_indices(inputs)[virtual_reservoir_index]
                push!(list_of_hydros, hydro_unit_label)
            end
        end
        for (asset_owner_index, asset_owner_label) in enumerate(IARA.asset_owner_label(inputs))
            if asset_owner_index in IARA.virtual_reservoir_asset_owner_indices(inputs)[virtual_reservoir_index]
                push!(list_of_asset_owners, asset_owner_label)
            end
        end
        virtual_reservoir_dict = Dict(
            "label" => virtual_reservoir_label,
            "hydro_units" => list_of_hydros,
            "asset_owners" => list_of_asset_owners,
        )
        push!(virtual_reservoirs_list, virtual_reservoir_dict)
    end
    return virtual_reservoirs_list
end

function list_assets(inputs::IARA.AbstractInputs)
    assets_list = []
    for (hydro_unit_index, hydro_unit_label) in enumerate(IARA.hydro_unit_label(inputs))
        asset_dict = Dict(
            "label" => hydro_unit_label,
            "type" => "hydro",
            "min_generation" => IARA.hydro_unit_min_generation(inputs)[hydro_unit_index],
            "max_generation" => IARA.hydro_unit_max_generation(inputs)[hydro_unit_index],
            "om_cost" => IARA.hydro_unit_om_cost(inputs)[hydro_unit_index],
        )
        push!(assets_list, asset_dict)
    end
    for (thermal_unit_index, thermal_unit_label) in enumerate(IARA.thermal_unit_label(inputs))
        asset_dict = Dict(
            "label" => thermal_unit_label,
            "type" => "thermal",
            "min_generation" => IARA.thermal_unit_min_generation(inputs)[thermal_unit_index],
            "max_generation" => IARA.thermal_unit_max_generation(inputs)[thermal_unit_index],
            "om_cost" => IARA.thermal_unit_om_cost(inputs)[thermal_unit_index],
        )
        push!(assets_list, asset_dict)
    end
    for (renewable_unit_index, renewable_unit_label) in enumerate(IARA.renewable_unit_label(inputs))
        asset_dict = Dict(
            "label" => renewable_unit_label,
            "type" => "renewable",
            "max_generation" => IARA.renewable_unit_max_generation(inputs)[renewable_unit_index],
            "om_cost" => IARA.renewable_unit_om_cost(inputs)[renewable_unit_index],
        )
        push!(assets_list, asset_dict)
    end
    return assets_list
end

function list_buses(inputs::IARA.AbstractInputs)
    return IARA.bus_label(inputs)
end
