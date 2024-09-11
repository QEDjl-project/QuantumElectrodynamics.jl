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
    project_dependencies=Pkg.dependencies(),
)::AbstractVector{Pkg.API.PackageInfo}
    deps = Vector{Pkg.API.PackageInfo}(undef, 0)
    for (uuid, dep) in project_dependencies
        if _match_package_filter(name_filter, dep.name)
            push!(deps, dep)
        end
    end
    return deps
end

"""
    set_dev_dependencies(
        dependencies::AbstractVector{Pkg.API.PackageInfo},
        custom_urls::AbstractDict{String,String}=Dict{String,String}(),
    )

Set all dependencies to the development version, if they are not already development versions.
The dict custom_urls takes as key a dependency name and a URL as value. If a dependency is in
custom_urls, it will use the URL as development version. If the dependency does not exist in
custom_urls, it will set the URL https://github.com/QEDjl-project/<dependency_name>.jl
"""
function set_dev_dependencies(
    dependencies::AbstractVector{Pkg.API.PackageInfo},
    custom_urls::AbstractDict{String,String}=Dict{String,String}(),
)
    for dep in dependencies
        # if tree_hash is nothing, it is already a dev version
        if !isnothing(dep.tree_hash)
            if haskey(custom_urls, dep.name)
                Pkg.develop(; url=custom_urls[dep.name])
            else
                Pkg.develop(; url="https://github.com/QEDjl-project/$(dep.name).jl")
            end
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    deps = get_filtered_dependencies(r"^(QED*|QuantumElectrodynamics*)")
    set_dev_dependencies(deps)
end
