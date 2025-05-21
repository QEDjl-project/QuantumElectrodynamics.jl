# Note: This file is used by SetupDevEnv.jl
#       It is not allowed to use third party packages.
#       Only standard library packages are allowed.

"""
    get_compat_changes()::Dict{String,String}

Generate a list of new compatibility versions for dependency packages.

# Returns

Return a dictionary, where the key is the name and the value is the version to be changed.

"""
function get_compat_changes()::Dict{String, String}
    @info "check for comapt changes"
    compat_changes = Dict{String, String}()
    with_logger(debuglogger) do
        if haskey(ENV, "CI_DEV_PKG_VERSION")
            compat_changes[string(ENV["CI_DEV_PKG_NAME"])] = string(
                ENV["CI_DEV_PKG_VERSION"]
            )
        end
        @debug "compat_changes: $(compat_changes)"
    end
    return compat_changes
end

"""
    set_compat_helper(
        name::AbstractString, version::AbstractString, project_path::AbstractString
    )

Change the version of an existing compat entries of a dependency.

# Args

- `name::AbstractString`: name of the compat entry
- `version::AbstractString`: new version of the compat entry
- `project_path::AbstractString`: project path of the dependency

"""
function set_compat_helper(
        name::AbstractString, version::AbstractString, project_path::AbstractString
    )
    project_toml_path = joinpath(project_path, "Project.toml")

    f = open(project_toml_path, "r")
    project_toml = TOML.parse(f)
    close(f)

    if haskey(project_toml, "compat") && haskey(project_toml["compat"], name)
        if project_toml["compat"][name] != version
            @info "change compat of $project_toml_path: $(name) -> $(version)"
            project_toml["compat"][name] = version
        end
    end

    # for GitHub Actions to fix permission denied error
    chmod(project_toml_path, 0o777)
    f = open(project_toml_path, "w")

    TOML.print(f, project_toml)
    return close(f)
end
