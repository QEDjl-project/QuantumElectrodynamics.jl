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

using Pkg
using TOML
using Logging
using LibGit2

# workaround if it is included in CI.jl for testing purpose
if abspath(PROGRAM_FILE) == @__FILE__
    include("./modules/Utils.jl")
end

"""
    get_test_type_from_env_var()::TestType

Depending on the value of the environment variable `CI_TEST_TYPE`, the test type to be tested is
returned. Depending on the type, different user-defined dependency URLs are used.

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
    @info String(take!(io))
end

"""
    get_test_specific_custom_urls(::UnitTest, urls::CustomDependencyUrls)::Dict{String, String}

Returns reference to the dict containing the custom repository URLs for the given test type.

# Returns

The key is the name of the package and the value the custom URL.
"""
get_test_specific_custom_urls(::UnitTest, urls::CustomDependencyUrls)::Dict{String,String} =
    urls.unit

"""
See `get_test_specific_custom_urls(::UnitTest, urls::CustomDependencyUrls)::Dict{String, String}`
"""
get_test_specific_custom_urls(
    ::IntegrationTest, urls::CustomDependencyUrls
)::Dict{String,String} = urls.integ

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
    graph::Dict, stop_package::AbstractString=""
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

"""
    remove_packages(dependencies::Vector{String})

Remove the given packages from the active environment.

# Args
- `dependencies::Vector{String}`: Packages to remove
"""
function remove_packages(dependencies::Vector{String})
    @info "remove packages: $(dependencies)"
    project_pkg_name = Pkg.project().name

    for pkg in dependencies
        if pkg == project_pkg_name
            @warn "Skipped uninstallation: Try to uninstall the dependency $(pkg), " *
                "but it is the name of the active project."
            continue
        end

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

    project_pkg_name = Pkg.project().name

    for pkg in pkg_to_install
        if pkg == project_pkg_name
            @warn "Skipped installation: Try to install the dependency $(pkg), " *
                "but it is the name of the active project."
            continue
        end

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
        test_type::TestType = get_test_type_from_env_var()
        @info "Use Custom dependency URLs for test type: $(test_type)"
        @info "Custom URL environment variable prefix: $(get_test_type_env_var_prefix(test_type))"

        check_environment_variables(test_type)

        custom_dependency_urls = CustomDependencyUrls()
        append_custom_dependency_urls_from_git_message!(custom_dependency_urls)
        append_custom_dependency_urls_from_env_var!(custom_dependency_urls)

        test_specific_custom_urls = get_test_specific_custom_urls(
            test_type, custom_dependency_urls
        )
        @info "Set custom URLs for dependencies: \n$(to_str_custom_urls(test_specific_custom_urls))"

        active_project_project_toml = Pkg.project().path

        compat_changes = get_compat_changes()

        qed_path = mktempdir(; cleanup=false)

        pkg_tree = build_qed_dependency_graph!(
            qed_path, compat_changes, test_specific_custom_urls
        )
        pkg_ordering = get_package_dependency_list(pkg_tree)

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
