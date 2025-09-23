function post_processing_minimum_outflow_violation(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions;
    physical_variables_suffix::String,
)
    outputs_dir = output_path(inputs)
    output_name = "hydro_minimum_outflow_violation" * physical_variables_suffix
    # This is a post processing of physical variables only, so it follows the physical variables suffix

    hydro_turbining_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(outputs_dir, "hydro_turbining" * physical_variables_suffix),
    )

    hydro_spillage_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(outputs_dir, "hydro_spillage" * physical_variables_suffix),
    )

    consider_subscenario = has_subscenario(hydro_turbining_reader)

    hydro_units_with_minimum_outflow =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [has_min_outflow])

    dimensions =
        consider_subscenario ? ["period", "scenario", "subscenario", "subperiod"] : ["period", "scenario", "subperiod"]
    initialize!(
        QuiverOutput,
        outputs_post_processing;
        inputs,
        output_name = output_name,
        dimensions = dimensions,
        unit = "hm3",
        labels = inputs.collections.hydro_unit.label[hydro_units_with_minimum_outflow],
        run_time_options,
        dir_path = post_processing_path(inputs),
    )

    writer = outputs_post_processing.outputs[output_name].writer

    num_periods = is_single_period(inputs) ? 1 : number_of_periods(inputs)
    for period in 1:num_periods
        for scenario in scenarios(inputs)
            for subscenario in subscenarios(inputs, run_time_options)
                for subperiod in subperiods(inputs)
                    if consider_subscenario
                        Quiver.goto!(
                            hydro_turbining_reader;
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                        )
                        Quiver.goto!(
                            hydro_spillage_reader;
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                        )
                    else
                        Quiver.goto!(hydro_turbining_reader; period, scenario, subperiod = subperiod)
                        Quiver.goto!(hydro_spillage_reader; period, scenario, subperiod = subperiod)
                    end

                    outflow = hydro_turbining_reader.data + hydro_spillage_reader.data
                    hydro_units_minimum_outflow_violation = zeros(length(hydro_units_with_minimum_outflow))

                    for (i, h) in enumerate(hydro_units_with_minimum_outflow)
                        minimum_outflow = hydro_unit_min_outflow(inputs, h)
                        minimum_outflow_violation =
                            (minimum_outflow - outflow[h]) * m3_per_second_to_hm3_per_hour() *
                            subperiod_duration_in_hours(inputs, subperiod)
                        hydro_units_minimum_outflow_violation[i] = minimum_outflow_violation
                    end

                    if consider_subscenario
                        Quiver.write!(
                            writer,
                            round_output(hydro_units_minimum_outflow_violation);
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                        )
                    else
                        Quiver.write!(
                            writer,
                            round_output(hydro_units_minimum_outflow_violation);
                            period,
                            scenario,
                            subperiod = subperiod,
                        )
                    end
                end
            end
        end
    end

    Quiver.close!(writer)
    Quiver.close!(hydro_turbining_reader)
    Quiver.close!(hydro_spillage_reader)

    return nothing
end
