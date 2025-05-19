include("modules/GitLabTargetBranch.jl")
include("modules/GenericTest.jl")
include("modules/UnitTest.jl")
include("modules/IntegTest.jl")
include("modules/Utils.jl")
include("modules/Bootloader/Arguments.jl")
include("modules/Bootloader/JobConfig.jl")
include("modules/Bootloader/JobPrinter.jl")

using IntegrationTests
using Logging

"""
    write_jobs!(job_yamls::Dict{String, Dict}, args::Dict{String, Any})

Write CI jobs to stdout or file. If a file output is empty, generate dummy job.

# Args
- `job_yamls::Dict{String, Dict}`: dict with CI jobs
- `args::Dict{String, Any}`: Script arguments to get output path for file output.
"""
function write_jobs!(job_yamls::Dict{String, Dict}, args::Dict{String, Any})
    if !isempty(job_yamls["stdout"])
        print_job_yaml(job_yamls["stdout"], stdout)
    end

    # If the output sink is a file for a child pipeline and there is no CI job defined,
    # add dummy job that the CI pipeline does not fail.
    for output_name in keys(job_yamls)
        if output_name != "stdout" && isempty(job_yamls[output_name])
            generate_dummy_job_yaml!(job_yamls[output_name])
        end
    end

    # if defined, write the different job yamls to the different output files
    for output_name in keys(output_paths())
        if haskey(job_yamls, output_name)
            open(args[output_name], "w") do out
                print_job_yaml(job_yamls[output_name], out)
            end
        end
    end

    return nothing
end

# use main function to avoid to define global variables
function main()
    args = parse_commandline()

    target_branch = get_target_branch(args)
    setup_dev_env::Bool = target_branch != "main"
    package_path = get_project_path(args)
    test_package = get_package_name_version(package_path)

    if "--pr" in ARGS && "--no-pr" in ARGS
        throw(ErrorException("It is not allowed to set the arguments --pr and --no-pr at the same time."))
    end

    # TOOD: move detecting if is a pull request from environment variable CI_COMMIT_REF_NAME
    # in an extra script
    # Workaround: check if environment variable `--pr` or `--no-pr` is set to override environment variable
    # CI_COMMIT_REF_NAME
    if haskey(ENV, "CI_QED_IS_PR")
        if ENV["CI_QED_IS_PR"] == "ON"
            pull_request = true
        elseif ENV["CI_QED_IS_PR"] == "OFF"
            pull_request = false
        else
            throw(ErrorException("Only \"ON\" or \"OFF\" allowed for CI_QED_IS_PR"))
        end
    elseif "--pr" in ARGS
        pull_request = true
    elseif "--no-pr" in ARGS
        pull_request = false
    else
        pull_request = is_pull_request(get(ENV, "CI_COMMIT_REF_NAME", ""))
    end

    @info "Test package name: $(test_package.name)"
    @info "Test package version: $(test_package.version)"
    @info "Test package path: $(test_package.path)"
    @info "Target branch: $(target_branch)"
    @info "Is pull request: $(pull_request)"
    @info "Unit test: setup dev environment: $(setup_dev_env)"

    tests_configurations = Dict()
    tests_configurations[UnitTest] = get_unit_test_configs(args)
    tests_configurations[IntegrationTest] = get_integration_test_configs(args, pull_request)

    info_test_configs(UnitTest, tests_configurations)
    info_test_configs(IntegrationTest, tests_configurations)

    # the "stdout" entry is required, otherwise
    # `get(job_yamls, "<name>", job_yamls["stdout"])` is not working
    # for unknown reason, job_yamls["stdout"] is accessed also in the case,
    # if the key exist
    job_yamls::Dict{String, Dict} = Dict("stdout" => Dict())
    for output_name in keys(output_paths())
        if !isnothing(args[output_name])
            job_yamls[output_name] = Dict()
        end
    end

    # if no tests should be generated, exit early
    if isempty(tests_configurations[UnitTest]) && isempty(tests_configurations[IntegrationTest])
        # Special case: The user defined file output for child pipelines.
        # It is not allowed to use an empty file for child pipeline. Therefore generated dummy jobs.
        if keys(job_yamls) != ["stdout"]
            write_jobs!(job_yamls, args)
        end
        exit(0)
    end


    tools_git_repo = get_git_ci_tools_url_branch()

    for (julia_version_type_name, platform) in tests_configurations[UnitTest]
        output_yaml = get_output_job_yaml(job_yamls, platform)
        add_unit_test_job_yaml!(
            output_yaml,
            test_package,
            setup_dev_env,
            julia_version_type_name,
            platform,
            tools_git_repo
        )
    end

    if !isempty(tests_configurations[IntegrationTest])
        custom_dependency_urls = CustomDependencyUrls()
        if target_branch != "main"
            append_custom_dependency_urls_from_git_message!(custom_dependency_urls)
            append_custom_dependency_urls_from_env_var!(custom_dependency_urls)
        end

        integration_test_package_names = get_qed_integration_test_package_names(
            test_package, custom_dependency_urls.integ
        )

        for (julia_version_type_name, platform) in tests_configurations[IntegrationTest]
            output_yaml = get_output_job_yaml(job_yamls, platform)

            julia_version_prefix = "_" * replace(julia_version_type_name.version, "." => "_")

            if platform == CUDA()
                julia_version_prefix = "_cuda" * julia_version_prefix
            end

            if platform == AMDGPU()
                julia_version_prefix = "_amdgpu" * julia_version_prefix
            end

            for integration_package_name in integration_test_package_names
                integration_test_repo = GitRepoAddress(
                    get(
                        custom_dependency_urls.integ,
                        integration_package_name,
                        "https://github.com/QEDjl-project/$(integration_package_name).jl.git"
                    )
                )

                add_integration_test_job_yaml!(
                    output_yaml,
                    test_package,
                    true, # setup dev env
                    false, # can fail
                    integration_package_name * julia_version_prefix,
                    integration_test_repo,
                    julia_version_type_name,
                    platform,
                    tools_git_repo
                )

                # Handles the case of merging in the main branch. If we want to merge in the main branch,
                # we do it because we want to publish the package. Therefore, we need to be sure that there
                # is an existing version of the dependent QED packages that works with the new version of
                # the package we want to release. The integration tests are tested against the development
                # branch and the release version.
                #  - The dev branch version must pass, as this means that the latest version of the other
                #    QED packages is compatible with our release version.
                #  - The release version integration tests may or may not pass.
                #    1. If all of these pass, we will not need to increase the minor version of this package.
                #    2. If they do not all pass, the minor version must be increased and the failing packages
                #    must also be released later with an updated compat entry.
                #    In either case the release can proceed, as the released packages will continue to work
                #    because of their current compat entries.
                if target_branch == "main" && pull_request
                    integration_test_release_repo = GitRepoAddress(
                        "https://github.com/QEDjl-project/$(integration_package_name).jl.git",
                        "main"
                    )

                    add_integration_test_job_yaml!(
                        output_yaml,
                        test_package,
                        false, # setup dev env
                        true, # can fail
                        integration_package_name * julia_version_prefix * "_release_test",
                        integration_test_release_repo,
                        julia_version_type_name,
                        platform,
                        tools_git_repo
                    )
                end
            end
        end
    end

    if !isempty(tests_configurations[UnitTest])
        add_unit_test_verify_job_yaml!(
            get(job_yamls, "output-unit-test-verify", job_yamls["stdout"]),
            setup_dev_env,
            tools_git_repo,
        )
    end

    write_jobs!(job_yamls, args)
    return exit(0)
end

# TODO: if Julia 1.11 is minimum, replace it it with: function (@main)(args)
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
