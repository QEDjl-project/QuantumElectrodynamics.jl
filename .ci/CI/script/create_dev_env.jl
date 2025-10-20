"""
Clones all repositories of the QED ecosystem into a folder and sets it to the Dev branch.
It then sets up the Julia environment for each package.
It uses the locally cloned repositories for the QED dependencies.
"""

using CI
using ArgParse
using Pkg

"""
    parse_commandline()::Dict{String, Any}

# Return

Parsed script arguments.
"""
function parse_commandline()::Dict{String, Any}
    s = ArgParseSettings()
    s.description = "Clones all dev branch versions of the complete QED ecosystem and setup the dev branch environment of each package."

    @add_arg_table! s begin
        "project-path-prefix"
        help = "Folder where all repositories are cloned in."
        arg_type = String
        required = true
    end

    return parse_args(s)
end

if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_commandline()
    qed_prefix_path = args["project-path-prefix"]

    compat_changes = CI.get_compat_changes()
    # search for all QED packages
    pkg_tree = CI.build_qed_dependency_graph!(
        qed_prefix_path, compat_changes
    )
    # order the QED packages by it dependencies to each other
    pkg_ordering = CI.get_package_dependency_list(pkg_tree)

    for pkg_level in pkg_ordering
        for pkg in pkg_level
            pkg_path = joinpath(qed_prefix_path, pkg)
            @info "Setup dev environment for package $(pkg)\n$(pkg_path)"

            required_deps = CI.get_filtered_dependencies(
                CI.get_qed_filter_regex(), joinpath(pkg_path, "Project.toml")
            )
            linear_pkg_ordering = CI.calculate_linear_dependency_ordering(
                pkg_ordering, required_deps
            )
            Pkg.activate(pkg_path)

            # remove all QED packages, because otherwise Julia tries to resolve the whole
            # environment if a package is added via Pkg.develop() which can cause circular dependencies
            CI.remove_packages(linear_pkg_ordering, false)

            CI.install_qed_dev_packages(
                linear_pkg_ordering,
                qed_prefix_path,
                pkg,
                pkg_path,
                compat_changes,
                false,
            )
        end
    end

    for pkg_level in pkg_ordering
        for pkg in pkg_level
            pkg_path = joinpath(qed_prefix_path, pkg)
            # reset Project.toml to dev branch version, because uninstalling QED packages change it
            run(`git -C $(pkg_path) checkout -- Project.toml`)
        end
    end
end
