# workaround if it is included in CI.jl for testing purpose
if abspath(PROGRAM_FILE) == @__FILE__
    include("./modules/Utils.jl")
end

struct EnvironmentVerificationException <: Exception
    envs::Set{AbstractString}
end

function Base.showerror(io::IO, e::EnvironmentVerificationException)
    local err_str = "Found custom dependencies for unit tests.\n"
    local env_prefix = get_test_type_env_var_prefix(UnitTest())
    for env_name in e.envs
        err_str *= "  $(env_prefix)$(env_name)\n"
    end
    err_str *= "\nPlease merge the custom dependency before and run the CI with custom dependency again."
    return print(io, "EnvironmentVerificationException: ", err_str)
end

if abspath(PROGRAM_FILE) == @__FILE__
    custom_dependency_urls = CustomDependencyUrls()
    append_custom_dependency_urls_from_git_message!(custom_dependency_urls)
    append_custom_dependency_urls_from_env_var!(custom_dependency_urls)

    if isempty(custom_dependency_urls.unit)
        @info "No custom dependencies for unit tests detected."
        exit(0)
    else
        throw(EnvironmentVerificationException(keys(custom_dependency_urls.unit)))
    end
end
