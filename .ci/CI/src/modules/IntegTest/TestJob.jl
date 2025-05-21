using Pkg: Pkg
using YAML: YAML
using Logging
using IntegrationTests

"""
    add_integration_test_job_yaml!(
        job_dict::Dict,
        test_package::TestPackage,
        setup_dev_env::Bool,
        can_fail::Bool,
        integration_test_name::AbstractString,
        integration_test_repo::GitRepoAddress,
        integration_test_type::ReleaseVersion,
        test_platform::TestPlatform = CPU,
        tools_git_repo::GitRepoAddress = GitRepoAddress(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        )
    )

Add an integration test to job_dict for a given integration test type and target test platform. The
generated job contains all properties to be directly translated to GitLab CI yaml.

# Args
- `job_dict::Dict`: Dict in which the new job is added.
- `test_package::TestPackage`: Properties of the package to be tested, such as name and version.
- `setup_dev_env::Bool`: If the value is true, additional job code is generated that allows the dev
    or feature branch versions of the QED dependencies to be used.
- `can_fail::Bool`: If the value is true, add GitLab CI flag `allow_failure: true`.
- `integration_test_name::AbstractString`: Name of the integration test.
- `integration_test_repo::GitRepoAddress`: Git repository URL and branch of the package used for
    the integration test.
- `integration_test_type::TestType`: Depending on the type, slightly different unit tests are generated.
    Read the documentation of the concrete type to get more information.
- `test_platform::TestPlatform`: Set target platform test, e.g. CPU, Nvidia GPU or AMD GPU.
- `tools_git_repo::GitRepoAddress`: URL and branch of the Git repository from which the CI tools are
    cloned in unit test job.
"""
function add_integration_test_job_yaml! end

function add_integration_test_job_yaml!(
        job_dict::Dict,
        test_package::TestPackage,
        setup_dev_env::Bool,
        can_fail::Bool,
        integration_test_name::AbstractString,
        integration_test_repo::GitRepoAddress,
        integration_test_type::ReleaseVersion,
        test_platform::CPU,
        tools_git_repo::GitRepoAddress = GitRepoAddress(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        )
    )
    _add_stage_once!(job_dict, "integ-test")

    job_yaml = _get_normal_unit_test(
        test_package,
        setup_dev_env,
        can_fail,
        integration_test_repo,
        integration_test_type,
        tools_git_repo
    )
    job_yaml["tags"] = ["cpuonly"]

    job_dict["integration_test_$(integration_test_name)"] = job_yaml
    return nothing
end

function add_integration_test_job_yaml!(
        job_dict::Dict,
        test_package::TestPackage,
        setup_dev_env::Bool,
        can_fail::Bool,
        integration_test_name::AbstractString,
        integration_test_repo::GitRepoAddress,
        integration_test_type::ReleaseVersion,
        test_platform::CUDA,
        tools_git_repo::GitRepoAddress = GitRepoAddress(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        )
    )
    _add_stage_once!(job_dict, "integ-test")

    job_yaml = _get_normal_unit_test(
        test_package,
        setup_dev_env,
        can_fail,
        integration_test_repo,
        integration_test_type,
        tools_git_repo
    )
    job_yaml["tags"] = ["cuda", "x86_64"]

    job_dict["integration_test_$(integration_test_name)"] = job_yaml
    return nothing
end

function add_integration_test_job_yaml!(
        job_dict::Dict,
        test_package::TestPackage,
        setup_dev_env::Bool,
        can_fail::Bool,
        integration_test_name::AbstractString,
        integration_test_repo::GitRepoAddress,
        integration_test_type::ReleaseVersion,
        test_platform::AMDGPU,
        tools_git_repo::GitRepoAddress = GitRepoAddress(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        )
    )
    _add_stage_once!(job_dict, "integ-test")

    job_yaml = _get_normal_unit_test(
        test_package,
        setup_dev_env,
        can_fail,
        integration_test_repo,
        integration_test_type,
        tools_git_repo
    )
    _add_julia_rocm_environment!(job_yaml, integration_test_type)
    job_yaml["tags"] = ["rocm", "x86_64"]


    job_dict["integration_test_$(integration_test_name)"] = job_yaml
    return nothing
end

"""
    _get_normal_unit_test(
        test_package::TestPackage,
        setup_dev_env::Bool,
        can_fail::Bool,
        integration_test_repo::GitRepoAddress,
        integration_test_type::ReleaseVersion,
        tools_git_repo::GitRepoAddress
    )::Dict

Creates a normal integration test job for a specific Julia version.

# Args
- `test_package::TestPackage`: Properties of the package to be tested, such as name and version.
- `setup_dev_env::Bool`: If the value is true, additional job code is generated that allows the dev
    or feature branch versions of the QED dependencies to be used.
- `can_fail::Bool`: If the value is true, add GitLab CI flag `allow_failure: true`.
- `integration_test_repo::GitRepoAddress`: Git repository URL and branch of the package used for
    the integration test.
- `integration_test_type::TestType`: Depending on the type, slightly different unit tests are generated.
    Read the documentation of the concrete type to get more information.
- `tools_git_repo::GitRepoAddress`: URL and branch of the Git repository from which the CI tools are
    cloned in unit test job.
Return

Returns a dict containing the integration test, which can be output directly as GitLab CI yaml.
"""
function _get_normal_unit_test(
        test_package::TestPackage,
        setup_dev_env::Bool,
        can_fail::Bool,
        integration_test_repo::GitRepoAddress,
        integration_test_type::ReleaseVersion,
        tools_git_repo::GitRepoAddress
    )::Dict
    script = ["apt update", "apt install -y git", "cd /"]

    if setup_dev_env
        push!(
            script,
            "git clone --depth 1 -b $(tools_git_repo.branch) $(tools_git_repo.url) /integration_test_tools",
        )
    end

    push!(
        script,
        "git clone --depth 1 -b $(integration_test_repo.branch) $(integration_test_repo.url) integration_test"
    )
    push!(script, "cd integration_test")

    if setup_dev_env
        push!(script, "julia --project=. /integration_test_tools/.ci/CI/script/SetupDevEnv.jl")
    else
        push!(
            script,
            "julia --project=. -e 'import Pkg; Pkg.develop(path=\"$(test_package.path)\");'"
        )
    end

    push!(script, "julia --project=. -e 'import Pkg; Pkg.instantiate()'")
    push!(script, "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'")

    job_yaml = Dict(
        "image" => "julia:$(integration_test_type.version)",
        "stage" => "integ-test",
        "variables" => Dict(
            "CI_DEV_PKG_NAME" => test_package.name,
            "CI_DEV_PKG_VERSION" => test_package.version,
            "CI_DEV_PKG_PATH" => test_package.path,
            "CI_TEST_TYPE" => "integ",
        ),
        "interruptible" => true,
        "script" => script,
    )

    if can_fail
        job_yaml["allow_failure"] = true
    end

    return job_yaml
end
