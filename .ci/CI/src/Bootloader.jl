include("./modules/Utils.jl")
include("./modules/Bootloader/Arguments.jl")
include("./modules/Bootloader/JobConfig.jl")
include("./modules/Bootloader/JobPrinter.jl")
include("./modules/GitLabTargetBranch.jl")
include("./modules/UnitTest.jl")
include("./modules/IntegTest.jl")

using IntegrationTests
using Logging

# use main function to avoid to define global variables
function main()
    args = parse_commandline()

    target_branch = get_target_branch(args)
    setup_dev_env::Bool = target_branch != "main"
    package_path = get_project_path(args)
    test_package = get_package_name_version(package_path)

    @info "Test package name: $(test_package.name)"
    @info "Test package version: $(test_package.version)"
    @info "Test package path: $(test_package.path)"
    @info "PR target branch: $(target_branch)"
    @info "Setup dev environment: $(setup_dev_env)"

    tests_configurations = Dict()
    tests_configurations[UnitTest] = get_unit_test_configs(args)

    info_test_configs(UnitTest, tests_configurations)

    is_integ = is_integ_tests(args)

    @info "integration tests are $(is_integ ? "enabled" : "disabled")"

    # if no tests should be generated, exit early
    if isempty(tests_configurations[UnitTest]) && !is_integ
        exit(0)
    end

    if !is_cpu_tests(args) && !is_integ && !isnothing(args["output-cpu"])
        @error "The output path for CPU tests is set, but CPU tests are not enabled"
        exit(1)
    end

    if !is_cuda_tests(args) && !is_amdgpu_tests(args) && !isnothing(args["output-gpu"])
        @error "The output path for GPU tests is set, but GPU tests are not enabled"
        exit(1)
    end

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

    tools_git_repo = get_git_ci_tools_url_branch()

    for (julia_version_type_name, platform) in tests_configurations[UnitTest]
        if platform == CPU
            output_yaml = get(job_yamls, "output-cpu", job_yamls["stdout"])
        else
            output_yaml = get(job_yamls, "output-gpu", job_yamls["stdout"])
        end

        add_unit_test_job_yaml!(
            output_yaml,
            test_package,
            setup_dev_env,
            julia_version_type_name,
            platform,
            tools_git_repo
        )
    end

    if is_integ
        custom_dependency_urls = CustomDependencyUrls()
        append_custom_dependency_urls_from_git_message!(custom_dependency_urls)
        append_custom_dependency_urls_from_env_var!(custom_dependency_urls)

        add_integration_test_job_yaml!(
            get(job_yamls, "output-cpu", job_yamls["stdout"]),
            test_package,
            target_branch,
            custom_dependency_urls.integ,
            tools_git_repo,
        )
    end

    if !isempty(tests_configurations[UnitTest])
        add_unit_test_verify_job_yaml!(
            get(job_yamls, "output-unit-test-verify", job_yamls["stdout"]),
            setup_dev_env,
            tools_git_repo,
        )
    end

    if !isempty(job_yamls["stdout"])
        print_job_yaml(job_yamls["stdout"], stdout)
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

# TODO: if Julia 1.11 is minimum, replace it it with: function (@main)(args)
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
