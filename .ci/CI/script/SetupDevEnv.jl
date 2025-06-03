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

using CI
using Pkg

"""
    get_test_specific_custom_urls(::CI.TestType, urls::CI.CustomDependencyUrls)::Dict{String, String}

Return a reference to the dict containing the custom repository URLs for the given test type.

# Returns

The key is the name of the package and the value the custom URL.
"""
function get_test_specific_custom_urls end

get_test_specific_custom_urls(
    ::CI.UnitTest, urls::CI.CustomDependencyUrls
)::Dict{String, String} = urls.unit

get_test_specific_custom_urls(
    ::CI.IntegrationTest, urls::CI.CustomDependencyUrls
)::Dict{String, String} = urls.integ


if abspath(PROGRAM_FILE) == @__FILE__
    try
        if length(ARGS) < 1
            @error "Define path to target Project as first argument."
            exit(1)
        end

        Pkg.activate(ARGS[1])

        test_type::CI.TestType = CI.get_test_type_from_env_var()
        dry_run = CI.is_dry_run()

        if dry_run
            @warn "try-run mode enabled"
        end

        CI.check_environment_variables(test_type)

        custom_dependency_urls = CI.CustomDependencyUrls()
        if CI.is_pull_request(get(ENV, "CI_COMMIT_REF_NAME", ""))
            @info "Use Custom dependency URLs for test type: $(test_type)\n" *
                "Custom URL environment variable prefix: $(CI.get_test_type_env_var_prefix(test_type))"

            CI.append_custom_dependency_urls_from_git_message!(custom_dependency_urls)
            CI.append_custom_dependency_urls_from_env_var!(custom_dependency_urls)
        else
            @info "Disable custom URLs for QED dependencies"
        end

        test_specific_custom_urls = get_test_specific_custom_urls(
            test_type, custom_dependency_urls
        )
        if !isempty(test_specific_custom_urls)
            @info "Set custom URLs for dependencies: \n$(print_pkg_urls(test_specific_custom_urls))"
        end

        active_project_project_toml = Pkg.project().path

        compat_changes = CI.get_compat_changes()

        qed_path = mktempdir(; cleanup = false)

        pkg_tree = CI.build_qed_dependency_graph!(
            qed_path, compat_changes, test_specific_custom_urls
        )
        pkg_ordering = CI.get_package_dependency_list(pkg_tree)

        required_deps = CI.get_filtered_dependencies(
            r"^(QED*|QuantumElectrodynamics*)", active_project_project_toml
        )

        linear_pkg_ordering = CI.calculate_linear_dependency_ordering(
            pkg_ordering, required_deps
        )

        # remove all QED packages, because otherwise Julia tries to resolve the whole
        # environment if a package is added via Pkg.develop() which can cause circulare dependencies
        CI.remove_packages(linear_pkg_ordering, dry_run)

        CI.install_qed_dev_packages(
            linear_pkg_ordering,
            qed_path,
            ENV["CI_DEV_PKG_NAME"],
            ENV["CI_DEV_PKG_PATH"],
            compat_changes,
            dry_run
        )
    catch e
        # print debug information if uncatch error is thrown
        println(String(take!(debug_logger_io)))
        throw(e)
    end

    # print debug information if debug information is manually enabled
    @debug String(take!(debug_logger_io))
end
