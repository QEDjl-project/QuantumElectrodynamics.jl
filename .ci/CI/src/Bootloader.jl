include("./modules/Utils.jl")
include("./modules/GitLabTargetBranch.jl")
include("./modules/UnitTest.jl")
include("./modules/IntegTest.jl")

using IntegrationTests
using TOML
using Logging
using YAML

"""
    _check_env_vars()

Check if required environemnt variables are set. Exit with error, if not set.
"""
function _check_env_vars()
    if !haskey(ENV, "CI_COMMIT_REF_NAME")
        @error "Environment variable CI_COMMIT_REF_NAME is not set. Required to determine target branch."
    end

    if !haskey(ENV, "CI_PROJECT_DIR")
        @error "Environment variable CI_PROJECT_DIR is not set. Defines the base path of the project to test."
    end
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

# use main function to avoid to define global variables
function main()
    _check_env_vars()

    package_path = ENV["CI_PROJECT_DIR"]
    test_package = get_package_name_version(package_path)
    target_branch = get_target()

    @info "Test package name: $(test_package.name)"
    @info "Test package version: $(test_package.version)"
    @info "Test package path: $(test_package.path)"
    @info "PR target branch: $(target_branch)"

    unit_test_julia_versions = get_unit_test_julia_versions()
    @info "Julia versions for the unit tests: $(unit_test_julia_versions)"

    job_yaml = Dict()

    tools_git_repo = get_git_ci_tools_url_branch()

    add_unit_test_job_yaml!(
        job_yaml,
        test_package,
        unit_test_julia_versions,
        target_branch,
        tools_git_repo,
        get_unit_test_nightly_baseimage(),
    )

    add_integration_test_job_yaml!(job_yaml, test_package, target_branch, tools_git_repo)

    add_unit_test_verify_job_yaml!(job_yaml, target_branch, tools_git_repo)

    return print_job_yaml(job_yaml)
end

# TODO: if Julia 1.11 is minimum, replace it it with: function (@main)(args)
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
