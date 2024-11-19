"""
Specify target processor for the tests.
"""
@enum TestPlatform CPU CUDA AMDGPU ONEAPI METAL

"""
    add_unit_test_job_yaml!(
        job_dict::Dict,
        test_package::TestPackage,
        julia_versions::Vector{String},
        target_branch::AbstractString,
        test_platform::TestPlatform=CPU,
        tools_git_repo::ToolsGitRepo=ToolsGitRepo(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        ),
        nightly_base_image::AbstractString="debian:bookworm-slim",
    )

Add an unit test to job_dict for a given Julia version. The generated job contains all properties
to be directly translated to GitLab CI yaml.

# Args
- `job_dict::Dict`: Dict in which the new job is added.
- `test_package::TestPackage`: Properties of the package to be tested, such as name and version.
- `julia_versions::Vector{String}`: Julia version used for the tests.
- `target_branch::AbstractString`: A different job code is generated depending on the target branch.
- `test_platform::TestPlatform`: Set target platform test, e.g. CPU, Nvidia GPU or AMD GPU.
- `tools_git_repo::ToolsGitRepo`: URL and branch of the Git repository from which the CI tools are
    cloned in unit test job.
- `nightly_base_image::AbstractString`: Name of the job base image if the Julia version is nightly.
"""
function add_unit_test_job_yaml!(
    job_dict::Dict,
    test_package::TestPackage,
    julia_versions::Vector{String},
    target_branch::AbstractString,
    test_platform::TestPlatform=CPU,
    tools_git_repo::ToolsGitRepo=ToolsGitRepo(
        "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
    ),
    nightly_base_image::AbstractString="debian:bookworm-slim",
)
    if test_platform in [ONEAPI, METAL]
        throw(ArgumentError("argument test_platform not implemented for $(test_platform)"))
    end

    if !haskey(job_dict, "stages")
        job_dict["stages"] = []
    end

    push!(job_dict["stages"], "unit-test")

    for version in julia_versions
        test_platform_name = lowercase(string(test_platform))
        if version != "nightly"
            if test_platform == AMDGPU
                job_dict["unit_test_julia_$(test_platform_name)_$(replace(version, "." => "_"))"] = _get_amdgpu_unit_test(
                    version, test_package, target_branch, tools_git_repo
                )
            else
                job_dict["unit_test_julia_$(test_platform_name)_$(replace(version, "." => "_"))"] = _get_normal_unit_test(
                    version, test_package, target_branch, test_platform, tools_git_repo
                )
            end
        else
            job_dict["unit_test_julia_$(test_platform_name)_nightly"] = _get_nightly_unit_test(
                test_package,
                target_branch,
                test_platform,
                tools_git_repo,
                nightly_base_image,
            )
        end
    end
end

"""
    add_unit_test_verify_job_yaml!(
        job_dict::Dict,
        target_branch::AbstractString,
        tools_git_repo::ToolsGitRepo=ToolsGitRepo(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        ),
    )

Adds a verify job to the CI pipeline that checks if a custom unit test dependency URL is specified
in the Git commit message.

# Args
- `job_dict::Dict`: Dict in which the new job is added.
- `target_branch::AbstractString`: A different job code is generated depending on the target branch.
- `tools_git_repo::ToolsGitRepo`: URL and branch of the Git repository from which the CI tools are
    cloned in unit test job.
"""
function add_unit_test_verify_job_yaml!(
    job_dict::Dict,
    target_branch::AbstractString,
    tools_git_repo::ToolsGitRepo=ToolsGitRepo(
        "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
    ),
)
    # verification script that no custom URLs are used in unit tests
    if target_branch != "main"
        push!(job_dict["stages"], "verify-unit-test-deps")
        job_dict["verify-unit-test-deps"] = Dict(
            "image" => "julia:1.10",
            "stage" => "verify-unit-test-deps",
            "script" => [
                "apt update && apt install -y git",
                "git clone --depth 1 -b $(tools_git_repo.branch) $(tools_git_repo.url) /tools",
                "julia /tools/.ci/verify_env.jl",
            ],
            "interruptible" => true,
            "tags" => ["cpuonly"],
        )
    end
end

"""
    _get_normal_unit_test(
        version::AbstractString,
        test_package::TestPackage,
        target_branch::AbstractString,
        test_platform::TestPlatform,
        tools_git_repo::ToolsGitRepo,
    )

Creates a normal unit test job for a specific Julia version.

# Args
- `version::AbstractString`: Julia version used for the tests.
- `test_package::TestPackage`: Properties of the package to be tested, such as name and version.
- `target_branch::AbstractString`: A different job code is generated depending on the target branch.
- `test_platform::TestPlatform`: Set target platform test, e.g. CPU, Nvidia GPU or AMD GPU.
- `tools_git_repo::ToolsGitRepo`: URL and branch of the Git repository from which the CI tools are
    cloned in unit test job.

Return

Returns a dict containing the unit test, which can be output directly as GitLab CI yaml.
"""
function _get_normal_unit_test(
    version::AbstractString,
    test_package::TestPackage,
    target_branch::AbstractString,
    test_platform::TestPlatform,
    tools_git_repo::ToolsGitRepo,
)::Dict
    job_yaml = Dict()
    job_yaml["stage"] = "unit-test"
    job_yaml["variables"] = Dict(
        "CI_DEV_PKG_NAME" => test_package.name,
        "CI_DEV_PKG_VERSION" => test_package.version,
        "CI_DEV_PKG_PATH" => test_package.path,
    )
    job_yaml["image"] = "julia:$(version)"

    if !haskey(job_yaml, "variables")
        job_yaml["variables"] = Dict()
    end

    for tp in instances(TestPlatform)
        job_yaml["variables"]["TEST_$(tp)"] = (tp == test_platform) ? "1" : "0"
    end

    script = [
        "apt update && apt install -y git",
        "git clone --depth 1 -b $(tools_git_repo.branch) $(tools_git_repo.url) /tmp/integration_test_tools/",
    ]

    if target_branch == "main"
        push!(
            script,
            "julia --project=. /tmp/integration_test_tools/.ci/CI/src/SetupDevEnv.jl \${CI_PROJECT_DIR}/Project.toml NO_MESSAGE",
        )
    else
        push!(
            script,
            "julia --project=. /tmp/integration_test_tools/.ci/CI/src/SetupDevEnv.jl \${CI_PROJECT_DIR}/Project.toml",
        )
    end

    script = vcat(
        script,
        [
            "julia --project=. -e 'import Pkg; Pkg.instantiate()'",
            "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
        ],
    )
    job_yaml["script"] = script

    job_yaml["interruptible"] = true

    if test_platform == CPU
        job_yaml["tags"] = ["cpuonly"]
    elseif test_platform == CUDA
        job_yaml["tags"] = ["cuda", "x86_64"]
    elseif test_platform == AMDGPU
        job_yaml["tags"] = ["rocm", "x86_64"]
    else
        throw(
            ArgumentError(
                "test_platform argument with value $(test_platform) not supported"
            ),
        )
    end

    return job_yaml
end

"""
    _get_nightly_unit_test(
        test_package::TestPackage,
        target_branch::AbstractString,
        test_platform::TestPlatform,
        tools_git_repo::ToolsGitRepo,
        nightly_base_image::AbstractString,
    )

Creates a unit test job which uses the Julia nightly version.

# Args
- `test_package::TestPackage`: Properties of the package to be tested, such as name and version.
- `test_platform::TestPlatform`: Set target platform test, e.g. CPU, Nvidia GPU or AMD GPU.
- `target_branch::AbstractString`: A different job code is generated depending on the target branch.
- `tools_git_repo::ToolsGitRepo`: URL and branch of the Git repository from which the CI tools are
    cloned in unit test job.
- `nightly_base_image::AbstractString`: Name of the job base image if the Julia version is nightly.

Return

Returns a dict containing the unit test, which can be output directly as GitLab CI yaml.
"""
function _get_nightly_unit_test(
    test_package::TestPackage,
    target_branch::AbstractString,
    test_platform::TestPlatform,
    tools_git_repo::ToolsGitRepo,
    nightly_base_image::AbstractString,
)
    job_yaml = _get_normal_unit_test(
        "1", test_package, target_branch, test_platform, tools_git_repo
    )
    job_yaml["image"] = nightly_base_image

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

    job_yaml["image"] = "debian:bookworm-slim"

    job_yaml["allow_failure"] = true
    return job_yaml
end

"""
    _get_amdgpu_unit_test(
        version::AbstractString,
        test_package::TestPackage,
        target_branch::AbstractString,
        tools_git_repo::ToolsGitRepo,
    )

Creates a amdgpu unit test job for a specific Julia version. Use a different base image and install 
Julia in it.

# Args
- `version::AbstractString`: Julia version used for the tests.
- `test_package::TestPackage`: Properties of the package to be tested, such as name and version.
- `target_branch::AbstractString`: A different job code is generated depending on the target branch.
- `tools_git_repo::ToolsGitRepo`: URL and branch of the Git repository from which the CI tools are
    cloned in unit test job.

Return

Returns a dict containing the unit test, which can be output directly as GitLab CI yaml.
"""
function _get_amdgpu_unit_test(
    version::AbstractString,
    test_package::TestPackage,
    target_branch::AbstractString,
    tools_git_repo::ToolsGitRepo,
)::Dict
    job_yaml = _get_normal_unit_test(
        version, test_package, target_branch, AMDGPU, tools_git_repo
    )
    job_yaml["image"] = "rocm/dev-ubuntu-24.04:6.2.4-complete"
    job_yaml["before_script"] = [
        "curl -fsSL https://install.julialang.org | sh -s -- -y -p /julia",
        "export PATH=/julia/bin:\$PATH",
        "echo \$PATH",
        "juliaup add $(version)",
        "juliaup default $(version)",
    ]
    job_yaml["tags"] = ["rocm", "x86_64"]

    return job_yaml
end
