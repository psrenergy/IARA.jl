#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function _get_bus_index(bg_bus_combination::String, bus_labels::Vector{String})
    for (i, bus) in enumerate(bus_labels)
        if occursin(bus, bg_bus_combination)
            return i
        end
    end
    return nothing
end

_check_floor(price::Real, floor::Real) = max(price, floor)
_check_cap(price::Real, cap::Real) = min(price, cap)

function _get_revenue(
    bidding_group_generation::Array{<:Real, 5},
    bidding_group_meta::Quiver.Metadata,
    load_marginal_cost::Array{<:Real, 4},
    load_marginal_cost_meta::Quiver.Metadata,
    spot_price_cap::Union{Nothing, Real},
    spot_price_floor::Union{Nothing, Real},
)
    # used for ex_ante_commercial, ex_ante_physical

    revenue = copy(bidding_group_generation)

    num_bidding_groups, num_bid_segments, num_subperiods, num_scenarios, num_periods = size(revenue)

    for stg in 1:num_periods
        for sce in 1:num_scenarios
            for blk in 1:num_subperiods
                for bs in 1:num_bid_segments
                    for bg in 1:num_bidding_groups
                        bus_i = _get_bus_index(bidding_group_meta.labels[bg], load_marginal_cost_meta.labels)

                        raw_revenue = revenue[bg, bs, blk, sce, stg] * load_marginal_cost[bus_i, blk, sce, stg] * 1000.0 # GWh to MWh
                        raw_revenue =
                            !is_null(spot_price_floor) ? _check_floor(raw_revenue, spot_price_floor) : raw_revenue
                        raw_revenue = !is_null(spot_price_cap) ? _check_cap(raw_revenue, spot_price_cap) : raw_revenue
                        revenue[bg, bs, blk, sce, stg] = raw_revenue
                    end
                end
            end
        end
    end
    return revenue
end

function _get_revenue(
    bidding_group_generation::Array{<:Real, 6},
    bidding_group_meta::Quiver.Metadata,
    load_marginal_cost::Array{<:Real, 5},
    load_marginal_cost_meta::Quiver.Metadata,
    spot_price_cap::Union{Nothing, Real},
    spot_price_floor::Union{Nothing, Real},
)
    # used for ex_post_commercial, ex_post_physical

    revenue = copy(bidding_group_generation)

    num_bidding_groups, num_bid_segments, num_subperiods, num_subscenarios, num_scenarios, num_periods = size(revenue)
    num_buses = size(load_marginal_cost, 1)

    for stg in 1:num_periods
        for sce in 1:num_scenarios
            for sub in 1:num_subscenarios
                for blk in 1:num_subperiods
                    for bs in 1:num_bid_segments
                        for bg in 1:num_bidding_groups
                            bus_i = _get_bus_index(bidding_group_meta.labels[bg], load_marginal_cost_meta.labels)

                            raw_revenue =
                                revenue[bg, bs, blk, sub, sce, stg] * load_marginal_cost[bus_i, blk, sub, sce, stg] *
                                1000.0 # GWh to MWh

                            raw_revenue =
                                !is_null(spot_price_floor) ? _check_floor(raw_revenue, spot_price_floor) : raw_revenue
                            raw_revenue =
                                !is_null(spot_price_cap) ? _check_cap(raw_revenue, spot_price_cap) : raw_revenue
                            revenue[bg, bs, blk, sub, sce, stg] = raw_revenue
                        end
                    end
                end
            end
        end
    end
    return revenue
end

function post_processing_bidding_group_revenue(inputs::Inputs)
    outputs_dir = output_path(inputs)

    spot_price_cap = inputs.collections.configurations.spot_price_cap
    spot_price_floor = inputs.collections.configurations.spot_price_floor

    bidding_group_generation_files = filter(x -> occursin(r"bidding_group_generation_.*\.csv", x), readdir(outputs_dir))

    for file in bidding_group_generation_files
        is_cost_based = occursin(r"_cost_based", file)

        m = match(r"^bidding_group_generation(?:_multihour){0,1}(_ex_[a-z]+_[a-z]+)(?:_cost_based){0,1}\.csv$", file)
        file_type = m[1]

        load_marginal_cost_file = filter(x -> startswith(x, "load_marginal_cost$file_type.csv"), readdir(outputs_dir))
        if isempty(load_marginal_cost_file)
            return
        end

        generation_data, generation_metadata = read_timeseries_file(joinpath(outputs_dir, file))
        load_marginal_cost_data, load_marginal_cost_metadata =
            read_timeseries_file(joinpath(outputs_dir, load_marginal_cost_file[1]))

        revenue = _get_revenue(
            generation_data,
            generation_metadata,
            load_marginal_cost_data,
            load_marginal_cost_metadata,
            spot_price_cap,
            spot_price_floor,
        )

        time_series_path =
            is_cost_based ? "bidding_group_revenue$(file_type)_cost_based" : "bidding_group_revenue$(file_type)"
        write_timeseries_file(
            joinpath(outputs_dir, time_series_path),
            revenue;
            dimensions = String.(generation_metadata.dimensions),
            labels = generation_metadata.labels,
            time_dimension = "period",
            dimension_size = generation_metadata.dimension_size,
            initial_date = generation_metadata.initial_date,
            unit = "\$",
        )
    end
end
