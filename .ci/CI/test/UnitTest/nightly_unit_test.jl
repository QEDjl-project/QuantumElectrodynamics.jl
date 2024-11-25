@testset "test _get_nightly_unit_test" begin
    for nightly_image in ["debian:bookworm-slim", "custom_image:latest"]
        julia_version = "a"
        test_package = CI.TestPackage("QEDfoo", "/path/to/project", "42.0")
        git_url = "http://github.com/name/repo"
        git_branch = "branch"

        expected_job = get_generic_unit_job(julia_version, test_package)

        expected_job["script"] = get_dev_unit_job_script_section(git_url, git_branch)

        expected_job["variables"]["TEST_CPU"] = "1"
        expected_job["variables"]["JULIA_DOWNLOAD"] = "/julia/download"
        expected_job["variables"]["JULIA_EXTRACT"] = "/julia/extract"
        expected_job["tags"] = ["cpuonly"]
        expected_job["image"] = nightly_image

        expected_job["before_script"] = [
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
            "JULIA_EXTRACT_FOLDER=\${JULIA_EXTRACT}/\$(ls \$JULIA_EXTRACT | grep -m1 julia)",
            "cp -r \$JULIA_EXTRACT_FOLDER/* /usr",
        ]
        expected_job["allow_failure"] = true

        job_yaml = CI._get_nightly_unit_test(
            test_package, "dev", CI.CPU, CI.ToolsGitRepo(git_url, git_branch), nightly_image
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
            julia_versions = Vector{String}(["nightly"])

            job_dict = Dict()
            CI.add_unit_test_job_yaml!(
                job_dict,
                test_package,
                julia_versions,
                "dev",
                CI.CPU,
                CI.ToolsGitRepo(git_url, git_branch),
            )

            job_name = "unit_test_julia_cpu_nightly"
            # default image
            expected_job["image"] = "debian:bookworm-slim"
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
