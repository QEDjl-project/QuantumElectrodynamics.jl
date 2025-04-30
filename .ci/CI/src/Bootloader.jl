include("./modules/Utils.jl")
include("./modules/GitLabTargetBranch.jl")
include("./modules/UnitTest.jl")
include("./modules/IntegTest.jl")

using IntegrationTests
using TOML
using Logging
using YAML
using ArgParse

"""
    output_paths()::Dict{String,String}

# Return

Returns a dictation of the possible output paths for different types of CI jobs. A command line
argument can be used to specify that the jobs should be written to a file instead of to stdout.
The key is the name of the option and the value is the help text for argparse.
"""
function output_paths()::Dict{String, String}
    return Dict(
        "output-cpu" => "Write CPU test job file to the given path. If not set, print job file content on stdout.",
        "output-gpu" => "Write GPU test job file to the given path. If not set, print job file content on stdout.",
        "output-unit-test-verify" => "Write the unit test verification job file to the given path. If not set, print job file content on stdout.",
    )
end

"""
    parse_commandline()::Dict{String, Any}

# Return

Parsed script arguments.
"""
function parse_commandline()::Dict{String, Any}
    s = ArgParseSettings()

    @add_arg_table s begin
        "--nocpu"
        help = "Disable the generation of CPU tests."
        action = :store_true
        "--cuda"
        help = "Enable the generation of CUDA tests."
        action = :store_true
        "--amdgpu"
        help = "Enable the generation of AMDGPU tests."
        action = :store_true
        "--nointeg"
        help = "Disable the generation of integration tests."
        action = :store_true
        "--target-branch"
        help = "If target branch is set, does not read the target branch from a GitHub Pull Request which is set via environment variable `CI_COMMIT_REF_NAME`."
        arg_type = String
        "--project-path"
        help = "Set the path to the package folder of the package to be tested. Can also be set via the environment variable `CI_PROJECT_DIR`."
        arg_type = String
    end

    # set options for optional output to file for the different test kinds
    for (arg_name, help_text) in output_paths()
        add_arg_table!(s, "--" * arg_name, Dict(:help => help_text, :arg_type => String))
    end

    return parse_args(s)
end

"""
    _get_config_from_arg_or_env_variable(
        arg_name::AbstractString,
        env_name::AbstractString,
        error_msg::AbstractString,
        args::Dict{String,Any},
    )::String

Checks the script argument and the environment variable. If the script argument is set, the value
is returned. If the argument is not set, the environment variable is checked and its value is
returned. If both are not set, an error message is displayed and the program is terminated with
error code 1.

# Args
- `arg_name::AbstractString`: Name of the argument.
- `env_name::AbstractString`: Name of the environment variable.
- `error_msg::AbstractString`: Error message if both are not set.
- `args::Dict{String,Any}`: Parsed arguments

# Return

Ether the value of the argument or the environment variable.
"""
function _get_config_from_arg_or_env_variable(
        arg_name::AbstractString,
        env_name::AbstractString,
        error_msg::AbstractString,
        args::Dict{String, Any},
    )::String
    if args[arg_name] !== nothing
        return args[arg_name]
    end

    if haskey(ENV, env_name)
        return ENV[env_name]
    end

    @error error_msg
    return exit(1)
end

"""
    get_target_branch(args::Dict{String,Any})::String

Get the target branch name. Can be set via argument `--target-branch` or environment variable
`CI_COMMIT_REF_NAME`.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return

Target branch name.
"""
function get_target_branch(args::Dict{String, Any})::String
    ci_commit_ref_name = _get_config_from_arg_or_env_variable(
        "target-branch",
        "CI_COMMIT_REF_NAME",
        "Target branch is not set via argument `--target-branch` or environment variable `CI_COMMIT_REF_NAME`",
        args,
    )

    return find_target_branch(ci_commit_ref_name)
end

"""
    get_project_path(args::Dict{String,Any})::String

Get the path of the project to be tested. Can be set via argument `--project-path` or environment
variable `CI_PROJECT_DIR`.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return

The path of the project to be tested.
"""
function get_project_path(args::Dict{String, Any})::String
    return _get_config_from_arg_or_env_variable(
        "project-path",
        "CI_PROJECT_DIR",
        "Path of the package to be tested is not set via argument `--project-path` or environment variable `CI_PROJECT_DIR`",
        args,
    )
end

"""
    _is_test(
        arg_name::AbstractString,
        arg_state::Bool,
        env_name::AbstractString,
        args::Dict{String,Any},
    )::Bool

Checks the command line argument and the environment variable whether test should be enabled or not.

# Args
- `arg_name::AbstractString`: Name of the argument.
- `arg_state::Bool`: Specify if setting argument should enable (true) or disable (false) the tests.
- `env_name::AbstractString`: Name of the environment variable.
- `args::Dict{String,Any}`: Parsed arguments

Return

True if enabled, false otherwise.
"""
function _is_test(
        arg_name::AbstractString,
        arg_state::Bool,
        env_name::AbstractString,
        args::Dict{String, Any},
    )::Bool
    if args[arg_name]
        return arg_state
    end

    if haskey(ENV, env_name)
        if ENV[env_name] == "ON"
            return true
        end
        if ENV[env_name] == "OFF"
            return false
        end
        @error "environment variable $env_name contains unknown value: $(ENV[env_name])\n" *
            "Only `ON` or `OFF` is allowed."
        exit(1)
    end

    return !arg_state
end

"""
    is_cpu_tests(args::Dict{String,Any})::Bool

Return true if CPU unit tests should be generated. CPU tests are enabled by default. Set argument
`--nocpu` to disable CPU unit tests or use the environment variable `CI_ENABLE_CPU_TESTS={"ON"|"OFF"}`.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return

True if CPU unit tests should be generated, false otherwise.
"""
function is_cpu_tests(args::Dict{String, Any})::Bool
    return _is_test("nocpu", false, "CI_ENABLE_CPU_TESTS", args)
end

"""
    is_cuda_tests(args::Dict{String,Any})::Bool

Check if CUDA GPU unit tests should be generated.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return

True, if CUDA GPU unit tests should be generated.
"""
function is_cuda_tests(args::Dict{String, Any})::Bool
    return _is_test("cuda", true, "CI_ENABLE_CUDA_TESTS", args)
end

"""
    is_amdgpu_tests(args::Dict{String,Any})::Bool

Check if AMDGPU GPU unit tests should be generated.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return

True, if AMDGPU GPU unit tests should be generated.
"""
function is_amdgpu_tests(args::Dict{String, Any})::Bool
    return _is_test("amdgpu", true, "CI_ENABLE_AMDGPU_TESTS", args)
end

"""
    is_integ_tests(args::Dict{String,Any})::Bool

Return true if integration tests should be generated. Integration tests are enabled by default. Set
argument `--nointeg` to disable this or use the environment variable
`CI_ENABLE_INTEG_TESTS={"ON"|"OFF"}`.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return

True if integration tests should be generated, false otherwise.
"""
function is_integ_tests(args::Dict{String, Any})::Bool
    return _is_test("nointeg", false, "CI_ENABLE_INTEG_TESTS", args)
end

"""
    get_package_name_version(package_path::AbstractString)::TestPackage

Extract package name and version from a Project.toml.

# Args
- `package_path::AbstractString`: Basepath of the package

# Returns

`TestPackage`: Contains name, versions and base path of the package.
"""
function get_package_name_version(package_path::AbstractString)::TestPackage
    project_toml_path = joinpath(package_path, "Project.toml")

    f = open(project_toml_path, "r")
    project_toml = TOML.parse(f)
    close(f)
    return TestPackage(project_toml["name"], project_toml["version"], package_path)
end

"""
    get_unit_test_julia_versions()::Vector{String}

Returns the test versions for the unit tests. If the environment variable CI_UNIT_TEST_VERSIONS is
not set, standard versions are returned. The value of the environment variable is a string with the
versions separated by commas. The versions are not tested for plausibility.

CI_UNIT_TEST_VERSIONS="1.11, 1.12, rc"

# Returns

- `Vector{String}`: Test versions for the unit tests

"""
function get_unit_test_julia_versions()::Vector{String}
    # CI_UNIT_TEST_VERSIONS
    if haskey(ENV, "CI_UNIT_TEST_VERSIONS")
        return strip.(split(ENV["CI_UNIT_TEST_VERSIONS"], ","))
    else
        return ["1.10", "1.11", "rc", "nightly"]
    end
end

"""
    get_unit_test_nightly_baseimage()::String

Returns container base image for nightly unit tests.

# Returns

`String`: Returns value of environment CI_UNIT_TEST_NIGHTLY_BASE_IMAGE if set. Otherwise default
value.
"""
function get_unit_test_nightly_baseimage()::String
    if haskey(ENV, "CI_UNIT_TEST_NIGHTLY_BASE_IMAGE")
        base_image = ENV["CI_UNIT_TEST_NIGHTLY_BASE_IMAGE"]
        @warn "use user defined base image for nightly unit test: $(base_image)"
        return base_image
    else
        return "debian:bookworm-slim"
    end
end

"""
    get_git_ci_tools_url_branch()::ToolsGitRepo

Returns the URL and the branch of the Git repository for the location where the CI tools are
located. The default is the dev branch at
https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git.
User-defined URL and branch can be defined with the environment variables CI_GIT_CI_TOOLS_URL
and CI_GIT_CI_TOOLS_BRANCH.

# Return

`ToolsGitRepo`: Contains git url and branch

"""
function get_git_ci_tools_url_branch()::ToolsGitRepo
    url = "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git"
    branch = "dev"

    if haskey(ENV, "CI_GIT_CI_TOOLS_URL")
        url = ENV["CI_GIT_CI_TOOLS_URL"]
        @warn "use custom git URL for CI tools: $(url)"
    end

    if haskey(ENV, "CI_GIT_CI_TOOLS_BRANCH")
        branch = ENV["CI_GIT_CI_TOOLS_BRANCH"]
        @warn "use custom git branch for CI tools: $(branch)"
    end

    return ToolsGitRepo(url, branch)
end

"""
Returns all unit tests configurations configured by script arguments and environment variables.
"""
function get_unit_test_configs(args::Dict{String, Any})::Vector{Tuple{UnitTestType, TestPlatform}}
    unit_test_types = Vector{Tuple{UnitTestType, TestPlatform}}()
    for julia_version in get_unit_test_julia_versions()
        if julia_version == "nightly" && is_cpu_tests(args)
            push!(
                unit_test_types,
                (
                    Nightly(get_unit_test_nightly_baseimage()),
                    CPU,
                )
            )

        elseif julia_version == "rc" && is_cpu_tests(args)
            push!(
                unit_test_types,
                (
                    ReleaseCandidate(),
                    CPU,
                )
            )
            continue
        else
            # normal, release Julia versions
            if is_cpu_tests(args)
                push!(
                    unit_test_types,
                    (
                        ReleaseVersion(julia_version),
                        CPU,
                    )
                )
            end

            if is_cuda_tests(args)
                push!(
                    unit_test_types,
                    (
                        ReleaseVersion(julia_version),
                        CUDA,
                    )
                )
            end

            if is_amdgpu_tests(args)
                push!(
                    unit_test_types,
                    (
                        ReleaseVersion(julia_version),
                        AMDGPU,
                    )
                )
            end
        end
    end
    return unit_test_types
end

"""
Print all test configurations via logger.

# Args

- `test_type_name::AbstractString`: Name of the test type
- `test_configs::Vector{Tuple{UnitTestType, TestPlatform}}`: Test configurations
"""
function _info_test_configs(
        test_type_name::AbstractString,
        test_configs::Vector{Tuple{UnitTestType, TestPlatform}}
    )
    output = test_type_name * ":\n"
    if isempty(test_configs)
        output *= "  no configurations"
    else
        for (test_type_name, platform) in test_configs
            output *= "  " * string(test_type_name) * " + " * string(platform) * "\n"
        end
    end
    return @info output
end

"""
    print_job_yaml(job_yaml::Dict, io::IO=stdout)

Prints to dict as human readable GitLab CI job yaml.

# Args
- `job_yaml::Dict`: Contains job descriptions.
- `io::IO=stdout`: Output for the rendered yaml.
"""
function print_job_yaml(job_yaml::Dict, io::IO = stdout)
    job_yaml_copy = deepcopy(job_yaml)

    # print all stages first
    if "stages" in keys(job_yaml_copy)
        YAML.write(io, "stages" => job_yaml["stages"])
        println(io, "")
        delete!(job_yaml_copy, "stages")
    end

    # print all unit tests with an empty line between
    for (top_level_object, top_level_object_value) in job_yaml_copy
        if startswith(top_level_object, "unit_test_julia_")
            YAML.write(io, top_level_object => top_level_object_value)
            println(io, "")
            delete!(job_yaml_copy, top_level_object)
        end
    end

    # print all integration tests with an empty line between
    for (top_level_object, top_level_object_value) in job_yaml_copy
        if startswith(top_level_object, "integration_test_")
            YAML.write(io, top_level_object => top_level_object_value)
            println(io, "")
            delete!(job_yaml_copy, top_level_object)
        end
    end

    # print everything, which was not already printed
    return if !isempty(job_yaml_copy)
        YAML.write(io, job_yaml_copy)
    end
end

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
    tests_configurations["unit"] = get_unit_test_configs(args)

    _info_test_configs("Unit tests", tests_configurations["unit"])

    is_integ = is_integ_tests(args)

    @info "integration tests are $(is_integ ? "enabled" : "disabled")"

    # if no tests should be generated, exit early
    if isempty(tests_configurations["unit"]) && !is_integ
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

    for (test_type_name, platform) in tests_configurations["unit"]
        if platform == CPU
            output_yaml = get(job_yamls, "output-cpu", job_yamls["stdout"])
        else
            output_yaml = get(job_yamls, "output-gpu", job_yamls["stdout"])
        end

        add_unit_test_job_yaml!(
            output_yaml,
            test_package,
            setup_dev_env,
            test_type_name,
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

    if !isempty(tests_configurations["unit"])
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
