"""
Returns the script section of an unit job targeting the dev branch.
"""
function get_dev_unit_job_script_section(
    git_repo_url::AbstractString, git_repo_branch::AbstractString
)
    return [
        "apt update && apt install -y git",
        "git clone --depth 1 -b $(git_repo_branch) $(git_repo_url) /tmp/integration_test_tools/",
        "julia --project=. /tmp/integration_test_tools/.ci/CI/src/SetupDevEnv.jl \${CI_PROJECT_DIR}/Project.toml",
        "julia --project=. -e 'import Pkg; Pkg.instantiate()'",
        "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
    ]
end

"""
Returns the script section of an unit job targeting the main branch.
"""
function get_main_unit_job_script_section(
    git_repo_url::AbstractString, git_repo_branch::AbstractString
)
    return [
        "apt update && apt install -y git",
        "git clone --depth 1 -b $(git_repo_branch) $(git_repo_url) /tmp/integration_test_tools/",
        "julia --project=. /tmp/integration_test_tools/.ci/CI/src/SetupDevEnv.jl \${CI_PROJECT_DIR}/Project.toml NO_MESSAGE",
        "julia --project=. -e 'import Pkg; Pkg.instantiate()'",
        "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
    ]
end

"""
Returns a job skeleton for a unit job.
"""
function get_generic_unit_job(
    julia_version::AbstractString, test_package::CI.TestPackage
)::Dict
    job_yaml = Dict()
    job_yaml["stage"] = "unit-test"
    job_yaml["image"] = "julia:$(julia_version)"
    job_yaml["variables"] = Dict(
        "CI_DEV_PKG_NAME" => test_package.name,
        "CI_DEV_PKG_PATH" => test_package.path,
        "CI_DEV_PKG_VERSION" => test_package.version,
    )

    for tp in instances(CI.TestPlatform)
        job_yaml["variables"]["TEST_$(tp)"] = "0"
    end

    job_yaml["interruptible"] = true

    return job_yaml
end

"""
Returns the before_script section of an amdgpu unit job.
"""
function get_amdgpu_before_script(julia_version::String)::Vector{String}
    return [
        "curl -fsSL https://install.julialang.org | sh -s -- -y -p /julia",
        "export PATH=/julia/bin:\$PATH",
        "echo \$PATH",
        "juliaup add $(julia_version)",
        "juliaup default $(julia_version)",
    ]
end
