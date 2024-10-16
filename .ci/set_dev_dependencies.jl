"""
The script sets all QuantumElectrodynamics dependencies of QuantumElectrodynamics
dependencies to the version of the current development branch. For our example we use the
project QEDprocess which has a dependency to QEDfields and QEDfields has a dependency to
QEDcore (I haven't checked if this is the case, it's just hypothetical). If we install
the dev-branch version of QEDfields, the last registered version of QEDcore is still
installed. If QEDfields uses a function which only exist in dev branch of QEDcore and
is not released yet, the integration test will fail.

The script needs to be executed the project space, which should be modified.
"""

using Pkg
using TOML
using Logging
using LibGit2

debug_logger_io = IOBuffer()
debuglogger = ConsoleLogger(debug_logger_io, Logging.Debug)

"""
    _match_package_filter(
        package_filter::Union{<:AbstractString,Regex},
        package::AbstractString
    )::Bool

Check if `package_filter` contains `package`. Wrapper function for `contains()` and `in()`.

# Returns

- `true` if it matches.

"""
function _match_package_filter(
    package_filter::Union{<:AbstractString,Regex}, package::AbstractString
)::Bool
    return contains(package, package_filter)
end

"""
    _match_package_filter(
        package_filter::AbstractVector{<:AbstractString},
        package::AbstractString
    )::Bool
"""
function _match_package_filter(
    package_filter::AbstractVector{<:AbstractString}, package::AbstractString
)::Bool
    return package in package_filter
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

function check_environemnt_variables()
    for var in ("CI_DEV_PKG_NAME", "CI_DEV_PKG_PATH")
        if !haskey(ENV, var)
            @error "environemnt variable $(var) needs to be set"
            exit(1)
        end
    end

    io = IOBuffer()
    println(io, "following environement variables are set:")
    for e in ("CI_DEV_PKG_NAME", "CI_DEV_PKG_VERSION", "CI_DEV_PKG_PATH")
        if haskey(ENV, e)
            println(io, "$(e): $(ENV[e])")
        end
    end

    for (var_name, var_value) in ENV
        if startswith(var_name, "CI_DEV_DEV_URL_")
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
with `CI_DEV_DEV_URL_`. This is followed by the package name, e.g. `CI_DEV_DEV_URL_QEDbase`. If the
variable is set, the user-defined URL is used instead of the standard URL for the Git clone.

# Returns

Dict of custom URLs where the key is the package name and the value the custom URL.
"""
function get_repository_custom_urls()::Dict{String,String}
    @info "get custom repository URLs from environemnt variables"
    custom_urls = Dict{String,String}()
    with_logger(debuglogger) do
        for (var_name, var_value) in ENV
            if startswith(var_name, "CI_DEV_DEV_URL_")
                custom_urls[var_name[(length("CI_DEV_DEV_URL_") + 1):end]] = var_value
            end
        end
        @debug "custom_urls: $(custom_urls)"
    end
    return custom_urls
end

"""
    get_filtered_dependencies(
        name_filter::Union{<:AbstractString,Regex}=r".*",
        project_source=Pkg.dependencies()
    )::AbstractVector{Pkg.API.PackageInfo}

Takes the project_dependencies and filter it by the name_filter. Removes also the UUID as
dict key.

# Returns

- `Vector` of filtered dependencies.
"""
function get_filtered_dependencies(
    name_filter::Union{<:AbstractString,Regex}, project_toml_path::AbstractString
)::AbstractVector{String}
    @info "get required QED dependencies for $(project_toml_path)"
    io = IOBuffer()
    println(io, "found dependencies:")

    project_toml = TOML.parsefile(project_toml_path)
    deps = Vector{String}(undef, 0)
    for toml_section in ("deps", "extras")
        if haskey(project_toml, toml_section)
            for dep_pkg in keys(project_toml[toml_section])
                if _match_package_filter(name_filter, dep_pkg)
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

function _render_qed_tree(graph)
    io = IOBuffer()
    _render_qed_tree!(io, graph, 0, "")
    return String(take!(io))
end

function _render_qed_tree!(io, graph, level, input_string)
    for key in keys(graph)
        println(io, repeat(".", level) * key)
        _render_qed_tree!(io, graph[key], level + 1, input_string)
    end
    return input_string
end

function build_qed_dependency_graph!(
    qed_path::AbstractString, custom_urls::Dict{String,String}=Dict{String,String}()
)::Dict
    @info "build QED dependency graph"
    qed_dependency_graph = Dict()
    qed_dependency_graph["QuantumElectrodynamics"] = _build_qed_dependency_graph!(
        qed_path, custom_urls, "QuantumElectrodynamics", ["QuantumElectrodynamics"]
    )
    with_logger(debuglogger) do
        @debug "QED graph:\n$(_render_qed_tree(qed_dependency_graph))"
    end
    return qed_dependency_graph
end

function _build_qed_dependency_graph!(
    qed_path::AbstractString,
    custom_urls::Dict{String,String},
    package_name::String,
    origin::Vector{String},
)::Dict
    qed_dependency_graph = Dict()
    repository_path = joinpath(qed_path, package_name)
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
                    qed_path, custom_urls, dep_pkg, vcat(origin, [dep_pkg])
                )
            end
        end
    end

    return qed_dependency_graph
end

function search_leaf(graph, leaf_list)
    for pkg in keys(graph)
        if isempty(keys(graph[pkg]))
            push!(leaf_list, pkg)
            pop!(graph, pkg)
        else
            search_leaf(graph[pkg], leaf_list)
        end
    end
end

function get_package_dependecy_list(graph, stop_package="")
    pkg_ordering = _get_package_dependecy_list(graph, stop_package)
    
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

function _get_package_dependecy_list(graph, stop_package)
    @info "calculate the correct sequence for adding QED packages"
    graph_copy = deepcopy(graph)
    pkg_ordering = []
    while true
        if isempty(keys(graph_copy["QuantumElectrodynamics"]))
            push!(pkg_ordering, Set{String}(["QuantumElectrodynamics"]))
            return pkg_ordering
        end
        leafs = Set{String}()
        search_leaf(graph_copy, leafs)
        if stop_package in leafs
            push!(pkg_ordering, Set{String}([stop_package]))
            return pkg_ordering
        end
        push!(pkg_ordering, leafs)
    end

    # unreachable
    return pkg_ordering
end

function calculate_linear_dependency_ordering(qed_package_ordering, required_dependencies)::Vector{String}
    @info "calculate linare ordering to add QED packages"
    linear_pkg_ordering = Vector{String}()

    for init_level in qed_package_ordering
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
    set_dev_dependencies(
        dependencies::AbstractVector{Pkg.API.PackageInfo},
        compact_names::AbstractVector{Tuple{String, String}}=Vector{Tuple{String, String}}(),
        custom_urls::AbstractDict{String,String}=Dict{String,String}(),
    )

Set all dependencies to the development version, if they are not already development versions.
The dict custom_urls takes as key a dependency name and a URL as value. If a dependency is in
custom_urls, it will use the URL as development version. If the dependency does not exist in
custom_urls, it will set the URL https://github.com/QEDjl-project/<dependency_name>.jl

With `compact_names` the compat entries of each dependency can be changed. The first value 
of the tuple is the name of the compatibility entry and the second value is the new version. 
Only changes the version of existing compat entries.
"""
function set_dev_dependencies(
    dependencies::AbstractVector{Pkg.API.PackageInfo},
    compact_names::AbstractVector{Tuple{String,String}}=Vector{Tuple{String,String}}(),
    custom_urls::AbstractDict{String,String}=Dict{String,String}(),
)
    for dep in dependencies
        # if tree_hash is nothing, it is already a dev version
        if !isnothing(dep.tree_hash)
            if haskey(custom_urls, dep.name)
                @warn "use custom url for package $(dep.name): $(custom_urls[dep.name])"
                Pkg.develop(; url=custom_urls[dep.name])
            else
                Pkg.develop(; url="https://github.com/QEDjl-project/$(dep.name).jl")
            end
        end
        for (compact_name, compact_version) in compact_names
            set_compat_helper(compact_name, compact_version, dep.source)
        end
    end
end

function set_dev_dependencies(
    dependencies::Set{String},
    compact_names::AbstractVector{Tuple{String,String}}=Vector{Tuple{String,String}}(),
    custom_urls::AbstractDict{String,String}=Dict{String,String}(),
)
    for dep in dependencies
        if haskey(custom_urls, dep)
            @warn "use custom url for package $(dep): $(custom_urls[dep])"
            Pkg.develop(; url=custom_urls[dep.name])
        else
            Pkg.develop(; url="https://github.com/QEDjl-project/$(dep).jl")
        end
        for (compact_name, compact_version) in compact_names
            set_compat_helper(compact_name, compact_version, dep.source)
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
        project_toml["compat"][name] = version
    end

    # for GitHub Actions to fix permission denied error
    chmod(project_toml_path, 0o777)
    f = open(project_toml_path, "w")

    TOML.print(f, project_toml)
    return close(f)
end

if abspath(PROGRAM_FILE) == @__FILE__
    try
        check_environemnt_variables()
        active_project_project_toml=Pkg.project().path

        compat_changes = get_compat_changes()
        custom_urls = get_repository_custom_urls()

        qed_path = mktempdir(; cleanup=false)

        pkg_tree = build_qed_dependency_graph!(qed_path, custom_urls)
        pkg_ordering = get_package_dependecy_list(pkg_tree)

        required_deps = get_filtered_dependencies(
            r"^(QED*|QuantumElectrodynamics*)",
            active_project_project_toml,
        )

        linear_pkg_ordering = calculate_linear_dependency_ordering(pkg_ordering, required_deps)

        # remove all QED packages, because otherwise Julia tries to resolve the whole
        # environment if a package is added via Pkg.develop() which can cause circulare dependencies
        remove_packages(linear_pkg_ordering)
        
        # add modified develop versions of the QED packages
        for pkg in linear_pkg_ordering
            if pkg == ENV["CI_DEV_PKG_NAME"]
                println("dev project")
                Pkg.develop(; path=ENV["CI_DEV_PKG_PATH"])
            else
                project_path = joinpath(qed_path, pkg)
                println(project_path)
                println("dev dependency")
                for (compat_name, compat_version) in compat_changes
                    println("set compat $(compat_name) to $(compat_version)")
                    set_compat_helper(compat_name, compat_version, project_path)
                end
                Pkg.develop(; path=project_path)
            end
        end
    catch e
        # print debug information if uncatch error is thrown
        println(String(take!(debug_logger_io)))
        throw(e)
    end
end
