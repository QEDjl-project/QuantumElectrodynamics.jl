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
    parse_commandline()::Dict{String, Any}

# Return

Parsed script arguments.
"""
function parse_commandline()::Dict{String,Any}
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
        "--target-branch"
        help = "If target branch is set, does not read the target branch from a GitHub Pull Request which is set via environment variable `CI_COMMIT_REF_NAME`."
        arg_type = String
        "--project-path"
        help = "Set the path to the package folder of the package to be tested. Can also be set via the environment variable `CI_PROJECT_DIR`."
        arg_type = String
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
    args::Dict{String,Any},
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
function get_target_branch(args::Dict{String,Any})::String
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
function get_project_path(args::Dict{String,Any})::String
    return _get_config_from_arg_or_env_variable(
        "project-path",
        "CI_PROJECT_DIR",
        "Path of the package to be tested is not set via argument `--project-path` or environment variable `CI_PROJECT_DIR`",
        args,
    )
end

"""
    is_cpu_tests(args::Dict{String,Any})::Bool

Returns true, if CPU unit tests should be generated. CPU tests are enabled by default. Set argument
`--nocpu` to disable it or use the environment variable `CI_ENABLE_CPU_TESTS={"ON"|"OFF"}`.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return 

True, if CPU unit tests should be generated.
"""
function is_cpu_tests(args::Dict{String,Any})::Bool
    # if flag is set, disable CPU tests
    # otherwise check environment variable
    if args["nocpu"]
        return false
    end

    if haskey(ENV, "CI_ENABLE_CPU_TESTS")
        if ENV["CI_ENABLE_CPU_TESTS"] == "ON"
            return true
        end
        if ENV["CI_ENABLE_CPU_TESTS"] == "OFF"
            return false
        end
        @error "environment variable CI_ENABLE_CPU_TESTS contains unknown value: $(ENV["CI_ENABLE_CPU_TESTS"])\n" *
            "Only `ON` or `OFF` is allowed."
        exit(1)
    end

    # if no argument or environment variable is set, enable CPU tests
    return true
end

"""
    _is_gpu_tests(
        arg_name::AbstractString, env_name::AbstractString, args::Dict{String,Any}
    )::Bool

Return if gpu unit tests should be generated depending on a commandline argument or environment 
variable.

# Args
- `arg_name::AbstractString`: Name of the argument.
- `env_name::AbstractString`: Name of the environment variable.
- `args::Dict{String,Any}`: Parsed arguments

Return

True if enabled or false if not. Default is false.
"""
function _is_gpu_tests(
    arg_name::AbstractString, env_name::AbstractString, args::Dict{String,Any}
)::Bool
    if args[arg_name]
        return true
    end

    if haskey(ENV, env_name)
        if ENV[env_name] == "ON"
            return true
        end
        if ENV[env_name] == "OFF"
            return false
        end
        @error "environment variable env_name contains unknown value: $(ENV["env_name"])\n" *
            "Only `ON` or `OFF` is allowed."
        exit(1)
    end

    # if no argument or environment variable is set, disable GPU tests
    return false
end

"""
    is_cuda_tests(args::Dict{String,Any})::Bool

Check if CUDA GPU unit tests should be generated.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return 

True, if CUDA GPU unit tests should be generated.
"""
function is_cuda_tests(args::Dict{String,Any})::Bool
    return _is_gpu_tests("cuda", "CI_ENABLE_CUDA_TESTS", args)
end

"""
    is_amdgpu_tests(args::Dict{String,Any})::Bool

Check if AMDGPU GPU unit tests should be generated.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return 

True, if AMDGPU GPU unit tests should be generated.
"""
function is_amdgpu_tests(args::Dict{String,Any})::Bool
    return _is_gpu_tests("amdgpu", "CI_ENABLE_AMDGPU_TESTS", args)
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
    print_job_yaml(job_yaml::Dict, io::IO=stdout)

Prints to dict as human readable GitLab CI job yaml.

# Args
- `job_yaml::Dict`: Contains job descriptions.
- `io::IO=stdout`: Output for the rendered yaml.
"""
function print_job_yaml(job_yaml::Dict, io::IO=stdout)
    job_yaml_copy = deepcopy(job_yaml)

    # print all stages first
    if "stages" in keys(job_yaml_copy)
        YAML.write(io, "stages" => job_yaml["stages"])
        println()
        delete!(job_yaml_copy, "stages")
    end

    # print all unit tests with an empty line between
    for (top_level_object, top_level_object_value) in job_yaml_copy
        if startswith(top_level_object, "unit_test_julia_")
            YAML.write(io, top_level_object => top_level_object_value)
            println()
            delete!(job_yaml_copy, top_level_object)
        end
    end

    # print all integration tests with an empty line between
    for (top_level_object, top_level_object_value) in job_yaml_copy
        if startswith(top_level_object, "integration_test_")
            YAML.write(io, top_level_object => top_level_object_value)
            println()
            delete!(job_yaml_copy, top_level_object)
        end
    end

    # print everything, which was not already printed
    if !isempty(job_yaml_copy)
        YAML.write(io, job_yaml_copy)
    end
end

"""
    _info_enabled_tests(test_name::AbstractString, state::Bool)

Helper function to display of unit tests are generated.

# Args
- `test_name::AbstractString`: Name of the unit test category
- `state::Bool`: Is enabled or not
"""
function _info_enabled_tests(test_name::AbstractString, state::Bool)
    @info "$(test_name) unit tests are $(state ? "enabled" : "disabled")"
end

# use main function to avoid to define global variables
function main()
    args = parse_commandline()

    target_branch = get_target_branch(args)
    package_path = get_project_path(args)
    test_package = get_package_name_version(package_path)

    @info "Test package name: $(test_package.name)"
    @info "Test package version: $(test_package.version)"
    @info "Test package path: $(test_package.path)"
    @info "PR target branch: $(target_branch)"

    is_cpu = is_cpu_tests(args)
    is_cuda = is_cuda_tests(args)
    is_amdgpu = is_amdgpu_tests(args)

    _info_enabled_tests("CPU", is_cpu)
    _info_enabled_tests("CUDA", is_cuda)
    _info_enabled_tests("AMDGPU", is_amdgpu)

    is_unit_tests = is_cpu || is_cuda || is_amdgpu
    @info "unit tests are $(is_unit_tests ? "enabled" : "disabled")"

    unit_test_julia_versions = get_unit_test_julia_versions()
    @info "Julia versions for the unit tests: $(unit_test_julia_versions)"

    job_yaml = Dict()

    tools_git_repo = get_git_ci_tools_url_branch()

    if is_cpu
        add_unit_test_job_yaml!(
            job_yaml,
            test_package,
            unit_test_julia_versions,
            target_branch,
            CPU,
            tools_git_repo,
            get_unit_test_nightly_baseimage(),
        )
    end

    if is_cuda || is_amdgpu
        for version in ["rc", "nightly"]
            if version in unit_test_julia_versions
                @info "Remove unit test version $(version) for GPU tests"
                filter!(v -> v != version, unit_test_julia_versions)
            end
        end
    end

    if is_cuda
        @info "Generate CUDA unit tests"
        add_unit_test_job_yaml!(
            job_yaml,
            test_package,
            unit_test_julia_versions,
            target_branch,
            CUDA,
            tools_git_repo,
        )
    end

    if is_amdgpu
        @info "Generate AMDGPU unit tests"

        add_unit_test_job_yaml!(
            job_yaml,
            test_package,
            unit_test_julia_versions,
            target_branch,
            AMDGPU,
            tools_git_repo,
        )
    end

    add_integration_test_job_yaml!(job_yaml, test_package, target_branch, tools_git_repo)

    if is_unit_tests
        add_unit_test_verify_job_yaml!(job_yaml, target_branch, tools_git_repo)
    end

    return print_job_yaml(job_yaml)
end

# TODO: if Julia 1.11 is minimum, replace it it with: function (@main)(args)
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
