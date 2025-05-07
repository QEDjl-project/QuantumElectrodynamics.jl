"""
    add_unit_test_verify_job_yaml!(
        job_dict::Dict,
        target_branch::AbstractString,
        tools_git_repo::GitRepoAddress=GitRepoAddress(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        ),
    )

Adds a verify job to the CI pipeline that checks if a custom unit test dependency URL is specified
in the Git commit message.

# Args
- `job_dict::Dict`: Dict in which the new job is added.
- `setup_dev_env::Bool`: If the value is true, additional job code is generated that allows the dev
    or feature branch versions of the QED dependencies to be used.
- `tools_git_repo::GitRepoAddress`: URL and branch of the Git repository from which the CI tools are
    cloned in unit test job.
"""
function add_unit_test_verify_job_yaml!(
        job_dict::Dict,
        setup_dev_env::Bool,
        tools_git_repo::GitRepoAddress = GitRepoAddress(
            "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
        ),
    )
    # verification script that no custom URLs are used in unit tests
    _add_stage_once!(job_dict, "verify-unit-test-deps")
    if setup_dev_env
        job_dict["verify-unit-test-deps"] = Dict(
            "image" => "julia:1.10",
            "stage" => "verify-unit-test-deps",
            "script" => [
                "apt update && apt install -y git",
                "git clone --depth 1 -b $(tools_git_repo.branch) $(tools_git_repo.url) /tools",
                "julia /tools/.ci/CI/src/VerifyEnv.jl",
            ],
            "interruptible" => true,
            "tags" => ["cpuonly"],
        )
    else
        generate_dummy_job_yaml!(
            job_dict,
            "No check necessary if SetupDevEnv.jl is not used.",
            "verify-unit-test-deps"
        )
    end
    return nothing
end
