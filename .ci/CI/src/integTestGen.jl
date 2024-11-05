module integTestGen

include("get_target_branch.jl")
include("utils.jl")

using .TargetBranch
using Pkg: Pkg
using YAML: YAML
using Logging
using IntegrationTests

"""
Contains all git-related information about a package.

# Fields
- `url`: Git url of the original project.
- `modified_url`: Stores the Git url set by the environment variable.
- `env_var`: Name of the environment variable to set the modified_url.
"""
mutable struct PackageInfo
    url::String
    modified_url::String
    env_var::String
    PackageInfo(url, env_var) = new(url, "", env_var)
end

"""
    extract_env_vars_from_git_message!(package_infos::AbstractDict{String, PackageInfo}, var_name = "CI_COMMIT_MESSAGE")

    Parse the commit message, if set via variable (usual `CI_COMMIT_MESSAGE`), and set custom URLs.
"""
function extract_env_vars_from_git_message!(
    package_infos::AbstractDict{String,PackageInfo}, var_name="CI_COMMIT_MESSAGE"
)
    if haskey(ENV, var_name)
        for line in split(ENV[var_name], "\n")
            line = strip(line)
            for pkg_info in values(package_infos)
                if startswith(line, pkg_info.env_var * ": ")
                    ENV[pkg_info.env_var] = SubString(
                        line, length(pkg_info.env_var * ": ") + 1
                    )
                end
            end
        end
    end
end

"""
    modify_package_url!(package_infos::AbstractDict{String, PackageInfo})

Iterate over all entries of package_info. If an environment variable exists with the same name as,
the `env_var` entry, set the value of the environment variable to `modified_url`.
"""
function modify_package_url!(package_infos::AbstractDict{String,PackageInfo})
    for package_info in values(package_infos)
        if haskey(ENV, package_info.env_var)
            package_info.modified_url = ENV[package_info.env_var]
        end
    end
end

"""
    modified_package_name(package_infos::AbstractDict{String, PackageInfo})

Read the name of the modified (project) package from the environment variable `CI_DEV_PKG_NAME`.

# Returns
- The name of the modified (project) package
"""
function modified_package_name(package_infos::AbstractDict{String,PackageInfo})
    for env_var in ["CI_DEV_PKG_NAME", "CI_PROJECT_DIR"]
        if !haskey(ENV, env_var)
            error("Environment variable $env_var is not set.")
        end
    end

    if !haskey(package_infos, ENV["CI_DEV_PKG_NAME"])
        package_name = ENV["CI_DEV_PKG_NAME"]
        error("Error unknown package name $package_name}")
    else
        return ENV["CI_DEV_PKG_NAME"]
    end
end

function clean_pkg_name(pkg_name::AbstractString)
    # remove color tags (?) from the package names
    return replace(pkg_name, r"\{[^}]*\}" => "")
end

"""
    generate_job_yaml!(package_name::String, job_yaml::Dict)

Generate GitLab CI job yaml for integration testing of a given package.

# Args
- `package_name::String`: Name of the package to test.
- `target_branch::AbstractString`: Name of the target branch of the pull request.
- `ci_project_dir::AbstractString`: Path of QED project which should be used for the integration test.
- `job_yaml::Dict`: Add generated job to this dict.
- `package_infos::AbstractDict{String,PackageInfo}`: Contains serveral information about QED packages
- `can_fail::Bool=false`: If true add `allow_failure=true` to the job yaml
"""
function generate_job_yaml!(
    package_name::String,
    target_branch::AbstractString,
    dev_package_name::AbstractString,
    dev_package_version::AbstractString,
    dev_package_path::AbstractString,
    job_yaml::Dict,
    package_infos::AbstractDict{String,PackageInfo},
    git_ci_tools_url::String,
    git_ci_tools_branch::String,
    stage::AbstractString="",
    can_fail::Bool=false,
)
    package_info = package_infos[package_name]
    # if modified_url is empty, use original url
    if package_info.modified_url == ""
        url = package_info.url
    else
        url = package_info.modified_url
    end

    script = ["apt update", "apt install -y git", "cd /"]

    split_url = split(url, "#")
    if length(split_url) > 2
        error("Ill formed url: $(url)")
    end

    push!(script, "git clone -b $target_branch $(split_url[1]) integration_test")
    if (target_branch != "main")
        push!(
            script,
            "git clone -b $(git_ci_tools_branch) $(git_ci_tools_url) /integration_test_tools",
        )
    end
    push!(script, "cd integration_test")

    # checkout specfic branch given by the environemnt variable
    # CI_INTG_PKG_URL_<dep_name>=https://url/to/the/repository#<commit_hash>
    if length(split_url) == 2
        push!(script, "git checkout $(split_url[2])")
    end

    if (target_branch == "main")
        push!(
            script,
            "julia --project=. -e 'import Pkg; Pkg.develop(path=\"$dev_package_path\");'",
        )
    else
        push!(script, "julia --project=. /integration_test_tools/.ci/CI/src/SetupDevEnv.jl")
    end
    push!(script, "julia --project=. -e 'import Pkg; Pkg.instantiate()'")
    push!(script, "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'")

    current_job_yaml = Dict(
        "image" => "julia:1.10",
        "variables" => Dict(
            "CI_DEV_PKG_NAME" => dev_package_name,
            "CI_DEV_PKG_VERSION" => dev_package_version,
            "CI_DEV_PKG_PATH" => dev_package_path,
        ),
        "interruptible" => true,
        "tags" => ["cpuonly"],
        "script" => script,
    )

    if stage != ""
        current_job_yaml["stage"] = stage
    end

    if haskey(ENV, "CI_DEV_PKG_NAME") &&
        haskey(ENV, "CI_DEV_PKG_VERSION") &&
        haskey(ENV, "CI_DEV_PKG_PATH")
        current_job_yaml["variables"] = Dict(
            "CI_DEV_PKG_NAME" => ENV["CI_DEV_PKG_NAME"],
            "CI_DEV_PKG_VERSION" => ENV["CI_DEV_PKG_VERSION"],
            "CI_DEV_PKG_PATH" => ENV["CI_DEV_PKG_PATH"],
        )
    end

    if can_fail
        current_job_yaml["allow_failure"] = true
        return job_yaml["integration_test_$(package_name)_release_test"] = current_job_yaml
    else
        return job_yaml["integration_test_$package_name"] = current_job_yaml
    end
end

"""
    generate_dummy_job_yaml!(job_yaml::Dict)

Generates a GitLab CI dummy job, if required.

# Args
- `job_yaml::Dict`: Add generated job to this dict.
"""
function generate_dummy_job_yaml!(job_yaml::Dict)
    return job_yaml["DummyJob"] = Dict(
        "image" => "alpine:latest",
        "interruptible" => true,
        "script" => ["echo \"This is a dummy job so that the CI does not fail.\""],
    )
end

"""
    get_package_info()::Dict{String,PackageInfo}

Returns a list with QED project package information.
"""
function get_package_info()::Dict{String,PackageInfo}
    return Dict(
        "QuantumElectrodynamics" => PackageInfo(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git",
            "CI_INTG_PKG_URL_QED",
        ),
        "QEDfields" => PackageInfo(
            "https://github.com/QEDjl-project/QEDfields.jl.git",
            "CI_INTG_PKG_URL_QEDfields",
        ),
        "QEDbase" => PackageInfo(
            "https://github.com/QEDjl-project/QEDbase.jl.git", "CI_INTG_PKG_URL_QEDbase"
        ),
        "QEDevents" => PackageInfo(
            "https://github.com/QEDjl-project/QEDevents.jl.git",
            "CI_INTG_PKG_URL_QEDevents",
        ),
        "QEDprocesses" => PackageInfo(
            "https://github.com/QEDjl-project/QEDprocesses.jl.git",
            "CI_INTG_PKG_URL_QEDprocesses",
        ),
        "QEDcore" => PackageInfo(
            "https://github.com/QEDjl-project/QEDcore.jl.git", "CI_INTG_PKG_URL_QEDcore"
        ),
    )
end

# if abspath(PROGRAM_FILE) == @__FILE__
#     if !haskey(ENV, "CI_COMMIT_REF_NAME")
#         @warn "Environemnt variable CI_COMMIT_REF_NAME not defined. Use default branch `dev`."
#         target_branch = "dev"
#     else
#         target_branch = get_target()
#     end

#     package_infos = get_package_info()

#     # custom commit message variable can be set as first argument
#     if length(ARGS) < 1
#         extract_env_vars_from_git_message!(package_infos)
#     else
#         extract_env_vars_from_git_message!(package_infos, ARGS[1])
#     end

#     modify_package_url!(package_infos)
#     modified_pkg = modified_package_name(package_infos)

#     # TODO(SimeonEhrig): refactor me, that the conversion is not required anymore
#     custom_urls = Dict{String,String}()
#     for (name, info) in package_infos
#         if info.modified_url != ""
#             custom_urls[name] = info.modified_url
#         end
#     end
#     qed_path = mktempdir(; cleanup=false)
#     compat_changes = Dict{String,String}()

#     pkg_tree = build_qed_dependency_graph!(qed_path, compat_changes, custom_urls)
#     depending_pkg = IntegrationTests.depending_projects(
#         modified_pkg, collect(keys(package_infos)), pkg_tree
#     )

#     job_yaml = Dict()

#     if !isempty(depending_pkg)
#         for p in depending_pkg
#             # Handles the case of merging in the main branch. If we want to merge in the main branch, 
#             # we do it because we want to publish the package. Therefore, we need to be sure that there 
#             # is an existing version of the dependent QED packages that works with the new version of 
#             # the package we want to release. The integration tests are tested against the development 
#             # branch and the release version.
#             #  - The dev branch version must pass, as this means that the latest version of the other 
#             #    QED packages is compatible with our release version.
#             #  - The release version integration tests may or may not pass. 
#             #    1. If all of these pass, we will not need to increase the minor version of this package. 
#             #    2. If they do not all pass, the minor version must be increased and the failing packages 
#             #    must also be released later with an updated compat entry.
#             #    In either case the release can proceed, as the released packages will continue to work
#             #    because of their current compat entries.
#             if target_branch == "main" && TargetBranch.is_pull_request()
#                 generate_job_yaml!(p, "dev", ENV["CI_PROJECT_DIR"], job_yaml, package_infos)
#                 generate_job_yaml!(
#                     p, "main", ENV["CI_PROJECT_DIR"], job_yaml, package_infos, true
#                 )
#             else
#                 generate_job_yaml!(
#                     p, target_branch, ENV["CI_PROJECT_DIR"], job_yaml, package_infos
#                 )
#             end
#         end
#     else
#         generate_dummy_job_yaml!(job_yaml)
#     end
#     println(YAML.write(job_yaml))
# end

end # module integTestGen
