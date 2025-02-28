
using TOML
using Logging
using LibGit2

debug_logger_io = IOBuffer()
debuglogger = ConsoleLogger(debug_logger_io, Logging.Debug)

"""
Represent type of tests to be tested
"""
abstract type TestType end
struct UnitTest <: TestType end
struct IntegrationTest <: TestType end

"""
    get_test_type_env_var_prefix(::TestType)

Depending on the test type, a different prefix for a environment variable name is returned.
Environment starting with the prefix contains custom dependency URLs.

# Args
`::TestType` The test type

# Returns

Prefix of variable names that are read in order to obtain user-defined URLs.
"""
get_test_type_env_var_prefix(::TestType) = error("unknown test type")
get_test_type_env_var_prefix(::UnitTest) = "CI_UNIT_PKG_URL_"
get_test_type_env_var_prefix(::IntegrationTest) = "CI_INTG_PKG_URL_"

"""
    get_test_type_name(::TestType)

Return human readable name of the test type.

# Args
`::TestType` The test type

# Returns

test name
"""
get_test_type_name(::UnitTest) = "unit test"
get_test_type_name(::IntegrationTest) = "integration test"

Base.show(io::IO, obj::TestType) = print(io, get_test_type_name(obj))

"""
    struct TestPackage

Contains information about the package to test.

# Members
- `name::String`: Name of the package.
- `version::String`: Version of the package.
- `path::String`: Path of the package root.

"""
struct TestPackage
    name::String
    version::String
    path::String
end

"""
    struct ToolsGitRepo

Url and branch of the Git repository QuantumElectrodynamics.jl, which is to be used in the CI jobs.

# Members
- `url::String`: Git repository URL.
- `branch::String`: Git branch.

"""
struct ToolsGitRepo
    url::String
    branch::String
end

"""
    struct CustomDependencyUrls

Stores custom repository URLs for QED packages which are dependency of the project to be tested.

# Members
- `unit::Dict{String,String}`: Custom dependencies of the unit tests
- `integ::Dict{String,String}`: Custom dependencies of the integration tests

"""
struct CustomDependencyUrls
    unit::Dict{String,String}
    integ::Dict{String,String}

    CustomDependencyUrls() = new(Dict{String,String}(), Dict{String,String}())
end

function to_str_custom_urls(urls::Dict{String,String})::String
    io = IOBuffer()
    for (index, (pkg_name, url)) in enumerate(urls)
        if index < length(urls)
            println(io, "$(pkg_name): $(url)")
        else
            print(io, "$(pkg_name): $(url)")
        end
    end
    return String(take!(io))
end

"""
    _git_clone(repo_url::AbstractString, directory::AbstractString)

Clones git repository

# Args
- `repo_url::AbstractString`: Url of the repository. Can either be a plan URL or use the Julia Pkg
    notation <URL>#<branchname>. e.g. https://https://github.com/user/repo.git#dev to clone the
    dev branch of the repository `repo`.
- `directory::AbstractString`: Path where the cloned repository is stored.
"""
function _git_clone(repo_url::AbstractString, directory::AbstractString)
    splitted_url = split(repo_url, "#")
    if length(splitted_url) < 2
        _git_clone(repo_url, "dev", directory)
    else
        _git_clone(splitted_url[1], splitted_url[2], directory)
    end
end

"""
    _git_clone(repo_url::AbstractString, directory::AbstractString)

Clones git repository

# Args
- `repo_url::AbstractString`: Url of the repository.
- `branch::AbstractString`: Git branch name
- `directory::AbstractString`: Path where the cloned repository is stored.
"""
function _git_clone(
    repo_url::AbstractString, branch::AbstractString, directory::AbstractString
)
    @info "clone repository: $(repo_url)#$(branch) -> $(directory)"
    with_logger(debuglogger) do
        try
            @debug "git clone --depth 1 -b $(branch) $(repo_url) $directory"
            run(
                pipeline(
                    `git clone --depth 1 -b $(branch) $(repo_url) $directory`;
                    stdout=devnull,
                    stderr=devnull,
                ),
            )
        catch
            @debug "LibGit2.clone($(repo_url), $(directory); branch=$(branch))"
            LibGit2.clone(repo_url, directory; branch=branch)
        end
    end
end

"""
    build_qed_dependency_graph!(
        repository_base_path::AbstractString,
        compat_changes::Dict{String,String},
        custom_urls::Dict{String,String}=Dict{String,String}(),
    )::Dict

Creates the dependency graph of the QED package ecosystem just by parsing Projects.toml. The
function starts by cloning the QuantumElectrodynamics.jl GitHub repository. Depending on
QuantumElectrodynamics.jl `Project.toml`, clones all directly and indirectly dependent QED.jl
GitHub repositories and constructs the dependency graph. 

Side effects of the function are:
    - the Git repositories remain in the path defined in the `repository_base_path` variable
    - the environment is not initialized (creation of a Manifest.toml) or changed in any other way

# Args

- `repository_base_path::AbstractString`: Base folder into which the QED projects are to be cloned.
- `compat_changes::Dict{String,String}`: All QED package versions are added so that they can be set
    correctly in the Compat section of the other QED packages. Existing entries are not changed.
- `custom_urls::Dict{String,String}`: By default, the URL pattern
    `https://github.com/QEDjl-project/<package name>.jl` is used for the clone and the dev branch
    is checked out. The dict allows the use of custom URLs and branches for each QED project. The
    key is the package name and the value must have the following form: `<git_url>#<branch_name>`.
    The syntax is the same as for `Pkg.add()`.

# Returns

Dict with the dependency graph. A leaf node has an empty dict. Duplications of dependencies are
possible.
"""
function build_qed_dependency_graph!(
    repository_base_path::AbstractString,
    compat_changes::Dict{String,String},
    custom_urls::Dict{String,String}=Dict{String,String}(),
)::Dict
    @info "build QED dependency graph"
    io = IOBuffer()
    println(io, "input compat_changes: $(compat_changes)")

    qed_dependency_graph = Dict()
    qed_dependency_graph["QuantumElectrodynamics"] = _build_qed_dependency_graph!(
        repository_base_path,
        compat_changes,
        custom_urls,
        "QuantumElectrodynamics",
        ["QuantumElectrodynamics"],
    )
    println(io, "output compat_changes: $(compat_changes)")
    with_logger(debuglogger) do
        println(io, "QED graph:\n$(_render_qed_tree(qed_dependency_graph))")
        @debug String(take!(io))
    end
    return qed_dependency_graph
end

"""
    _build_qed_dependency_graph!(
        repository_base_path::AbstractString,
        compat_changes::Dict{String,String},
        custom_urls::Dict{String,String},
        package_name::String,
        origin::Vector{String},
    )::Dict

# Args

- `repository_base_path::AbstractString`: Base folder into which the QED projects will be cloned.
- `compat_changes::Dict{String,String}`: All QED package versions are added so that they can be set
    correctly in the Compat section of the other QED packages. Existing entries are not changed.
- `custom_urls::Dict{String,String}`: By default, the URL pattern
    `https://github.com/QEDjl-project/<package name>.jl` is used for the clone and the dev branch
    is checked out. The dict allows the use of custom URLs and branches for each QED project. The
    key is the package name and the value must have the following form: `<git_url>#<branch_name>`.
    The syntax is the same as for `Pkg.add()`.
- `package_name::AbstractString`: Current package to clone
- `origin::Vector{String}`: List of already visited packages

# Returns

Dict with the dependency graph. A leaf node has an empty dict. Duplications of dependencies are
possible.
"""
function _build_qed_dependency_graph!(
    repository_base_path::AbstractString,
    compat_changes::Dict{String,String},
    custom_urls::Dict{String,String},
    package_name::AbstractString,
    origin::Vector{String},
)::Dict
    qed_dependency_graph = Dict()
    repository_path = joinpath(repository_base_path, package_name)
    if !isdir(repository_path)
        if haskey(custom_urls, package_name)
            _git_clone(custom_urls[package_name], repository_path)
        else
            _git_clone(
                "https://github.com/QEDjl-project/$(package_name).jl",
                "dev",
                repository_path,
            )
        end
    end

    # read dependencies from Project.toml and clone next packages until no 
    # QED dependencies are left
    project_toml = TOML.parsefile(joinpath(repository_path, "Project.toml"))

    # add package version to compat entires, that they can be set correctly in the compat section of
    # other packages
    if !(project_toml["name"] in keys(compat_changes))
        compat_changes[project_toml["name"]] = project_toml["version"]
    end

    if haskey(project_toml, "deps")
        for dep_pkg in keys(project_toml["deps"])
            # check for circular dependency
            # actual there should be no circular dependency in graph
            # if there is a circular dependency in the graph, find a good way to appease the CI 
            # developer
            if dep_pkg in origin
                dep_chain = ""
                for dep in origin
                    dep_chain *= dep * " -> "
                end
                throw(
                    ErrorException(
                        "detect circular dependency in graph: $(dep_chain)$(dep_pkg)"
                    ),
                )
            end
            # handle only dependency starting with QED
            if startswith(dep_pkg, "QED")
                qed_dependency_graph[dep_pkg] = _build_qed_dependency_graph!(
                    repository_base_path,
                    compat_changes,
                    custom_urls,
                    dep_pkg,
                    vcat(origin, [dep_pkg]),
                )
            end
        end
    end

    return qed_dependency_graph
end

"""
    _render_qed_tree(graph::Dict)::String

Renders a given graph in ASCII art for debugging purposes.

# Args
- `graph::Dict`: The graph

# Returns

Rendered graph
"""
function _render_qed_tree(graph::Dict)::String
    io = IOBuffer()
    _render_qed_tree(io, graph, 0, "")
    return String(take!(io))
end

function _render_qed_tree(io::IO, graph::Dict, level::Integer, input_string::AbstractString)
    for key in keys(graph)
        println(io, repeat(".", level) * key)
        _render_qed_tree(io, graph[key], level + 1, input_string)
    end
    return input_string
end

"""
    get_project_version_name()::Tuple{String,String}

# Return

Returns project name and version number
"""
function get_project_version_name_path()::Tuple{String,String,String}
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
    custom_dependency_urls::CustomDependencyUrls, env::AbstractDict{String,String}=ENV
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
    with_logger(debuglogger) do
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
    custom_dependency_urls::CustomDependencyUrls, env::AbstractDict{String,String}=ENV
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
            if length(split(line, ":"; limit=2)) < 2
                _custom_url_error(test_type, line)
            end

            (pkg_name, url) = split(line, ":"; limit=2)
            url = strip(url)
            if !startswith(url, "http")
                _custom_url_error(test_type, line)
            end

            pkg_name = pkg_name[(length(env_prefix) + 1):end]
            @info "add $(pkg_name)=$(url) to $(get_test_type_name(test_type)) custom urls"
            url_dict[pkg_name] = url
        end
    end
end

"""
    _add_stage_once!(job_dict::Dict, stage_name::AbstractString)

Check whether the stage section and stage name exist. If one or both are not available, add them to
the job.

# Args
- `job_dict::Dict`: The job dict.
- `stage_name::AbstractString`: Name of the stage.
"""
function _add_stage_once!(job_dict::Dict, stage_name::AbstractString)
    if !haskey(job_dict, "stages")
        job_dict["stages"] = []
    end

    if !(stage_name in job_dict["stages"])
        push!(job_dict["stages"], stage_name)
    end
end
