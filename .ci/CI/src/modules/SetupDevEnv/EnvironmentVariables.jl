# Note: This file is used by SetupDevEnv.jl
#       It is not allowed to use third party packages.
#       Only standard library packages are allowed.

"""
    get_test_type_from_env_var()::TestType

Return the test type to be tested depending on the value of the environment variable `CI_TEST_TYPE`. Depending on the type, different user-defined dependency URLs are used.

# Returns

test type to be tested
"""
function get_test_type_from_env_var()::TestType
    if !haskey(ENV, "CI_TEST_TYPE")
        @error "environment variable CI_TEST_TYPE needs to be set to \"unit\" or \"integ\""
        exit(1)
    end

    if ENV["CI_TEST_TYPE"] == "unit"
        return UnitTest()
    elseif ENV["CI_TEST_TYPE"] == "integ"
        return IntegrationTest()
    else
        @error "environment variable CI_TEST_TYPE needs to have the value \"unit\" or \"integ\""
        exit(1)
    end
end

"""
    check_environment_variables(test_type::TestType)

Check if all required environment variables are set and print required and optional environment
variables.

# Args
- `test_type::TestType` Depending on the type, different environment variables for custom
repository URLs are checked.
"""
function check_environment_variables(test_type::TestType)
    # check required environment variables
    for var in ("CI_DEV_PKG_NAME", "CI_DEV_PKG_PATH")
        if !haskey(ENV, var)
            @error "environment variable $(var) needs to be set"
            exit(1)
        end
    end

    # display all used environment variables
    io = IOBuffer()
    println(io, "following environment variables are set:")
    for e in ("CI_DEV_PKG_NAME", "CI_DEV_PKG_VERSION", "CI_DEV_PKG_PATH")
        if haskey(ENV, e)
            println(io, "$(e): $(ENV[e])")
        end
    end

    for (var_name, var_value) in ENV
        if startswith(var_name, get_test_type_env_var_prefix(test_type))
            println(io, "$(var_name): $(var_value)")
        end
    end
    return @info String(take!(io))
end

"""

    is_dry_run()
    
Return true if the environment variable `CI_SETUP_DEV_ENV_DRY_RUN=ON` is set, false otherwise.
"""
function is_dry_run()::Bool
    if haskey(ENV, "CI_SETUP_DEV_ENV_DRY_RUN")
        if ENV["CI_SETUP_DEV_ENV_DRY_RUN"] == "ON"
            return true
        end
    end
    return false
end
