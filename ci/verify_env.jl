"""
The script checks, if custom dependency for unit tests via `CI_UNIT_PKG_URL_<package_name>` are set.
If yes, the script fails, which means in practice, that the PR rely on non merged code.
"""

"""
    extract_env_vars_from_git_message!()

Parse the commit message, if set via variable `CI_COMMIT_MESSAGE` and set custom urls.
"""
function extract_env_vars_from_git_message!()
    if haskey(ENV, "CI_COMMIT_MESSAGE")
        println("Found env variable CI_COMMIT_MESSAGE")
        for line in split(ENV["CI_COMMIT_MESSAGE"], "\n")
            line = strip(line)
            if startswith(line, "CI_UNIT_PKG_URL_")
                (var_name, url) = split(line, ":"; limit=2)
                println("add " * var_name * "=" * strip(url))
                ENV[var_name] = strip(url)
            end
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    extract_env_vars_from_git_message!()
    filtered_env = filter((env_name)-> startswith(env_name, "CI_UNIT_PKG_URL_"), keys(ENV))

    if isempty(filtered_env)
        printstyled("No custom dependencies for unit tests detected.\n"; color = :green)
        exit(0)
    else
        printstyled("Found custom dependencies for unit tests detected.\n"; color = :red)
        for env in filtered_env
            printstyled("  $env\n"; color = :red)
        end
        printstyled("\nPlease merge the custom dependency before and run the CI with custom dependency again.\n"; color = :red)
        exit(1)
    end
end
