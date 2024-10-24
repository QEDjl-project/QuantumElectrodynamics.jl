"""
The script checks the dependencies of the current project and provides a Julia environment that
provides all current development versions of the QED dependencies.

The following steps are carried out
1. Create a dependency graph of the active project without instantiating it. The QED
project is cloned to do this, and the current dev branch is used.
2. Calculate the correct order for all QED packages in which the packages must be added to the
environment so that no QED package is added as an implicit dependency.
3. Calculate which packages must be added in which order for the QED package to be tested.
4. Remove all QED packages from the current environment to prevent QED packages defined as
implicit dependencies from being instantiated.
5. Install the QED package for testing and all QED dependencies in the correct order. If it is a
dependency, the compat entry is also changed to match the QED package under test.

The script must be executed in the project space, which should be modified.
"""

module SetupDevEnv

using Pkg
using TOML
using Logging
using LibGit2

debug_logger_io = IOBuffer()
debuglogger = ConsoleLogger(debug_logger_io, Logging.Debug)

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
    extract_env_vars_from_git_message!(var_name::AbstractString="CI_COMMIT_MESSAGE")

Parse the commit message, if set via variable (usual `CI_COMMIT_MESSAGE`) and set custom URLs.
"""
function extract_env_vars_from_git_message!(var_name::AbstractString="CI_COMMIT_MESSAGE")
    if haskey(ENV, var_name)
        @info "Found env variable $var_name"
        for line in split(ENV[var_name], "\n")
            line = strip(line)
            if startswith(line, "CI_UNIT_PKG_URL_")
                (pkg_name, url) = split(line, ":"; limit=2)
                @info "add " * pkg_name * "=" * strip(url)
                ENV[pkg_name] = strip(url)
            end
        end
    end
end

"""
    check_environemnt_variables()

Check if all reguired environement variables are set and print required and optional environement 
variables.
"""
function check_environemnt_variables()
    # check required environement variables
    for var in ("CI_DEV_PKG_NAME", "CI_DEV_PKG_PATH")
        if !haskey(ENV, var)
            @error "environemnt variable $(var) needs to be set"
            exit(1)
        end
    end

    # display all used environement variables
    io = IOBuffer()
    println(io, "following environement variables are set:")
    for e in ("CI_DEV_PKG_NAME", "CI_DEV_PKG_VERSION", "CI_DEV_PKG_PATH")
        if haskey(ENV, e)
            println(io, "$(e): $(ENV[e])")
        end
    end

    for (var_name, var_value) in ENV
        if startswith(var_name, "CI_UNIT_PKG_URL_")
            println(io, "$(var_name): $(var_value)")
        end
    end
    @info String(take!(io))
end

"""
    get_compat_changes()::Dict{String,String}

Generates a list of new compatibility versions for dependency packages.

# Returns

Returns a dictionary, where the key is the name and the value is the version to be changed.
    
"""
function get_compat_changes()::Dict{String,String}
    @info "check for comapt changes"
    compat_changes = Dict{String,String}()
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
    get_repository_custom_urls()::Dict{String,String}

Reads user-defined repository URLs from the environment variables. An environment variable must begin
with `CI_UNIT_PKG_URL_`. This is followed by the package name, e.g. `CI_UNIT_PKG_URL_QEDbase`. If the
variable is set, the user-defined URL is used instead of the standard URL for the Git clone.

# Returns

Dict of custom URLs where the key is the package name and the value the custom URL.
"""
function get_repository_custom_urls()::Dict{String,String}
    @info "get custom repository URLs from environemnt variables"
    custom_urls = Dict{String,String}()
    with_logger(debuglogger) do
        for (var_name, var_value) in ENV
            if startswith(var_name, "CI_UNIT_PKG_URL_")
                pkg_name = var_name[(length("CI_UNIT_PKG_URL_") + 1):end]
                @debug "add $(pkg_name)=$(var_value) to custom_urls"
                custom_urls[pkg_name] = var_value
            end
        end
        @debug "custom_urls: $(custom_urls)"
    end
    return custom_urls
end

"""
    get_filtered_dependencies(
        name_filter::Regex, project_toml_path::AbstractString
    )::AbstractVector{String}

Return a list of dependencies that are defined in the sections `deps` and `extras` in a `Project.toml`
of a package.

# Args
    - `name_filter::Regex`: Only if the package name matches the regex, it will be returned.
    - `project_toml_path::AbstractString`: Path of the `Project.toml`

# Returns

List of package dependencies
"""
function get_filtered_dependencies(
    name_filter::Regex, project_toml_path::AbstractString
)::AbstractVector{String}
    @info "get required QED dependencies for $(project_toml_path)"
    io = IOBuffer()
    println(io, "found dependencies:")

    project_toml = TOML.parsefile(project_toml_path)
    deps = Vector{String}(undef, 0)
    for toml_section in ("deps", "extras")
        if haskey(project_toml, toml_section)
            for dep_pkg in keys(project_toml[toml_section])
                if contains(dep_pkg, name_filter)
                    if !(dep_pkg in deps)
                        push!(deps, dep_pkg)
                    end
                    println(io, "[$(toml_section)] -> $(dep_pkg)")
                end
            end
        end
    end
    with_logger(debuglogger) do
        @debug "required dependencies: $(deps)\n" * String(take!(io))
    end
    return deps
end

"""
    _render_qed_tree(graph)::String

Renders a given graph in ASCII art for debugging purposes.

# Returns

Rendered graph
"""
function _render_qed_tree(graph::Dict)::String
    io = IOBuffer()
    _render_qed_tree(io, graph, 0, "")
    return String(take!(io))
end

function _render_qed_tree(io::IO, graph::Dict, level::Integer, input_string::String)
    for key in keys(graph)
        println(io, repeat(".", level) * key)
        _render_qed_tree(io, graph[key], level + 1, input_string)
    end
    return input_string
end

"""
    build_qed_dependency_graph!(
        repository_base_path::AbstractString,
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
- `package_name::String`: Current package to clone
- `origin::Vector{String}`: List of already visited packages

# Returns

Dict with the dependency graph. A leaf node has an empty dict. Duplications of dependencies are
possible.
"""
function _build_qed_dependency_graph!(
    repository_base_path::AbstractString,
    compat_changes::Dict{String,String},
    custom_urls::Dict{String,String},
    package_name::String,
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
    _search_leaf!(graph::Dict, leaf_set::Set{String})

Search for all leafs in a graph and add it to the leaf_set.

Site effect:
- if a leaf is found, remove it from the graph

# Args
- `graph::Dict`: Dependency graph
- `leaf_set::Set{String}`: set of founded leafs

"""
function _search_leaf!(graph::Dict, leaf_set::Set{String})
    for pkg in keys(graph)
        if isempty(keys(graph[pkg]))
            push!(leaf_set, pkg)
            pop!(graph, pkg)
        else
            _search_leaf!(graph[pkg], leaf_set)
        end
    end
    return Nothing
end

"""
    get_package_dependecy_list(
        graph::Dict, stop_package::AbstractString=""
    )::Vector{Set{String}}

Executes a search and reduction algorithm. In each round, all leaves in the graph are searched for
and added to a set. If a leaf is found, it is removed from the graph. At the end of a round, the
set is added to a list. The algorithm loops until the graph is reduced to an empty graph or the 
stop package is found.

The inversion of the list specifies the order in which the nodes must be added to the graph to
create it. There is no order between the packages within a set. The list does not store the
dependencies between the nodes.

The algorithm works on a copy of the input graph.

# Args
- `graph::Dict`: The dependency graph that is to be reduced
- `stop_package::AbstractString=""`: If the stop package is found, stop the reduction before the
    graph is empty.

# Returns

Returns a list of sets. The index position stands for the round in which the leaf was found,
e.g. pkg_ordering[1] stands for the first round. The set contains all leaves that were found in the
round. There is no order within a round.
"""
function get_package_dependecy_list(
    graph::Dict, stop_package::AbstractString=""
)::Vector{Set{String}}
    pkg_ordering = _get_package_dependecy_list!(graph, stop_package)

    with_logger(debuglogger) do
        io = IOBuffer()
        for i in keys(pkg_ordering)
            println(io, "$(i): $(pkg_ordering[i])")
        end
        pkg_ordering_str = String(take!(io))
        @debug "generate dependency ordering list:\n$(pkg_ordering_str)"
    end

    return pkg_ordering
end

function _get_package_dependecy_list!(
    graph::Dict, stop_package::AbstractString
)::Vector{Set{String}}
    @info "calculate the correct sequence for adding QED packages"
    graph_copy = deepcopy(graph)
    pkg_ordering = Vector{Set{String}}()
    while true
        if isempty(keys(graph_copy["QuantumElectrodynamics"]))
            push!(pkg_ordering, Set{String}(["QuantumElectrodynamics"]))
            return pkg_ordering
        end
        leafs = Set{String}()
        _search_leaf!(graph_copy, leafs)
        if stop_package in leafs
            push!(pkg_ordering, Set{String}([stop_package]))
            return pkg_ordering
        end
        push!(pkg_ordering, leafs)
    end

    # unreachable
    return pkg_ordering
end

"""
    calculate_linear_dependency_ordering(
        package_dependecy_list::Vector{Set{String}}, 
        required_dependencies::AbstractVector{String}
    )::Vector{String}

Computes an ordered list of packages that shows how to add packages to a Julia environment without
adding a package from the list as an implicit dependency of another package from the list for a
given package.


# Args
- `package_dependecy_list::Vector{Set{String}},`: Ordered list of packages to be added, which
    avoids implicit dependencies for the entire package ecosystem.
- `required_dependencies::AbstractVector{String}`: Required dependencies for a specifc package

# Returns

Ordered list of packages that shows how to add packages to a Julia environment without
adding a package from the list as an implicit dependency of another package from the list for a
given package.
"""
function calculate_linear_dependency_ordering(
    package_dependecy_list::Vector{Set{String}},
    required_dependencies::AbstractVector{String},
)::Vector{String}
    @info "calculate linare ordering to add QED packages"
    linear_pkg_ordering = Vector{String}()

    for init_level in package_dependecy_list
        for required_dep in required_dependencies
            if required_dep in init_level
                push!(linear_pkg_ordering, required_dep)
            end
        end
    end

    with_logger(debuglogger) do
        @debug "linear ordering of QED packages to add: $(linear_pkg_ordering)"
    end

    return linear_pkg_ordering
end

"""
    remove_packages(dependencies::Vector{String})

Remove the given packages from the active environment.

# Args
- `dependencies::Vector{String}`: Packages to remove
"""
function remove_packages(dependencies::Vector{String})
    @info "remove packages: $(dependencies)"
    for pkg in dependencies
        # if the package is in the extra section, it cannot be removed
        try
            Pkg.rm(pkg)
        catch
            @warn "tried to remove uninstalled package $(pkg)"
        end
    end
end

"""
    install_qed_dev_packages(
        pkg_to_install::Vector{String},
        qed_path,
        dev_package_name::AbstractString,
        dev_package_path::AbstractString,
        compat_changes::Dict{String,String},
    )

Install the development version of all specified QED packages for the project. This includes
dependencies and the project to be tested itself. For dependencies, the compat entry is also
changed so that it is compatible with the project to be tested.

# Args
    - `pkg_to_install::Vector{String}`: Names of the QED packages to be installed.
    - `qed_path`: Base path in which the repositories of the development versions of the
        dependencies are located.
    - `dev_package_name::AbstractString`: Name of the QED package to be tested.
    - `dev_package_path::AbstractString`: Repository path of the QED package to be tested.
    - `compat_changes::Dict{String,String}`: Sets the Compat entries in the dependency projects to
        the specified version. The key is the name of the compatibility entry and the value is the
        new version.

"""
function install_qed_dev_packages(
    pkg_to_install::Vector{String},
    qed_path,
    dev_package_name::AbstractString,
    dev_package_path::AbstractString,
    compat_changes::Dict{String,String},
)
    @info "install QED packages"

    for pkg in pkg_to_install
        if pkg == dev_package_name
            @info "install dev package: $(dev_package_path)"
            Pkg.develop(; path=dev_package_path)
        else
            project_path = joinpath(qed_path, pkg)

            for (compat_name, compat_version) in compat_changes
                set_compat_helper(compat_name, compat_version, project_path)
            end

            @info "install dependency package: $(project_path)"
            Pkg.develop(; path=project_path)
        end
    end
end

"""
    set_compat_helper(
        name::AbstractString, version::AbstractString, project_path::AbstractString
    )

Change the version of an existing compat enties of a dependency.

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

if abspath(PROGRAM_FILE) == @__FILE__
    try
        extract_env_vars_from_git_message!()
        check_environemnt_variables()
        active_project_project_toml = Pkg.project().path

        compat_changes = get_compat_changes()
        custom_urls = get_repository_custom_urls()

        qed_path = mktempdir(; cleanup=false)

        pkg_tree = build_qed_dependency_graph!(qed_path, compat_changes, custom_urls)
        pkg_ordering = get_package_dependecy_list(pkg_tree)

        required_deps = get_filtered_dependencies(
            r"^(QED*|QuantumElectrodynamics*)", active_project_project_toml
        )

        linear_pkg_ordering = calculate_linear_dependency_ordering(
            pkg_ordering, required_deps
        )

        # remove all QED packages, because otherwise Julia tries to resolve the whole
        # environment if a package is added via Pkg.develop() which can cause circulare dependencies
        remove_packages(linear_pkg_ordering)

        install_qed_dev_packages(
            linear_pkg_ordering,
            qed_path,
            ENV["CI_DEV_PKG_NAME"],
            ENV["CI_DEV_PKG_PATH"],
            compat_changes,
        )
    catch e
        # print debug information if uncatch error is thrown
        println(String(take!(debug_logger_io)))
        throw(e)
    end

    # print debug information if debug information is manually enabled
    @debug String(take!(debug_logger_io))
end

end
