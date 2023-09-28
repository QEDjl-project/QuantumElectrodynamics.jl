"""
The script checks, if a custom dependency for unit tests via `CI_UNIT_PKG_URL_<package_name>` is set.
If so, the script fails, which means in practice, that the PR relies on non-merged code.
"""

"""
    extract_env_vars_from_git_message!()

Parse the commit message, if set via variable `CI_COMMIT_MESSAGE` and set custom URLs.
"""
function extract_env_vars_from_git_message!()
    if haskey(ENV, "CI_COMMIT_MESSAGE")
        @info "Found env variable CI_COMMIT_MESSAGE"
        for line in split(ENV["CI_COMMIT_MESSAGE"], "\n")
            line = strip(line)
            if startswith(line, "CI_UNIT_PKG_URL_")
                (var_name, url) = split(line, ":"; limit=2)
                @info "add " * var_name * "=" * strip(url)
                ENV[var_name] = strip(url)
            end
        end
    end
end

struct EnvironmentVerificationException <: Exception
    envs::Set{AbstractString}
end

function Base.showerror(io::IO, e::EnvironmentVerificationException)
    local err_str = "Found custom dependencies for unit tests.\n"
    for env in e.envs
        err_str *= "  $env\n"
    end
    err_str *= "\nPlease merge the custom dependency before and run the CI with custom dependency again."
    return print(io, "EnvironmentVerificationException: ", err_str)
end

if abspath(PROGRAM_FILE) == @__FILE__
    extract_env_vars_from_git_message!()
    filtered_env = filter((env_name) -> startswith(env_name, "CI_UNIT_PKG_URL_"), keys(ENV))

    if isempty(filtered_env)
        @info "No custom dependencies for unit tests detected."
        exit(0)
    else
        throw(EnvironmentVerificationException(filtered_env))
    end
end
