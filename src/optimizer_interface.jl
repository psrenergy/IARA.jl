struct IARAOptimizer
    optimizer::Any
    write_lp_hook::Function
    treat_infeasibilities_hook::Function
end

function _pass_names_to_solver(optimizer; warn::Bool = true)
    _pass_variable_names_to_solver(optimizer; warn = warn)
    _pass_constraint_names_to_solver(optimizer; warn = warn)
    return
end

function _pass_variable_names_to_solver(optimizer; warn::Bool = true)
    max_name_length = 64
    n = length(optimizer.variable_info)
    if n == 0
        return
    end
    names = String["C$i" for i in 1:n]
    duplicate_check = Set{String}()
    for info in values(optimizer.variable_info)
        if isempty(info.name)
            continue
        elseif length(info.name) > max_name_length
            if warn
                @warn(
                    "Skipping variable name because it is longer than " *
                    "$max_name_length characters: $(info.name)",
                )
            end
        elseif info.name in duplicate_check
            if warn
                @warn("Skipping duplicate variable name $(info.name)")
            end
        else
            names[info.column+1] = info.name
            push!(duplicate_check, info.name)
        end
    end
    for (col, name) in enumerate(names)
        HiGHS.Highs_passColName(optimizer.inner, col - 1, name)
    end
    return
end

function _pass_constraint_names_to_solver(optimizer; warn::Bool = true)
    max_name_length = 64
    n = length(optimizer.affine_constraint_info)
    if n == 0
        return
    end
    names = String["R$i" for i in 1:n]
    duplicate_check = Set{String}()
    for info in values(optimizer.affine_constraint_info)
        if isempty(info.name)
            continue
        elseif length(info.name) > max_name_length
            if warn
                @warn(
                    "Skipping constraint name because it is longer than " *
                    "$max_name_length characters: $(info.name)",
                )
            end
        elseif info.name in duplicate_check
            if warn
                @warn("Skipping duplicate constraint name $(info.name)")
            end
        else
            names[info.row+1] = info.name
            push!(duplicate_check, info.name)
        end
    end
    for (row, name) in enumerate(names)
        HiGHS.Highs_passRowName(optimizer.inner, row - 1, name)
    end
    return
end

function default_optimizer()
    optimizer = HiGHS.Optimizer()
    write_lp_hook = function _write_lp_hook(model, lp_filename)
        optimizer = JuMP.backend(model).optimizer.model.optimizer
        # We make this statement because when using ParametricOptInterface the 
        # written might not pass all parameters to the file.
        # Writing directly from the lower leve API will ensure that exactly the 
        # model being solved is written.
        _pass_names_to_solver(optimizer)
        HiGHS.Highs_writeModel(optimizer.inner, lp_filename)
        return nothing
    end
    treat_infeasibilities = function _treat_infeasibilities(model, lp_filename)
        status = JuMP.termination_status(model)
        if status == MOI.INFEASIBLE
            optimizer = JuMP.backend(model).optimizer.model.optimizer

            # We make this statement because when using ParametricOptInterface the 
            # written might not pass all parameters to the file.
            # Writing directly from the lower leve API will ensure that exactly the 
            # model being solved is written.
            _pass_names_to_solver(optimizer)
            HiGHS.Highs_writeModel(optimizer.inner, lp_filename)
        end
        return nothing
    end

    return IARAOptimizer(
        optimizer,
        write_lp_hook,
        treat_infeasibilities,
    )
end
