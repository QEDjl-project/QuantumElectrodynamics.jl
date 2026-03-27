"""
    get_output_variables()::Dict{String, String}

# Returns

A Dict containing environment variables without value. During script runtime, the values needs to be
set. Otherwise the script will exit with an error.
"""
function get_output_variables()::Dict{String, String}
    required_output_variables = [
        "CI_QED_TARGET_BRANCH",
        "CI_QED_IS_PR",
        "CI_QED_COMMIT_HASH",
    ]

    output_env_vars = Dict{String, String}()
    for var_name in required_output_variables
        output_env_vars[var_name] = ""
    end
    return output_env_vars
end

"""
    check_output_variables(output_variables::Dict{String, String})::Bool

Checks if one of the environment variables has an empty value.

# Args
- `output_variables::Dict{String, String}`: Dict with environment variables

# Return

Return `true`, if no value is empty.
"""
function check_output_variables(output_variables::Dict{String, String})::Bool
    non_empty_var = true
    for (name, value) in output_variables
        if value == ""
            @error "Internal error: output variable $(name) is empty"
            global non_empty_var
            non_empty_var = false
        end
    end
    return non_empty_var
end
