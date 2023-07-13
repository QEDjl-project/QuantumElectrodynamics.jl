module integTestGen

import Pkg
import PkgDependency
import YAML

"""
    create_working_env(project_path::AbstractString)

Create a temporary folder, and set up a new Project.toml and activate it. Checking the dependencies of
a project only works, if it is a dependency of the integTestGen.jl. Because the package to analyze
is only a temporary dependency, it must not change the Project.toml of integTestGen.jl permanently.
Therefore, the script generates a temporary Julia environment and adds the package
to analyze as a dependency.

# Args
    `project_path::AbstractString`: Absolute path to the project folder of the package to be analysed
"""
function create_working_env(project_path::AbstractString)
    tmp_path = mktempdir()
    Pkg.activate(tmp_path)
    # same dependency like in the Project.toml of integTestGen.jl
    Pkg.add("Pkg")
    Pkg.add("PkgDependency")
    Pkg.add("YAML")
    # add main project as dependency
    Pkg.develop(path=project_path)
end

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

    Parse the commit message, if set via variable (usual `CI_COMMIT_MESSAGE`) and set custom URLs.
"""
function extract_env_vars_from_git_message!(package_infos::AbstractDict{String, PackageInfo}, var_name = "CI_COMMIT_MESSAGE")
    if haskey(ENV, var_name)
        for line in split(ENV[var_name], "\n")
            line = strip(line)
            for pkg_info in values(package_infos)
                if startswith(line, pkg_info.env_var * ": ")
                    ENV[pkg_info.env_var] = SubString(line, length(pkg_info.env_var * ": ") + 1)
                end
            end
        end
    end
end

"""
    modify_package_url!(package_infos::AbstractDict{String, PackageInfo})

Iterate over all entries of package_info. If an environment variable exits with the same name like,
the `env_var` entry, set the value of the environment variable to `custom_url`.
"""
function modify_package_url!(package_infos::AbstractDict{String, PackageInfo})
    for package_info in values(package_infos)
        if haskey(ENV, package_info.env_var)
            package_info.modified_url = ENV[package_info.env_var]
        end
    end
end

"""
    modified_package_name(package_infos::AbstractDict{String, PackageInfo})

Read the name of the modified (project) package from the environment variable `CI_DEPENDENCY_NAME`.

# Returns
- The name of the modified (project) package
"""
function modified_package_name(package_infos::AbstractDict{String, PackageInfo})
    for env_var in ["CI_DEPENDENCY_NAME", "CI_PROJECT_DIR"]
        if !haskey(ENV, env_var)
            error("Environment variable $env_var is not set.")
        end
    end

    if !haskey(package_infos, ENV["CI_DEPENDENCY_NAME"])
        package_name = ENV["CI_DEPENDENCY_NAME"]
        error("Error unknown package name $package_name}")
    else
        return ENV["CI_DEPENDENCY_NAME"]
    end
end

"""
    depending_projects(package_name, package_prefix, project_tree)

    Return a list of packages, which has the package `package_name` as a dependency. Ignore all packages, which does not start with `package_prefix`.

# Arguments
- `package_name::String`: Name of the dependency
- `package_prefix::Union{AbstractString,Regex}`: If package name does not start with the prefix, do not check if had the dependency.
- `project_tree=PkgDependency.builddict(Pkg.project().uuid, Pkg.project())`: Project tree, where to search the dependend packages. Needs to be a nested dict.
                                                                             Each (sub-)project needs to be AbstractDict{String, AbstractDict}

# Returns
- `::AbstractVector{String}`: all packages, which have the search dependency

"""
function depending_projects(package_name::String, package_prefix::Union{AbstractString,Regex}, project_tree=PkgDependency.builddict(Pkg.project().uuid, Pkg.project()))::AbstractVector{String}
    packages::AbstractVector{String} = []
    visited_packages::AbstractVector{String} = []
    traverse_tree!(package_name, package_prefix, project_tree, packages, visited_packages)
    return packages
end

"""
    traverse_tree!(package_name::String, package_prefix::Union{AbstractString,Regex}, project_tree, packages::AbstractVector{String}, visited_packages::AbstractVector{String})

Traverse a project tree and add package to `packages`, which has the package `package_name` as dependency. Ignore all packages, which does not start with `package_prefix`.
See [`depending_projects`](@ref)

"""
function traverse_tree!(package_name::String, package_prefix::Union{AbstractString,Regex}, project_tree, packages::AbstractVector{String}, visited_packages::AbstractVector{String})
    for project_name_version in keys(project_tree)
        # remove project version from string -> usual shape: `packageName.jl version`
        project_name = split(project_name_version)[1]
        # fullfil the requirements
        # - package starts with the prefix
        # - the dependency is not nothing (I think this representate, that the package was already set as dependency of a another package and therefore do not repead the dependencies)
        # - has dependency
        # - was not already checked
        if startswith(project_name, package_prefix) && project_tree[project_name_version] !== nothing && !isempty(project_tree[project_name_version]) && !(project_name in visited_packages)
            # only investigate each package one time
            # assumption: package name with it's dependency is unique
            push!(visited_packages, project_name)
            for dependency_name_version in keys(project_tree[project_name_version])
                # dependency matches, add to packages
                if startswith(dependency_name_version, package_name)
                    push!(packages, project_name)
                    break
                end
            end
            # independent of a match, under investigate all dependencies too, because they can also have the package as dependency
            traverse_tree!(package_name, package_prefix, project_tree[project_name_version], packages, visited_packages)
        end
    end
end

"""
    generate_job_yaml!(package_name::String, job_yaml::Dict)

Generate GitLab CI job yaml for integration test of a give package.

# Args
- `package_name::String`: Name of the package to test.
- `job_yaml::Dict`: Add generated job to this dict.
"""
function generate_job_yaml!(package_name::String, job_yaml::Dict, package_infos::AbstractDict{String, PackageInfo})
    package_info = package_infos[package_name]
    # if modified_url is empty, use original url
    if package_info.modified_url == ""
        url = package_info.url
    else
        url = package_info.modified_url
    end

    script = [
        "apt update",
        "apt install -y git",
        "cd /"
    ]


    split_url = split(url, "#")
    if length(split_url) > 2
        error("Ill formed url: $(url)")
    end

    push!(script, "git clone $(split_url[1]) integration_test")
    push!(script, "cd integration_test")

    if length(split_url) == 2
        push!(script, "git checkout $(split_url[2])")
    end

    push!(script, "julia --project=. -e 'import Pkg; Pkg.Registry.add(Pkg.RegistrySpec(url=\"https://github.com/QEDjl-project/registry.git\"));'")
    push!(script, "julia --project=. -e 'import Pkg; Pkg.Registry.add(Pkg.RegistrySpec(url=\"https://github.com/JuliaRegistries/General\"));'")
    ci_project_dir = ENV["CI_PROJECT_DIR"]
    push!(script, "julia --project=. -e 'import Pkg; Pkg.develop(path=\"$ci_project_dir\");'")
    push!(script, "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'")

    job_yaml["IntegrationTest$package_name"] = Dict(
        "image" => "julia:1.9",
        "interruptible" => true,
        "tags" => ["cpuonly"],
        "script" => script)
end

"""
    generate_dummy_job_yaml!(job_yaml::Dict)

Generates a GitLab CI dummy job, if required.

# Args
- `job_yaml::Dict`: Add generated job to this dict.
"""
function generate_dummy_job_yaml!(job_yaml::Dict)
    job_yaml["DummyJob"] = Dict("image" => "alpine:latest",
        "interruptible" => true,
        "script" => ["echo \"This is a dummy job so that the CI does not fail.\""])
end

if abspath(PROGRAM_FILE) == @__FILE__
    package_infos = Dict(
        "QED" => PackageInfo(
            "https://github.com/QEDjl-project/QED.jl.git",
            "CI_INTG_PKG_URL_QED"),
        "QEDfields" => PackageInfo(
                "https://github.com/QEDjl-project/QEDfields.jl.git",
                "CI_INTG_PKG_URL_QEDfields"),
        "QEDbase" => PackageInfo(
                "https://github.com/QEDjl-project/QEDbase.jl.git",
                "CI_INTG_PKG_URL_QEDbase"),
        "QEDevents" => PackageInfo(
                "https://github.com/QEDjl-project/QEDevents.jl.git",
                "CI_INTG_PKG_URL_QEDevents"),
        "QEDprocesses" => PackageInfo(
                "https://github.com/QEDjl-project/QEDprocesses.jl.git",
                "CI_INTG_PKG_URL_QEDprocesses"),
    )

    # custom commit message variable can be set as first argument
    if length(ARGS) < 1
        extract_env_vars_from_git_message!(package_infos)
    else
        extract_env_vars_from_git_message!(package_infos, ARGS[1])
    end

    modify_package_url!(package_infos)
    modified_pkg = modified_package_name(package_infos)

    # the script is locate in ci/integTestGen/src
    # so we need to go 3 steps upwards in hierarchy to get the QED.jl Project.toml
    create_working_env(abspath(joinpath((@__DIR__), "../../..")))
    depending_pkg = depending_projects(modified_pkg, r"(QED)")

    job_yaml = Dict()

    if !isempty(depending_pkg)
        for p in depending_pkg
            generate_job_yaml!(p, job_yaml, package_infos)
        end
    else
        generate_dummy_job_yaml!(job_yaml)
    end
    println(YAML.write(job_yaml))
end

end # module integTestGen
