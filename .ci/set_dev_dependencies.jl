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

# TODO(SimeonEhrig): is copied from integTestGen.jl
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
    name_filter::Union{<:AbstractString,Regex}=r".*",
    project_toml_path=Pkg.project().path,
)::AbstractVector{String}
    project_toml = TOML.parsefile(project_toml_path)
    deps = Vector{String}(undef, 0)
    if haskey(project_toml, "deps")
        for dep_pkg in keys(project_toml["deps"])
            if _match_package_filter(name_filter, dep_pkg)
                push!(deps, dep_pkg)
            end
        end
    end
    return deps
end

function build_qed_dev_dependency_graph(qed_path, custom_urls=Dict{String,String}(), package_name="QuantumElectrodynamics", origin=["QuantumElectrodynamics"]
    )::AbstractDict
    graph=Dict()
    repository_path = joinpath(qed_path, package_name)
    if !isdir(repository_path)
        if haskey(custom_urls, package_name)
            splitted_url = split(custom_urls[package_name], "#")
            if length(splitted_url) < 2
                LibGit2.clone(splitted_url[1], repository_path, branch="dev")
            else
                LibGit2.clone(splitted_url[1], repository_path, branch=splitted_url[2])
            end
        else
            # could be optimized with clone depth=1, but no idea if LibGit2.jl support it
            LibGit2.clone("https://github.com/QEDjl-project/$(package_name).jl", repository_path, branch="dev")
        end
    end
    # implement graph building algorithm with `git clone`
    project_toml = TOML.parsefile(joinpath(repository_path, "Project.toml"))
    if haskey(project_toml, "deps")
        for dep_pkg in keys(project_toml["deps"])
            if dep_pkg in origin
                dep_chain = ""
                for dep in origin
                    dep_chain *= dep * " -> "
                end
                throw(ErrorException("detect circular dependency in graph: $(dep_chain)$(dep_pkg)"))
            end
            if startswith(dep_pkg, "QED")
                graph[dep_pkg] = build_qed_dev_dependency_graph(qed_path, custom_urls, dep_pkg, vcat(origin, [dep_pkg]))
            end
        end
    end

    if package_name=="QuantumElectrodynamics"
        head_node = Dict()
        head_node[package_name] = graph
        return head_node
    end
    return graph
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
    graph_copy = deepcopy(graph)
    pkg_ordering = []
    while true
        if isempty(keys(graph_copy["QuantumElectrodynamics"]))
            push!(pkg_ordering,Set{String}(["QuantumElectrodynamics"]))
            return pkg_ordering
        end
        leafs = Set{String}()
        search_leaf(graph_copy, leafs)
        if stop_package in leafs
            push!(pkg_ordering,Set{String}([stop_package]))
            return pkg_ordering
        end
        push!(pkg_ordering, leafs) 
    end
    return pkg_ordering
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

function get_custom_urls_from_env_variables()::AbstractDict{String,String}
    custom_urls=Dict{String,String}()
    for (var_name, var_value) in ENV
        if startswith(var_name, "CI_DEV_DEV_URL_")
            custom_urls[var_name[length("CI_DEV_DEV_URL_")+1:end]] = var_value
        end
    end
    return custom_urls
end

function print_tree(graph, level=0)
    for key in keys(graph)
        println(repeat(".", level)*key)
        print_tree(graph[key], level+1)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    for var in ("CI_DEPENDENCY_NAME", "CI_DEPENDENCY_PATH")
        if !haskey(ENV, var)
            @error "environemnt variable $(var) needs to be set"
            exit(1)
        end
    end

    qed_path=mktempdir(;cleanup=false)
    #qed_path="/tmp/jl_1H5Kco"
    println(qed_path)

    custom_urls = get_custom_urls_from_env_variables()

    new_compat = Vector{Tuple{String,String}}()
    if haskey(ENV, "CI_DEPENDENCY_NAME") && haskey(ENV, "CI_DEPENDENCY_VERSION")
        push!(
            new_compat,
            (string(ENV["CI_DEPENDENCY_NAME"]), string(ENV["CI_DEPENDENCY_VERSION"])),
        )
    end

    pkg_tree = build_qed_dev_dependency_graph(qed_path, custom_urls)
    pkg_ordering = get_package_dependecy_list(pkg_tree)
    for i in keys(pkg_ordering)
        println("$(i): $(pkg_ordering[i])")
    end

    required_deps = get_filtered_dependencies(r"^(QED*|QuantumElectrodynamics*)")

    my_pkg_ordering = []

    for init_level in pkg_ordering
        for required_dep in required_deps
            if required_dep in init_level
                push!(my_pkg_ordering, required_dep)
            end
        end
    end

    println(my_pkg_ordering)

    # remove all QED packages, because otherwise Julia tries to resolve the whole
    # environment if a package is added via Pkg.develop() which can cause circulare dependencies
    for pkg in my_pkg_ordering
        Pkg.rm(pkg)
    end

    # add modified develop versions of the QED packages
    for pkg in my_pkg_ordering
        if pkg == ENV["CI_DEPENDENCY_NAME"]
            println("dev project")
            Pkg.develop(;path=ENV["CI_DEPENDENCY_PATH"])
        else
            project_path=joinpath(qed_path, pkg)
            println(project_path)
            println("dev dependency")
            for (compat_name, compat_version) in new_compat
                println("set compat $(compat_name) to $(compat_version)")
                set_compat_helper(compat_name, compat_version, project_path)
            end
            Pkg.develop(;path=project_path)
        end
    end

    exit()

    #deps = get_filtered_dependencies(r"^(QED*|QuantumElectrodynamics*)")
    #set_dev_dependencies(deps, new_compat, custom_urls)
end
