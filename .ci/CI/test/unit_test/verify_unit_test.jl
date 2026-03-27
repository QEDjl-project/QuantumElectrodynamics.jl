@testset "test add_unit_test_verify_job_yaml!() target branch dev" begin
    for git_repo in [
            CI.GitRepoAddress("https://github.com/name/repo", "dev"),
            CI.GitRepoAddress("foo", "bar"),
        ]
        expected_job = Dict(
            "image" => "julia:1.10",
            "stage" => "verify-unit-test-deps",
            "script" => [
                "apt update && apt install -y git",
                "git clone --depth 1 -b $(git_repo.branch) $(git_repo.url) /tools",
                "julia --project=/tools/.ci/CI/ -e 'import Pkg; Pkg.instantiate()'",
                "julia --project=/tools/.ci/CI/ /tools/.ci/CI/script/verify_env.jl",
            ],
            "interruptible" => true,
            "tags" => CI.get_cpu_runner_tags(),
        )

        job_dict = Dict()
        CI.add_unit_test_verify_job_yaml!(job_dict, true, git_repo)

        @test job_dict["stages"] == ["verify-unit-test-deps"]
        @test (
            @assert job_dict["verify-unit-test-deps"] == expected_job yaml_diff(
                job_dict["verify-unit-test-deps"], expected_job
            );
            true
        )
    end
end

@testset "test add_unit_test_verify_job_yaml!() target branch main" begin
    expected_job = Dict(
        "stages" => ["verify-unit-test-deps"],
        "DummyJob" => Dict(
            "image" => "alpine:latest",
            "stage" => "verify-unit-test-deps",
            "interruptible" => true,
            "script" => ["echo \"No check necessary if setup_dev_env.jl is not used.\""]
        )
    )

    job_dict = Dict()
    CI.add_unit_test_verify_job_yaml!(
        job_dict, false, CI.GitRepoAddress("https://github.com/name/repo", "dev")
    )
    @test (
        @assert job_dict == expected_job yaml_diff(
            job_dict, expected_job
        );
        true
    )
end
