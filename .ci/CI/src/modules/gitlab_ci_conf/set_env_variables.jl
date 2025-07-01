using GitHub

# define which environment variables should be set, if tag is found
# it is not allow the set the same environment variable with different values
const known_tags = Dict{String, Vector{Tuple{String, String}}}(
    "doc" => [
        ("CI_QED_ENABLE_CPU_TESTS", "OFF"),
        ("CI_QED_ENABLE_CUDA_TESTS", "OFF"),
        ("CI_QED_ENABLE_AMDGPU_TESTS", "OFF"),
        ("CI_QED_ENABLE_INTEG_TESTS", "OFF"),
    ],
    "no-cpu-test" => [
        ("CI_QED_ENABLE_CPU_TESTS", "OFF"),
    ],
    "no-gpu-test" => [
        ("CI_QED_ENABLE_CUDA_TESTS", "OFF"),
        ("CI_QED_ENABLE_AMDGPU_TESTS", "OFF"),
    ],
    "no-cuda-test" => [
        ("CI_QED_ENABLE_CUDA_TESTS", "OFF"),
    ],
    "no-amdgpu-test" => [
        ("CI_QED_ENABLE_AMDGPU_TESTS", "OFF"),
    ],
    "no-integ-test" => [
        ("CI_QED_ENABLE_INTEG_TESTS", "OFF"),
    ],
    "large-test" => [
        ("CI_QED_LARGE_TESTS", "ON"),
    ],
)

"""
    _set_output_env_vars!(output_env_vars::Dict, name::AbstractString, value::AbstractString)

The function prevents predefined environment variables from being overwritten.
It sets the value of the argument `value` in `output_env_vars` if the environment variable with the
name `name` does not exist. Otherwise, the value of the environment variable is used and set in
`output_env_vars`.

# Args
- `output_env_vars::Dict`: Contains environment variables which should be set.
- `name::AbstractString`: Name of the environment variable.
- `value::AbstractString`: Value of the new defined environment variable.
"""
function _set_output_env_vars!(output_env_vars::Dict, name::AbstractString, value::AbstractString)
    if haskey(ENV, name)
        output_env_vars[name] = ENV[name]
    else
        output_env_vars[name] = value
    end
    return nothing
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
    _set_output_env_vars!(output_env_vars, "CI_QED_IS_PR", "ON")
    pull_request_info = CI.parse_gitlab_ci_pull_request(ci_commit_ref_name)
    @info "Pull request info:\n$(CI.github_pr_to_string(pull_request_info))"
    pr = CI.pull_github_pull_request(pull_request_info)

    _set_output_env_vars!(output_env_vars, "CI_QED_TARGET_BRANCH", pr.base.ref)
    _read_pull_request_labels!(pr, output_env_vars)
    return nothing
end

"""
    _read_pull_request_labels!(pr::GitHub.PullRequest, output_env_vars::Dict{String, String})

Reads the labels from the given pull request. If a label begins with `CI:`, the prefix is removed
and a check is made to see whether it is defined in `known_tags`. If it is defined, the
corresponding environment variables are added to `output_env_vars`.

# Args
- `pr::GitHub.PullRequest`: Pull request object with labels
- `output_env_vars::Dict{String, String}`: Environment variables for the output.

"""
function _read_pull_request_labels!(pr::GitHub.PullRequest, output_env_vars::Dict{String, String})
    global known_tags

    io = IOBuffer()
    for label in pr.labels
        if startswith(label.name, "CI:")
            println(io, label.name)
            tag = strip(label.name[(length("CI:") + 1):end])
            if !haskey(known_tags, tag)
                @warn "Unknown tag: $(tag)"
            else
                for (env_var_name, env_var_value) in known_tags[tag]
                    # do not use _set_output_env_vars!(), as this environment should be variable
                    # overridable
                    output_env_vars[env_var_name] = env_var_value
                end
            end
        end
    end

    msg = String(take!(io))
    if msg != ""
        @info "found CI labels:\n$(msg)"
    end
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
    _set_output_env_vars!(output_env_vars, "CI_QED_IS_PR", "OFF")
    @info "Commit is not part of a pull request"

    # If the commit is not a pull request, CI_COMMIT_REF_NAME stores the target branch name
    # Special case: for version tags we use the same rules like for the main branch
    try
        VersionNumber(ci_commit_ref_name)
        _set_output_env_vars!(output_env_vars, "CI_QED_TARGET_BRANCH", "main")
    catch
        _set_output_env_vars!(output_env_vars, "CI_QED_TARGET_BRANCH", ci_commit_ref_name)
    end
    return nothing
end

"""
    read_commit_message!(output_env_vars::Dict{String, String})

Reads the CI commit message defined in the environment variable `CI_COMMIT_MESSAGE`, if set. If it
finds a line that starts with the environment variable specific prefix for the test type, it parses
the line and adds the custom URL to `output_env_vars`.

# Args
- `output_env_vars::Dict{String, String}`: Environment variables for the output.
"""
function read_commit_message!(output_env_vars::Dict{String, String})
    custom_dependency_urls = CustomDependencyUrls()
    append_custom_dependency_urls_from_git_message!(custom_dependency_urls)
    for test_type in [UnitTest(), IntegrationTest()]
        for (name, value) in get_test_specific_custom_urls(test_type, custom_dependency_urls)
            env_name = get_test_type_env_var_prefix(test_type) * name
            # do not use _set_output_env_vars!(), as this environment should be variable
            # overridable
            output_env_vars[env_name] = value
        end
    end
    return nothing
end
