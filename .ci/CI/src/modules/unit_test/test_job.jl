"""
    add_unit_test_job_yaml!(
        job_dict::Dict,
        test_package::TestPackage,
        unit_test_type::TestType,
        test_platform::TestPlatform = CPU,
        tools_git_repo::GitRepoAddress = GitRepoAddress(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        )
    )

Add an unit test to job_dict for a given unit test type and target test platform. The generated job
contains all properties to be directly translated to GitLab CI yaml.

# Args
- `job_dict::Dict`: Dict in which the new job is added.
- `test_package::TestPackage`: Properties of the package to be tested, such as name and version.
- `unit_test_type::TestType`: Depending on the type, slightly different unit tests are generated.
    Read the documentation of the concrete type to get more information.
- `test_platform::TestPlatform`: Set target platform test, e.g. CPU, Nvidia GPU or AMD GPU.
- `tools_git_repo::GitRepoAddress`: URL and branch of the Git repository from which the CI tools are
    cloned in unit test job.
"""
function add_unit_test_job_yaml! end

_get_unit_test_name_prefix(test_platform::TestPlatform) = "unit_test_julia_" * lowercase(get_platform_name(test_platform))

function add_unit_test_job_yaml!(
        job_dict::Dict,
        test_package::TestPackage,
        unit_test_type::ReleaseVersion,
        test_platform::CPU,
        tools_git_repo::GitRepoAddress = GitRepoAddress(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        )
    )
    _add_stage_once!(job_dict, "unit-test")
    job_yaml = _get_default_unit_test(
        unit_test_type.version, test_package, test_platform, tools_git_repo
    )
    job_yaml["tags"] = ["cpuonly"]

    job_name = _get_unit_test_name_prefix(test_platform)
    job_name *= "_" * replace(unit_test_type.version, "." => "_")
    job_dict[job_name] = job_yaml
    return nothing
end

function add_unit_test_job_yaml!(
        job_dict::Dict,
        test_package::TestPackage,
        unit_test_type::ReleaseVersion,
        test_platform::CUDA,
        tools_git_repo::GitRepoAddress = GitRepoAddress(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        )
    )
    _add_stage_once!(job_dict, "unit-test")
    job_yaml = _get_default_unit_test(
        unit_test_type.version, test_package, test_platform, tools_git_repo
    )
    job_yaml["tags"] = ["cuda", "x86_64"]

    job_name = _get_unit_test_name_prefix(test_platform)
    job_name *= "_" * replace(unit_test_type.version, "." => "_")
    job_dict[job_name] = job_yaml
    return nothing
end

function add_unit_test_job_yaml!(
        job_dict::Dict,
        test_package::TestPackage,
        unit_test_type::ReleaseVersion,
        test_platform::AMDGPU,
        tools_git_repo::GitRepoAddress = GitRepoAddress(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        )
    )
    _add_stage_once!(job_dict, "unit-test")
    job_yaml = _get_default_unit_test(
        unit_test_type.version, test_package, test_platform, tools_git_repo
    )
    _add_julia_rocm_environment!(job_yaml, unit_test_type)
    job_yaml["tags"] = ["rocm", "x86_64"]

    job_name = _get_unit_test_name_prefix(test_platform)
    job_name *= "_" * replace(unit_test_type.version, "." => "_")
    job_dict[job_name] = job_yaml
    return nothing
end

function add_unit_test_job_yaml!(
        job_dict::Dict,
        test_package::TestPackage,
        unit_test_type::ReleaseCandidate,
        test_platform::CPU,
        tools_git_repo::GitRepoAddress = GitRepoAddress(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        )
    )
    _add_stage_once!(job_dict, "unit-test")
    job_yaml = _get_default_unit_test(
        "rc", test_package, test_platform, tools_git_repo
    )
    job_yaml["allow_failure"] = true
    job_yaml["tags"] = ["cpuonly"]

    job_name = _get_unit_test_name_prefix(test_platform)
    job_name *= "_release_candidate"

    job_dict[job_name] = job_yaml
    return nothing
end

function add_unit_test_job_yaml!(
        job_dict::Dict,
        test_package::TestPackage,
        unit_test_type::Nightly,
        test_platform::CPU,
        tools_git_repo::GitRepoAddress = GitRepoAddress(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        )
    )
    _add_stage_once!(job_dict, "unit-test")
    job_yaml = _get_default_unit_test(
        "nightly", test_package, test_platform, tools_git_repo
    )
    job_yaml["image"] = unit_test_type.container_image

    if !haskey(job_yaml, "variables")
        job_yaml["variables"] = Dict()
    end
    job_yaml["variables"]["JULIA_DOWNLOAD"] = "/julia/download"
    job_yaml["variables"]["JULIA_EXTRACT"] = "/julia/extract"

    job_yaml["before_script"] = [
        "apt update && apt install -y wget",
        "mkdir -p \$JULIA_DOWNLOAD",
        "mkdir -p \$JULIA_EXTRACT",
        "if [[ \$CI_RUNNER_EXECUTABLE_ARCH == \"linux/arm64\" ]]; then
  wget https://julialangnightlies-s3.julialang.org/bin/linux/aarch64/julia-latest-linux-aarch64.tar.gz -O \$JULIA_DOWNLOAD/julia-nightly.tar.gz
elif [[ \$CI_RUNNER_EXECUTABLE_ARCH == \"linux/amd64\" ]]; then
  wget https://julialangnightlies-s3.julialang.org/bin/linux/x86_64/julia-latest-linux-x86_64.tar.gz -O \$JULIA_DOWNLOAD/julia-nightly.tar.gz
else
  echo \"unknown runner architecture -> \$CI_RUNNER_EXECUTABLE_ARCH\"
  exit 1
fi",
        "tar -xf \$JULIA_DOWNLOAD/julia-nightly.tar.gz -C \$JULIA_EXTRACT",
        # we need to search for the julia base folder name, because the second part of the name is the git commit hash
        # e.g. julia-b0c6781676f
        "JULIA_EXTRACT_FOLDER=\${JULIA_EXTRACT}/\$(ls \$JULIA_EXTRACT | grep -m1 julia)",
        # copy everything to /usr to make julia public available
        # mv is not possible, because it cannot merge folder
        "cp -r \$JULIA_EXTRACT_FOLDER/* /usr",
    ]
    job_yaml["allow_failure"] = true
    job_yaml["tags"] = ["cpuonly"]

    job_name = _get_unit_test_name_prefix(test_platform)
    job_name *= "_nightly"

    job_dict[job_name] = job_yaml
    return nothing
end

"""
    _get_default_unit_test(
        version::AbstractString,
        test_package::TestPackage,
        test_platform::TestPlatform,
        tools_git_repo::GitRepoAddress,
    )

Creates a normal unit test job for a specific Julia version.

# Args
- `version::AbstractString`: Julia version used for the tests.
- `test_package::TestPackage`: Properties of the package to be tested, such as name and version.
- `test_platform::TestPlatform`: Set target platform test, e.g. CPU, Nvidia GPU or AMD GPU.
- `tools_git_repo::GitRepoAddress`: URL and branch of the Git repository from which the CI tools are
    cloned in unit test job.

Return

Returns a dict containing the unit test, which can be output directly as GitLab CI yaml.
"""
function _get_default_unit_test(
        version::AbstractString,
        test_package::TestPackage,
        test_platform::TestPlatform,
        tools_git_repo::GitRepoAddress,
    )::Dict
    job_yaml = Dict()
    job_yaml["stage"] = "unit-test"
    job_yaml["variables"] = Dict(
        "CI_QED_DEV_PKG_NAME" => test_package.name,
        "CI_QED_DEV_PKG_VERSION" => test_package.version,
        "CI_QED_DEV_PKG_PATH" => test_package.path,
        "CI_QED_TEST_TYPE" => "unit",
    )
    job_yaml["image"] = "julia:$(version)"

    if !haskey(job_yaml, "variables")
        job_yaml["variables"] = Dict()
    end

    for tp in TestPlatforms
        job_yaml["variables"]["CI_QED_TEST_$(get_platform_name(tp))"] = (tp == test_platform) ? "1" : "0"
    end

    job_yaml["script"] = [
        "env | grep CI_QED_",
        "apt update && apt install -y git",
        "git clone --depth 1 -b $(tools_git_repo.branch) $(tools_git_repo.url) /tmp/integration_test_tools/",
        "julia --project=/tmp/integration_test_tools/.ci/CI/ -e 'import Pkg; Pkg.instantiate()'",
        "julia --project=/tmp/integration_test_tools/.ci/CI/ /tmp/integration_test_tools/.ci/CI/script/setup_dev_env.jl \${CI_PROJECT_DIR}",
        "julia --project=. -e 'import Pkg; Pkg.instantiate()'",
        "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
    ]

    job_yaml["interruptible"] = true

    return job_yaml
end
