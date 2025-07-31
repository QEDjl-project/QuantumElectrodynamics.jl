using ArgParse
using CI
using Pkg

if abspath(PROGRAM_FILE) == @__FILE__
    s = ArgParseSettings("Script to setup and QED project with develop dependencies.")

    @add_arg_table! s begin
        "-d"
        help = "Directory into which all repositories are cloned. Must exist."
        arg_type = String
        required = true
        "-p"
        help = "QED project to be setup."
        arg_type = String
        required = true
    end

    args = parse_args(s)
    repo_prefix = args["d"]
    project_name = args["p"]

    # remove .jl from package name, if was set
    if endswith(project_name, ".jl")
        project_name = project_name[1:(end - 3)]
    end

    if !isdir(repo_prefix)
        @error "$(repo_prefix) is not a directory."
        exit(1)
    end

    compat_changes = Dict{String, String}()
    pkg_tree = CI.build_qed_dependency_graph!(
        repo_prefix,
        compat_changes,
        Dict{String, String}(),
        project_name
    )

    project_path = joinpath(repo_prefix, project_name)
    Pkg.activate(project_path)

    pkg_ordering = CI.get_package_dependency_list(pkg_tree, "", project_name)
    required_deps = CI.get_filtered_dependencies(r"^(QED*|QuantumElectrodynamics*)", Pkg.project().path)

    linear_pkg_ordering = CI.calculate_linear_dependency_ordering(
        pkg_ordering, required_deps
    )

    println(linear_pkg_ordering)

    for stage in pkg_ordering[1:(end - 1)]

    end
    CI.remove_packages(linear_pkg_ordering, false)
    CI.install_qed_dev_packages(
        linear_pkg_ordering,
        repo_prefix,
        project_name,
        project_path,
        compat_changes,
        false
    )
end
