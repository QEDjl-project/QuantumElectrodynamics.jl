using CI

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
    for (name, value) in output_env_vars
        if value == ""
            @error "Internal error: output variable $(name) is empty"
            global non_empty_var
            non_empty_var = false
        end
    end
    return non_empty_var
end

"""
    handle_pull_request!(ci_commit_ref_name::AbstractString, output_env_vars::Dict{String, String})

Handle the case, if a pull request is encoded in the `CI_COMMIT_REF_NAME` environment variable.
Write several environment variable values to `output_env_vars`.

# Args
- `ci_commit_ref_name::AbstractString`: Content of the `CI_COMMIT_REF_NAME` environment variable.
- `output_env_vars::Dict{String, String}`: Environment variables for the output.
"""
function handle_pull_request!(ci_commit_ref_name::AbstractString, output_env_vars::Dict{String, String})
    output_env_vars["CI_QED_IS_PR"] = "ON"
    pull_request_info = CI.parse_gitlab_ci_pull_request(ci_commit_ref_name)
    @info "Pull request info:\n$(CI.github_pr_to_string(pull_request_info))"
    pr = CI.pull_github_pull_request(pull_request_info)

    output_env_vars["CI_QED_TARGET_BRANCH"] = pr.base.ref
    return nothing
end

"""
    handle_normal_commit!(ci_commit_ref_name::AbstractString, output_env_vars::Dict{String, String})

Handle the case, if the `CI_COMMIT_REF_NAME` environment variable points to a normal commit.
Write several environment variable values to `output_env_vars`.

# Args
- `ci_commit_ref_name::AbstractString`: Content of the `CI_COMMIT_REF_NAME` environment variable.
- `output_env_vars::Dict{String, String}`: Environment variables for the output.
"""
function handle_normal_commit!(ci_commit_ref_name::AbstractString, output_env_vars::Dict{String, String})
    output_env_vars["CI_QED_IS_PR"] = "OFF"
    @info "Commit is not part of a pull request"

    # If the commit is not a pull request, CI_COMMIT_REF_NAME stores the target branch name
    # Special case: for version tags we use the same rules like for the main branch
    try
        VersionNumber(ci_commit_ref_name)
        output_env_vars["CI_QED_TARGET_BRANCH"] = "main"
    catch
        output_env_vars["CI_QED_TARGET_BRANCH"] = ci_commit_ref_name
    end
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    if !haskey(ENV, "CI_COMMIT_REF_NAME")
        @error "Environment variable CI_COMMIT_REF_NAME is not set."
        exit(1)
    end

    ci_commit_ref_name = ENV["CI_COMMIT_REF_NAME"]
    @info "CI_COMMIT_REF_NAME: $(ci_commit_ref_name)"

    output_env_vars = get_output_variables()

    pull_request = CI.is_pull_request(ci_commit_ref_name)
    if pull_request
        handle_pull_request!(ci_commit_ref_name, output_env_vars)
    else
        handle_normal_commit!(ci_commit_ref_name, output_env_vars)
    end

    if output_env_vars["CI_QED_TARGET_BRANCH"] != "main"
        CI.read_commit_message!(output_env_vars)
    end

    if !check_output_variables(output_env_vars)
        exit(1)
    end

    for (name, value) in output_env_vars
        println("export $(name)=$(value)")
    end

end
