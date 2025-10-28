using ArgParse
using TOML

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
        "output-verify" => "Write verification job file to the given path. If not set, print job file content on stdout.",
    )
end

"""
    get_output_job_yaml(job_yamls::Dict, platform::TestPlatform)

The output sink is returned depending on the platform type. For CPU it is “output-cpu” and for CUDA
or AMDGPU it is “output-gpu”. If a key in `job_yaml` is not set because the generated code is not
to be written to a file, the sink `stdout` is returned.

# Args

- `job_yaml::Dict`: The job dict with with the different output sinks.
- `platform::TestPlatform`: Depending on the platform, select the output sink.

# Returns

Output sink (::Dict)
"""
function get_output_job_yaml(job_yaml::Dict, platform::TestPlatform)::Dict
    if !haskey(job_yaml, "stdout")
        throw(ErrorException("job_yamls has no key stdout"))
    end

    if platform == CPU()
        return get(job_yaml, "output-cpu", job_yaml["stdout"])
    elseif (platform == CUDA() || platform == AMDGPU())
        return get(job_yaml, "output-gpu", job_yaml["stdout"])
    else
        throw(ErrorException("Unknown platform: $(platform)"))
    end
end

"""
    parse_commandline()::Dict{String, Any}

# Return

Parsed script arguments.
"""
function parse_commandline()::Dict{String, Any}
    s = ArgParseSettings()

    @add_arg_table! s begin
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
        help = "On Pull Request, the target branch is the branch where changes will be merged in.\n" *
            "Otherwise it is the branch where the tests are running on.\n" *
            "If target branch is set, does not read the target branch from a GitHub Pull Request which is set via environment variable `CI_QED_TARGET_BRANCH`."
        arg_type = String
        "--pr"
        help = "Generate jobs for a pull request. If not set, the value of the environment variable CI_QED_IS_PR decides if it is pull request or not."
        action = :store_true
        "--project-path"
        help = "Set the path to the package folder of the package to be tested. Can also be set via the environment variable `CI_PROJECT_DIR`."
        arg_type = String
        "--code-coverage"
        help = "Enable code coverage in Unit tests. Requires --target-branch and --commit-hash. --pr-number is required if --pr is set."
        action = :store_true
        "--feature-branch"
        help = "The feature branch names the branch in a pull request, where changes coming from.\n" *
            "If the CI runs on a non-pull request, the feature branch and target branch are equal.\n" *
            "If feature branch is set, does not read the target branch from a GitHub Pull Request which is set via environment variable `CI_QED_FEATURE_BRANCH`."
        arg_type = String
        "--commit-hash"
        help = "Git commit hash of the commit to be tested."
        arg_type = String
        "--pr-number"
        help = "Pull request number."
        arg_type = String
    end

    # set options for optional output to file for the different test kinds
    for (arg_name, help_text) in output_paths()
        add_arg_table!(s, "--" * arg_name, Dict(:help => help_text, :arg_type => String))
    end

    return parse_args(s)
end

"""
    exit_error_handler(error_msg::AbstractString)

A error handler handles an error. This error displays the error message and exit the 
application with error code 1.

# Args
- `error_msg::AbstractString`: Error message.
"""
function exit_error_handler(error_msg::AbstractString)
    @error error_msg
    return exit(1)
end

"""
    runtime_error_handler(error_msg::AbstractString)

A error handler handles an error. This error throws an ErrorException.

# Args
- `error_msg::AbstractString`: Error message.
"""
function runtime_error_handler(error_msg::AbstractString)
    throw(ErrorException(error_msg))
end

"""
    _get_config_from_arg_or_env_variable(
        arg_name::AbstractString,
        env_name::AbstractString,
        error_msg::AbstractString,
        args::Dict{String,Any},
        error_handler,
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
- `error_handler`: Error handler which is called in the case of an error.

# Return

Ether the value of the argument or the environment variable.
"""
function _get_config_from_arg_or_env_variable(
        arg_name::AbstractString,
        env_name::AbstractString,
        error_msg::AbstractString,
        args::Dict{String, Any},
        error_handler
    )::String
    if args[arg_name] !== nothing
        return args[arg_name]
    end

    if haskey(ENV, env_name)
        return ENV[env_name]
    end

    error_handler(error_msg)
end

"""
    get_target_branch(args::Dict{String,Any}, error_handler)::String

Get the target branch name. Can be set via argument `--target-branch` or environment variable
`CI_QED_TARGET_BRANCH`.

# Args
- `args::Dict{String,Any}`: Parsed arguments
- `error_handler`: Error handler which is called in the case of an error.

# Return

Target branch name.
"""
function get_target_branch(args::Dict{String, Any}, error_handler = exit_error_handler)::String
    ci_commit_ref_name = _get_config_from_arg_or_env_variable(
        "target-branch",
        "CI_QED_TARGET_BRANCH",
        "Target branch is not set via argument `--target-branch` or environment variable `CI_QED_TARGET_BRANCH`",
        args,
        error_handler
    )

    return find_target_branch(ci_commit_ref_name)
end

"""
    get_project_path(args::Dict{String,Any})::String

Get the path of the project to be tested. Can be set via argument `--project-path` or environment
variable `CI_PROJECT_DIR`.

# Args
- `args::Dict{String,Any}`: Parsed arguments
- `error_handler`: Error handler which is called in the case of an error.

# Return

The path of the project to be tested.
"""
function get_project_path(args::Dict{String, Any}, error_handler = exit_error_handler)::String
    return _get_config_from_arg_or_env_variable(
        "project-path",
        "CI_PROJECT_DIR",
        "Path of the package to be tested is not set via argument `--project-path` or environment variable `CI_PROJECT_DIR`",
        args,
        error_handler
    )
end

"""
    get_feature_branch(args::Dict{String,Any}, error_handler)::String

Get the feature branch name. Can be set via argument `--feature-branch` or environment variable
`CI_QED_FEATURE_BRANCH`.

# Args
- `args::Dict{String,Any}`: Parsed arguments
- `error_handler`: Error handler which is called in the case of an error.

# Return

Feature branch name.
"""
function get_feature_branch(args::Dict{String, Any}, error_handler = exit_error_handler)::String
    return _get_config_from_arg_or_env_variable(
        "feature-branch",
        "CI_QED_FEATURE_BRANCH",
        "Feature branch is not set via argument `--feature-branch` or environment variable `CI_QED_FEATURE_BRANCH`",
        args,
        error_handler
    )
end

"""
    get_commit_hash(args::Dict{String,Any}, error_handler)::String

Get the git commit hash. Can be set via argument `--commit-hash"` or environment variable
`CI_QED_COMMIT_HASH`.

# Args
- `args::Dict{String,Any}`: Parsed arguments
- `error_handler`: Error handler which is called in the case of an error.

# Return

Git commit hash.
"""
function get_commit_hash(args::Dict{String, Any}, error_handler = exit_error_handler)::String
    return _get_config_from_arg_or_env_variable(
        "commit-hash",
        "CI_QED_COMMIT_HASH",
        "Git commit hash is not set via argument `--commit-hash` or environment variable `CI_QED_COMMIT_HASH`",
        args,
        error_handler
    )
end

"""
    get_pr_number(args::Dict{String,Any}, error_handler)::String

Get the pull request number. Can be set via argument `--pr-number"` or environment variable
`CI_QED_PR_NUMBER`.

# Args
- `args::Dict{String,Any}`: Parsed arguments
- `error_handler`: Error handler which is called in the case of an error.

# Return

Git commit hash.
"""
function get_pr_number(args::Dict{String, Any}, error_handler = exit_error_handler)::Integer
    return parse(
        Int64, _get_config_from_arg_or_env_variable(
            "pr-number",
            "CI_QED_PR_NUMBER",
            "Pull request number is not set via argument `--pr-number` or environment variable `CI_QED_PR_NUMBER`",
            args,
            error_handler
        )
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
`--nocpu` to disable CPU unit tests or use the environment variable `CI_QED_ENABLE_CPU_TESTS={"ON"|"OFF"}`.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return

True if CPU unit tests should be generated, false otherwise.
"""
function is_cpu_tests(args::Dict{String, Any})::Bool
    return _is_test("nocpu", false, "CI_QED_ENABLE_CPU_TESTS", args)
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
    return _is_test("cuda", true, "CI_QED_ENABLE_CUDA_TESTS", args)
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
    return _is_test("amdgpu", true, "CI_QED_ENABLE_AMDGPU_TESTS", args)
end

"""
    is_integ_tests(args::Dict{String,Any})::Bool

Return true if integration tests should be generated. Integration tests are enabled by default. Set
argument `--nointeg` to disable this or use the environment variable
`CI_QED_ENABLE_INTEG_TESTS={"ON"|"OFF"}`.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return

True if integration tests should be generated, false otherwise.
"""
function is_integ_tests(args::Dict{String, Any})::Bool
    return _is_test("nointeg", false, "CI_QED_ENABLE_INTEG_TESTS", args)
end

"""
    is_pull_request(args::Dict{String,Any})::Bool

Return true if tests the are generated for a pull request. Disabled by default. Set argument `--pr`
to disable this or use the environment variable `CI_QED_IS_PR={"ON"|"OFF"}`.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return

True if the tests are generated for a pull request, false otherwise.
"""
function is_pull_request(args::Dict{String, Any})::Bool
    return _is_test("pr", true, "CI_QED_IS_PR", args)
end

"""
    is_code_coverage(args::Dict{String,Any})::Bool

Return true if code coverage is enabled. Disabled by default. Set argument `--code-coverage`
to enable this or use the environment variable `CI_QED_IS_CODE_COVERAGE={"ON"|"OFF"}`.

# Args
- `args::Dict{String,Any}`: Parsed arguments

# Return

True if the code coverage script code should be generated, false otherwise.
"""
function is_code_coverage(args::Dict{String, Any})::Bool
    return _is_test("code-coverage", true, "CI_QED_IS_CODE_COVERAGE", args)
end

"""
    get_unit_test_julia_versions()::Vector{String}

Returns the test versions for the unit tests. If the environment variable CI_QED_UNIT_TEST_VERSIONS is
not set, standard versions are returned. The value of the environment variable is a string with the
versions separated by commas. The versions are not tested for plausibility.

CI_QED_UNIT_TEST_VERSIONS="1.11, 1.12, rc"

# Returns

- `Vector{String}`: Test versions for the unit tests

"""
function get_unit_test_julia_versions()::Vector{String}
    # CI_QED_UNIT_TEST_VERSIONS
    if haskey(ENV, "CI_QED_UNIT_TEST_VERSIONS")
        return strip.(split(ENV["CI_QED_UNIT_TEST_VERSIONS"], ","))
    else
        return ["1.10", "1.11", "1.12", "rc", "nightly"]
    end
end
"""
    get_integration_test_julia_versions()::Vector{String}

Returns the test versions for the integration tests. If the environment variable
CI_QED_INTEG_TEST_VERSIONS is not set, standard versions are returned. The value of the environment
variable is a string with the versions separated by commas. The versions are not tested for
plausibility.

CI_QED_INTEG_TEST_VERSIONS="1.10"

# Returns

- `Vector{String}`: Test versions for the integration tests

"""
function get_integration_test_julia_versions()::Vector{String}
    # CI_QED_UNIT_TEST_VERSIONS
    if haskey(ENV, "CI_QED_INTEG_TEST_VERSIONS")
        return strip.(split(ENV["CI_QED_INTEG_TEST_VERSIONS"], ","))
    else
        return ["1.10"]
    end
end

"""
    get_unit_test_nightly_baseimage()::String

Returns container base image for nightly unit tests.

# Returns

`String`: Returns value of environment CI_QED_UNIT_TEST_NIGHTLY_BASE_IMAGE if set. Otherwise default
value.
"""
function get_unit_test_nightly_baseimage()::String
    if haskey(ENV, "CI_QED_UNIT_TEST_NIGHTLY_BASE_IMAGE")
        base_image = ENV["CI_QED_UNIT_TEST_NIGHTLY_BASE_IMAGE"]
        @warn "use user defined base image for nightly unit test: $(base_image)"
        return base_image
    else
        return "debian:bookworm-slim"
    end
end

"""
    get_git_ci_tools_url_branch()::GitRepoAddress

Returns the URL and the branch of the Git repository for the location where the CI tools are
located. The default is the dev branch at
https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git.
User-defined URL and branch can be defined with the environment variables CI_QED_GIT_CI_TOOLS_URL
and CI_QED_GIT_CI_TOOLS_BRANCH.

# Return

`GitRepoAddress`: Contains git url and branch

"""
function get_git_ci_tools_url_branch()::GitRepoAddress
    url = "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git"
    branch = "dev"

    if haskey(ENV, "CI_QED_GIT_CI_TOOLS_URL")
        url = ENV["CI_QED_GIT_CI_TOOLS_URL"]
        @warn "use custom git URL for CI tools: $(url)"
    end

    if haskey(ENV, "CI_QED_GIT_CI_TOOLS_BRANCH")
        branch = ENV["CI_QED_GIT_CI_TOOLS_BRANCH"]
        @warn "use custom git branch for CI tools: $(branch)"
    end

    return GitRepoAddress(url, branch)
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
