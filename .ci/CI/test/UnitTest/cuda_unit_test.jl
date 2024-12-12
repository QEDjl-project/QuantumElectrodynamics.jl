@testset "test _get_normal_unit_test CUDA platform" begin
    julia_version = "1.10"
    test_package = CI.TestPackage("QEDfoo", "/path/to/project", "42.0")
    git_url = "http://github.com/name/repo"
    git_branch = "branch"

    expected_job = get_generic_unit_job(julia_version, test_package)

    expected_job["script"] = get_main_unit_job_script_section(git_url, git_branch)

    expected_job["variables"]["TEST_CUDA"] = "1"
    expected_job["tags"] = ["cuda", "x86_64"]

    job_yaml = CI._get_normal_unit_test(
        julia_version, test_package, "main", CI.CUDA, CI.ToolsGitRepo(git_url, git_branch)
    )

    @test keys(expected_job) == keys(job_yaml)

    for k in keys(expected_job)
        @test (
            @assert job_yaml[k] == expected_job[k] (
                "\nkey: \"$(k)\"\n:" * yaml_diff(job_yaml[k], expected_job[k])
            );
            true
        )
    end

    @test (@assert job_yaml == expected_job yaml_diff(job_yaml, expected_job);
    true)

    @testset "test public interface" begin
        julia_versions = Vector{String}(["1.9", "1.10", "1.11"])

        job_dict = Dict()
        CI.add_unit_test_job_yaml!(
            job_dict,
            test_package,
            julia_versions,
            "main",
            CI.CUDA,
            CI.ToolsGitRepo(git_url, git_branch),
        )

        for julia_version in julia_versions
            job_name = "unit_test_julia_cuda_$(replace(julia_version, "." => "_"))"
            expected_job["image"] = "julia:$(julia_version)"
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
end