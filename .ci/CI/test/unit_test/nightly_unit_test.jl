@testset "unit test: cpu nightly" begin
    julia_versions = ["1.9", "1.13"]
    test_package = CI.TestPackage("QEDfoo", "/path/to/project", "7.0")
    git_url = "http://github.com/name/repo"
    git_branch = "branch"
    tools_git_repo = CI.GitRepoAddress(git_url, git_branch)

    for nightly_image in ["debian:bookworm-slim", "custom_image:latest"]
        expected_job = get_generic_unit_job("stupid_name", test_package)
        expected_job["script"] = get_main_unit_job_script_section(tools_git_repo)

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

        expected_job["image"] = nightly_image
        expected_job["variables"]["JULIA_DOWNLOAD"] = "/julia/download"
        expected_job["variables"]["JULIA_EXTRACT"] = "/julia/extract"
        expected_job["variables"]["CI_QED_TEST_CPU"] = "1"
        expected_job["tags"] = CI.get_cpu_runner_tags()
        expected_job["allow_failure"] = true


        job_dict = Dict()
        CI.add_unit_test_job_yaml!(
            job_dict,
            test_package,
            CI.Nightly(nightly_image),
            CI.CPU(),
            tools_git_repo
        )

        job_name = "unit_test_julia_cpu_nightly"
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
