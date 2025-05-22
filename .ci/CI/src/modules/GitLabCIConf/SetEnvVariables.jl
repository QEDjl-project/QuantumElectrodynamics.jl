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
            # TODO: change me to get_test_type_env_var_prefix()
            env_name = get_test_type_env_var_prefix2(test_type) * name
            output_env_vars[env_name] = value
        end
    end
    return nothing
end
