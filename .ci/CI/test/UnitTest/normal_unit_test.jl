@testset "unit test: cpu release" begin
    julia_versions = ["1.9", "1.13"]
    test_package = CI.TestPackage("QEDfoo", "/path/to/project", "7.0")
    git_url = "http://github.com/name/repo"
    git_branch = "branch"
    tools_git_repo = CI.GitRepoAddress(git_url, git_branch)

    for version in julia_versions, setup_dev_env in [true, false]
        expected_job = get_generic_unit_job(version, test_package)
        expected_job["script"] = get_main_unit_job_script_section(setup_dev_env, tools_git_repo)

        expected_job["variables"]["TEST_CPU"] = "1"
        expected_job["tags"] = ["cpuonly"]

        job_dict = Dict()
        CI.add_unit_test_job_yaml!(
            job_dict,
            test_package,
            setup_dev_env,
            CI.ReleaseVersion(version),
            CI.CPU,
            tools_git_repo
        )

        job_name = "unit_test_julia_cpu_$(replace(version, "." => "_"))"
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
end
