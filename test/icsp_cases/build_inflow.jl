using Statistics, Random, Distributions
include("./inflow_history.jl")

function build_iid_inflow(
    case_path::String;
    number_of_subperiods::Int = 24,
    number_of_samples::Int = 100,
    number_of_seasons::Int = 12,
    subperiod_duration_in_hours::Float64 = 30.0,
    expected_number_of_repeats::Float64 = 1.0,
)
    Random.seed!(1234)

    @assert number_of_seasons * number_of_subperiods * subperiod_duration_in_hours * expected_number_of_repeats == 8640 "Cycle duration does not match the expected value"
    
    # Dimension adjustments
    std_dev_adjustment = sqrt(expected_number_of_repeats) # sqrt(beta)

    # Inflow history dimensions:
    number_of_hydro_units = 4
    number_of_months_per_year = 12
    number_of_years = 82
    month_duration_in_hours = 30 * 24  # Assuming each month has 30 days

    # Get inflow statistics
    reshaped_inflow_history = Array{Float64, 3}(undef, number_of_hydro_units, number_of_months_per_year, number_of_years)
    for hydro in 1:number_of_hydro_units, month in 1:number_of_months_per_year, year in 1:number_of_years
        reshaped_inflow_history[hydro, month, year] = inflow_history[hydro][month][year] / month_duration_in_hours
        # (inflow_history [MWh]) / (month_duration_in_hours - 720 - [hours/month]) / (production_factor - 1 - [MW/m3/s]) = ([m3/s])
    end

    inflow_log_monthly_average = reshaped_inflow_history .|> log |> (x -> mean(x, dims=3)) |> (x -> dropdims(x; dims = 3))
    inflow_log_monthly_std_dev = reshaped_inflow_history .|> log |> (x -> std(x, dims=3)) |> (x -> dropdims(x; dims = 3))

    # Adjust log-normal distribution parameters so that the standard deviation is multiplied by std_dev_adjustment
    adjusted_sigma = sqrt.(log.(std_dev_adjustment^2 .* (exp.(inflow_log_monthly_std_dev.^2) .- 1) .+ 1))
    adjusted_mu = inflow_log_monthly_average .+ 0.5 .* (inflow_log_monthly_std_dev.^2 .- adjusted_sigma.^2)

    # Adjust log-normal parameters for the new number of seasons
    adjusted_mu, adjusted_sigma = concatenate_lognormal_params(adjusted_mu, adjusted_sigma, number_of_seasons, number_of_hydro_units)

    # Build default IID inflow scenarios (12 seasons, subperiod_duration_in_hours  = 30)
    iid_inflow = Array{Float64, 4}(undef, number_of_hydro_units, number_of_subperiods, number_of_samples, number_of_seasons)
    for hydro in 1:number_of_hydro_units, season in 1:number_of_seasons
        distrib = LogNormal(adjusted_mu[hydro, season], adjusted_sigma[hydro, season])
        for subperiod in 1:number_of_subperiods, sample in 1:number_of_samples
            iid_inflow[hydro, subperiod, sample, season] = rand(distrib)
        end
    end

    return iid_inflow
end

function concatenate_lognormal_params(original_mu::Array{Float64, 2}, original_sigma::Array{Float64, 2}, number_of_seasons::Int, number_of_hydros::Int)

    number_of_months_per_season = Int(12 / number_of_seasons)

    new_mu = Array{Float64, 2}(undef, number_of_hydros, number_of_seasons)
    new_sigma = Array{Float64, 2}(undef, number_of_hydros, number_of_seasons)

    for hydro in 1:number_of_hydros
        for season in 1:number_of_seasons
            season_idx = ((season - 1) * number_of_months_per_season + 1):(season * number_of_months_per_season)
            mu = original_mu[hydro, season_idx]
            sigma = original_sigma[hydro, season_idx]

            means = [exp(mu[i] + 0.5 * sigma[i]^2) for i in 1:number_of_months_per_season]
            vars  = [(exp(sigma[i]^2) - 1) * exp(2 * mu[i] + sigma[i]^2) for i in 1:number_of_months_per_season]

            # Mean of concatenated dataset
            m = sum(means) / number_of_months_per_season

            # Variance of concatenated dataset
            var_within = sum(vars) / number_of_months_per_season
            var_between = sum((means[i] - m)^2 for i in 1:number_of_months_per_season) / number_of_months_per_season
            s2 = var_within + var_between
            s = sqrt(s2)

            # Log-normal parameters for Z
            new_sigma[hydro, season] = sqrt(log(1 + (s / m)^2))
            new_mu[hydro, season] = log(m) - 0.5 * new_sigma[hydro, season]^2

        end
    end

    return new_mu, new_sigma
end
