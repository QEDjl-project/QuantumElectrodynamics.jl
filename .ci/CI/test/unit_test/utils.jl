"""
Returns the script section of an unit job without test command.

# Args
- `tools_git_repo::CI.GitRepoAddress`: Contains Git repository URL and branch of the dev tools.
"""
function get_script_section_without_test(tools_git_repo::CI.GitRepoAddress)
    return [
        "env | grep CI_QED_",
        "apt update && apt install -y git",
        "git clone --depth 1 -b $(tools_git_repo.branch) $(tools_git_repo.url) /tmp/integration_test_tools/",
        "julia --project=/tmp/integration_test_tools/.ci/CI/ -e 'import Pkg; Pkg.instantiate()'",
        "julia --project=/tmp/integration_test_tools/.ci/CI/ /tmp/integration_test_tools/.ci/CI/script/setup_dev_env.jl \${CI_PROJECT_DIR}",
        "julia --project=. -e 'import Pkg; Pkg.instantiate()'",
    ]
end

"""
Returns the script section of an unit job.

# Args
- `tools_git_repo::CI.GitRepoAddress`: Contains Git repository URL and branch of the dev tools.
"""
function get_main_unit_job_script_section(
        tools_git_repo::CI.GitRepoAddress
    )
    script = get_script_section_without_test(tools_git_repo)
    push!(script, "julia --project=. -e 'import Pkg; Pkg.test()'")
    return script
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
        "CI_QED_DEV_PKG_NAME" => test_package.name,
        "CI_QED_DEV_PKG_PATH" => test_package.path,
        "CI_QED_DEV_PKG_VERSION" => test_package.version,
        "CI_QED_TEST_TYPE" => "unit",
    )

    for tp in CI.TestPlatforms
        job_yaml["variables"]["CI_QED_TEST_$(CI.get_platform_name(tp))"] = "0"
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
