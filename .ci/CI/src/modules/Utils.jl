using TOML
using Logging
using LibGit2

debug_logger_io = IOBuffer()
debuglogger = ConsoleLogger(debug_logger_io, Logging.Debug)

"""
    get_project_version_name()::Tuple{String,String}

# Return

Returns project name and version number
"""
function get_project_version_name_path()::Tuple{String, String, String}
    return (Pkg.project().name, string(Pkg.project().version), dirname(Pkg.project().path))
end

"""
    append_custom_dependency_urls_from_env_var!(
        custom_dependency_urls::CustomDependencyUrls, env::AbstractDict{String,String}=ENV
    )

Reads user-defined repository URLs from the environment variables. An environment variable must
either start with the prefix `CI_UNIT_PKG_URL` for custom URLs for unit tests or with the prefix
`CI_INTG_PKG_URL_` for integration tests.
The prefix is removed from the variable name and saved as the package name in
custom_dependency_urls with the variable value. For example,
`CI_UNIT_PKG_URL_QEDbase=https://github.com/integ/QEDbase` is saved as
`QEDbase=https://github.com/integ/QEDbase`.
If the variable is set, the user-defined URL is used instead of the standard URL for the Git clone.

# Args
- `custom_dependency_urls::CustomDependencyUrls`: Add custom unit and integration test custom URLs
- `env::AbstractDict{String,String}`: Only for testing purposes (default: `ENV`).

"""
function append_custom_dependency_urls_from_env_var!(
        custom_dependency_urls::CustomDependencyUrls, env::AbstractDict{String, String} = ENV
    )
    @info "get custom repository URLs from environment variables"
    test_types = [
        ("unit", get_test_type_env_var_prefix(UnitTest()), custom_dependency_urls.unit),
        (
            "integration",
            get_test_type_env_var_prefix(IntegrationTest()),
            custom_dependency_urls.integ,
        ),
    ]
    return with_logger(debuglogger) do
        for (var_name, var_value) in env
            for (test_name, env_prefix, url_dict) in test_types
                if startswith(var_name, env_prefix)
                    pkg_name = var_name[(length(env_prefix) + 1):end]
                    @info "add $(pkg_name)=$(var_value) to $(test_name) test custom urls"
                    url_dict[pkg_name] = var_value
                end
            end
        end
        @debug "custom_urls: $(custom_dependency_urls)"
    end
end

"""Error for append_custom_dependency_urls_from_git_message!"""
function _custom_url_error(test_type::TestType, line::AbstractString)
    return error(
        "custom $(get_test_type_name(test_type)) dependency URL has not the correct shape\n" *
            "given: $line\n" *
            "required shape:\n" *
            "  $(get_test_type_env_var_prefix(test_type))QEDexample: https://github.com/User/QEDexample\n",
        "or\n" *
            "  $(get_test_type_env_var_prefix(test_type))QEDexample: https://github.com/User/QEDexample#example_branch",
    )
end

"""
    append_custom_dependency_urls_from_git_message!(
        custom_dependency_urls::CustomDependencyUrls, env::AbstractDict{String,String}=ENV
    )

Parse the commit message, if set via variable (usual `CI_COMMIT_MESSAGE`) and set custom URLs.
A line with a custom URL must either start with the prefix `CI_UNIT_PKG_URL` for custom URLs for
unit tests or with the prefix `CI_INTG_PKG_URL_` for integration tests, followed by an `: ` and the
URL.

```
Git headline

This is a nice message.
And another line.

CI_INTG_PKG_URL_QEDfields: https://github.com/integ/QEDfields
CI_INTG_PKG_URL_QEDprocesses: https://github.com/integ/QEDprocesses
CI_INTG_PKG_URL_QEDbase: https://github.com/integ/QEDbase
CI_UNIT_PKG_URL_QEDbase: https://github.com/unit/QEDbase
CI_UNIT_PKG_URL_QEDcore: https://github.com/unit/QEDcore
```

The prefix is removed from the variable name and saved as the package name in
custom_dependency_urls with the variable value. For example,
`CI_UNIT_PKG_URL_QEDbase: https://github.com/integ/QEDbase` is saved as
`QEDbase=https://github.com/integ/QEDbase`.
If the variable is set, the user-defined URL is used instead of the standard URL for the Git clone.

# Args
- `custom_dependency_urls::CustomDependencyUrls`: Add custom unit and integration test custom URLs
- `env::AbstractDict{String,String}`: Only for testing purposes (default: `ENV`).

"""
function append_custom_dependency_urls_from_git_message!(
        custom_dependency_urls::CustomDependencyUrls, env::AbstractDict{String, String} = ENV
    )
    test_types = [
        (UnitTest(), custom_dependency_urls.unit),
        (IntegrationTest(), custom_dependency_urls.integ),
    ]
    if !haskey(env, "CI_COMMIT_MESSAGE")
        @info "Git commit message variable CI_COMMIT_MESSAGE is not set."
        return nothing
    end

    @info "Git commit message is set."
    for line in split(env["CI_COMMIT_MESSAGE"], "\n"), (test_type, url_dict) in test_types
        line = strip(line)
        env_prefix = get_test_type_env_var_prefix(test_type)
        if startswith(line, env_prefix)
            if length(split(line, ":"; limit = 2)) < 2
                _custom_url_error(test_type, line)
            end

            (pkg_name, url) = split(line, ":"; limit = 2)
            url = strip(url)
            if !startswith(url, "http")
                _custom_url_error(test_type, line)
            end

            pkg_name = pkg_name[(length(env_prefix) + 1):end]
            @info "add $(pkg_name)=$(url) to $(get_test_type_name(test_type)) custom urls"
            url_dict[pkg_name] = url
        end
    end
    return
end
