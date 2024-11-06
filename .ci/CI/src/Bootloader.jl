include("./modules/Utils.jl")
include("./modules/GitLabTargetBranch.jl")
include("./modules/UnitTest.jl")
include("./modules/IntegTest.jl")

using IntegrationTests
using TOML
using Logging
using YAML

function _check_env_vars()
    if !haskey(ENV, "CI_COMMIT_REF_NAME")
        @error "Environment variable CI_COMMIT_REF_NAME is not set. Required to determine target branch."
    end

    if !haskey(ENV, "CI_PROJECT_DIR")
        @error "Environment variable CI_PROJECT_DIR is not set. Defines the base path of the project to test."
    end
end

function get_package_name_version(package_path::AbstractString)::TestPackage
    project_toml_path = joinpath(package_path, "Project.toml")

    f = open(project_toml_path, "r")
    project_toml = TOML.parse(f)
    close(f)
    return TestPackage(project_toml["name"], project_toml["version"], package_path)
end

function get_unit_test_julia_versions()::Vector{String}
    # TODO: support reading julia versions from env variables

    return ["1.10", "1.11", "rc", "nightly"]
end

function get_unit_test_nightly_baseimage()::String
    # TODO: support reading from env variables

    return "debian:bookworm-slim"
end

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
    #target_branch = GitLabTargetBranch.get_target()
    target_branch = "dev"

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
