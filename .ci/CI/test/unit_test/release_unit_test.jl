@testset "unit test: cpu release candidate" begin
    julia_versions = ["1.9", "1.13"]
    test_package = CI.TestPackage("QEDfoo", "/path/to/project", "7.0")
    git_url = "http://github.com/name/repo"
    git_branch = "branch"
    tools_git_repo = CI.GitRepoAddress(git_url, git_branch)

    expected_job = get_generic_unit_job("rc", test_package)
    expected_job["script"] = get_main_unit_job_script_section(tools_git_repo)

    expected_job["variables"]["TEST_CPU"] = "1"
    expected_job["tags"] = ["cpuonly"]
    expected_job["allow_failure"] = true


    job_dict = Dict()
    CI.add_unit_test_job_yaml!(
        job_dict,
        test_package,
        CI.ReleaseCandidate(),
        CI.CPU(),
        tools_git_repo
    )

    job_name = "unit_test_julia_cpu_release_candidate"
    @test haskey(job_dict, job_name)
    @test job_dict["stages"] == ["unit-test"]

    unit_test_job = job_dict[job_name]

    @test keys(expected_job) == keys(unit_test_job)

    for k in keys(expected_job)
        @test (
            @assert unit_test_job[k] == expected_job[k] (
                "\nkey: \"$(k)\"\n:" * yaml_diff(unit_test_job[k], expected_job[k])
            );
            true
        )
    end

    @test (
        @assert unit_test_job == expected_job yaml_diff(
            unit_test_job, expected_job
        );
        true
    )
end
