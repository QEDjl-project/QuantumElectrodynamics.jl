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
        "output-unit-test-verify" => "Write the unit test verification job file to the given path. If not set, print job file content on stdout.",
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
        "--pr"
        help = "Generate jobs for a pull request. If not set, the value of the environment variable CI_COMMIT_REF_NAME decides if it is pull request or not."
        action = :store_true
        "--no-pr"
        help = "Generate jobs for a normal commit. If not set, the value of the environment variable CI_COMMIT_REF_NAME decides if it is pull request or not."
        action = :store_true
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
    get_integration_test_julia_versions()::Vector{String}

Returns the test versions for the integration tests. If the environment variable
CI_INTEG_TEST_VERSIONS is not set, standard versions are returned. The value of the environment
variable is a string with the versions separated by commas. The versions are not tested for
plausibility.

CI_INTEG_TEST_VERSIONS="1.10"

# Returns

- `Vector{String}`: Test versions for the integration tests

"""
function get_integration_test_julia_versions()::Vector{String}
    # CI_UNIT_TEST_VERSIONS
    if haskey(ENV, "CI_INTEG_TEST_VERSIONS")
        return strip.(split(ENV["CI_INTEG_TEST_VERSIONS"], ","))
    else
        return ["1.10"]
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
    get_git_ci_tools_url_branch()::GitRepoAddress

Returns the URL and the branch of the Git repository for the location where the CI tools are
located. The default is the dev branch at
https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git.
User-defined URL and branch can be defined with the environment variables CI_GIT_CI_TOOLS_URL
and CI_GIT_CI_TOOLS_BRANCH.

# Return

`GitRepoAddress`: Contains git url and branch

"""
function get_git_ci_tools_url_branch()::GitRepoAddress
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
