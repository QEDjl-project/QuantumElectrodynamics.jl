# Note: This file is used by SetupDevEnv.jl
#       It is not allowed to use third party packages.
#       Only standard library packages are allowed.

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
    get_package_dependency_list(
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
function get_package_dependency_list(
        graph::Dict, stop_package::AbstractString = ""
    )::Vector{Set{String}}
    pkg_ordering = _get_package_dependency_list!(graph, stop_package)

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

function _get_package_dependency_list!(
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

    # First we search for the highest level containing a required dependency
    # All dependencies in the levels below the highest level needs to be installed
    # and there be part of the output.
    highest_level = 0

    for level in 1:length(package_dependecy_list)
        for required_dep in required_dependencies
            if required_dep in package_dependecy_list[level]
                highest_level = level
            end
        end
    end

    # could not find required dependency
    if highest_level == 0
        return linear_pkg_ordering
    end

    # copy complete level
    for level in 1:(highest_level - 1)
        for pkg in package_dependecy_list[level]
            push!(linear_pkg_ordering, pkg)
        end
    end

    # copy only the dependencies from the highest_level, which are required
    for pkg in package_dependecy_list[highest_level]
        if pkg in required_dependencies
            push!(linear_pkg_ordering, pkg)
        end
    end

    with_logger(debuglogger) do
        @debug "linear ordering of QED packages to add: $(linear_pkg_ordering)"
    end

    return linear_pkg_ordering
end
