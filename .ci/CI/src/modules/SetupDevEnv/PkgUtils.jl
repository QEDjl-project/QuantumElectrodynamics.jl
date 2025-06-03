"""
    remove_packages(dependencies::Vector{String})

Remove the given packages from the active environment.

# Args
- `dependencies::Vector{String}`: Packages to remove
- `dry_run::Bool`: If true, display only logging messages and do not remove packages.
"""
function remove_packages(dependencies::Vector{String}, dry_run::Bool)
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
            if !dry_run
                Pkg.rm(pkg)
            end
        catch
            @warn "tried to remove uninstalled package $(pkg)"
        end
    end
    return
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
    - `dry_run::Bool`: If true, display only logging messages and do not install packages.
"""
function install_qed_dev_packages(
        pkg_to_install::Vector{String},
        qed_path,
        dev_package_name::AbstractString,
        dev_package_path::AbstractString,
        compat_changes::Dict{String, String},
        dry_run::Bool
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
            if !dry_run
                Pkg.develop(; path = dev_package_path)
            end
        else
            project_path = joinpath(qed_path, pkg)

            for (compat_name, compat_version) in compat_changes
                set_compat_helper(compat_name, compat_version, project_path)
            end

            @info "install dependency package: $(project_path)"
            if !dry_run
                Pkg.develop(; path = project_path)
            end
        end
    end
    return
end
