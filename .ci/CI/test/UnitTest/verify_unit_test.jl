@testset "test add_unit_test_verify_job_yaml!() target branch dev" begin
    for git_repo in [
        CI.ToolsGitRepo("https://github.com/name/repo", "dev"),
        CI.ToolsGitRepo("foo", "bar"),
    ]
        expected_job = Dict(
            "image" => "julia:1.10",
            "stage" => "verify-unit-test-deps",
            "script" => [
                "apt update && apt install -y git",
                "git clone --depth 1 -b $(git_repo.branch) $(git_repo.url) /tools",
                "julia /tools/.ci/verify_env.jl",
            ],
            "interruptible" => true,
            "tags" => ["cpuonly"],
        )

        job_dict = Dict()
        CI.add_unit_test_verify_job_yaml!(job_dict, "dev", git_repo)

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
    job_dict = Dict()
    CI.add_unit_test_verify_job_yaml!(
        job_dict, "main", CI.ToolsGitRepo("https://github.com/name/repo", "dev")
    )
    @test isempty(job_dict)
end
