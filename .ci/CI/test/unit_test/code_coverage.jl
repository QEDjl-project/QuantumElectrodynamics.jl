@testset "unit test: add code coverage for dev branch" begin
    test_package = CI.TestPackage("QEDfoo", "/path/to/project", "7.0")
    julia_version = "1.13"
    git_url = "http://github.com/name/repo"
    git_branch = "branch"
    tools_git_repo = CI.GitRepoAddress(git_url, git_branch)
    code_coverage_conf = CI.CodeCoverageConf("MaxMusterman/run.jl", "123sdf32", "dev", 0)

    job_dict = Dict()
    CI.add_unit_test_job_yaml!(
        job_dict,
        test_package,
        CI.ReleaseVersion(julia_version),
        CI.CPU(),
        tools_git_repo,
        code_coverage_conf
    )
    job_name = "unit_test_julia_cpu_$(replace(julia_version, "." => "_"))"

    expected_script = get_script_section_without_test(tools_git_repo)
    expected_script = vcat(
        expected_script, [
            "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
            "julia --project=@coverage -e 'import Pkg; Pkg.add(\"Coverage\"); using Coverage; LCOV.writefile(\"coverage-lcov.info\", process_folder())'",
            # installing the codecov CLI via pip takes much more time
            # therefore use it as fallback
            # on x86, simply download pre compiled executable
            "if [[ \$CI_RUNNER_EXECUTABLE_ARCH == \"linux/amd64\" ]]; then
  curl -Os https://cli.codecov.io/latest/linux/codecov
  chmod +x codecov
  mv ./codecov /usr/local/bin/
else
  apt update && apt install -y python3-pip
  pip3 install --break-system-packages codecov-cli
fi",
            "codecov --version",
            "env -i CODECOV_TOKEN=\$CODECOV_TOKEN bash -c \"codecov -v \
            create-commit \
            --git-service github \
            --branch dev \
            --sha 123sdf32  \
            --slug MaxMusterman/run.jl\"",
            "env -i CODECOV_TOKEN=\$CODECOV_TOKEN bash -c \"codecov -v \
            create-report \
            --git-service github \
            --sha 123sdf32  \
            --slug MaxMusterman/run.jl\"",
            "env -i CODECOV_TOKEN=\$CODECOV_TOKEN bash -c \"codecov -v \
            do-upload \
            --git-service github \
            --branch dev \
            --sha 123sdf32  \
            --slug MaxMusterman/run.jl\"",
        ]
    )

    @test (
        @assert job_dict[job_name]["script"] == expected_script yaml_diff(
            job_dict[job_name]["script"], expected_script
        );
        true
    )
end

@testset "unit test: add code coverage for pull request" begin
    test_package = CI.TestPackage("QEDfoo", "/path/to/project", "7.0")
    julia_version = "1.13"
    git_url = "http://github.com/name/repo"
    git_branch = "branch"
    tools_git_repo = CI.GitRepoAddress(git_url, git_branch)
    code_coverage_conf = CI.CodeCoverageConf("MaxMusterman/do.jl", "345asds2", "feature2", 13)

    job_dict = Dict()
    CI.add_unit_test_job_yaml!(
        job_dict,
        test_package,
        CI.ReleaseVersion(julia_version),
        CI.CPU(),
        tools_git_repo,
        code_coverage_conf
    )
    job_name = "unit_test_julia_cpu_$(replace(julia_version, "." => "_"))"

    expected_script = get_script_section_without_test(tools_git_repo)
    expected_script = vcat(
        expected_script, [
            "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
            "julia --project=@coverage -e 'import Pkg; Pkg.add(\"Coverage\"); using Coverage; LCOV.writefile(\"coverage-lcov.info\", process_folder())'",
            # installing the codecov CLI via pip takes much more time
            # therefore use it as fallback
            # on x86, simply download pre compiled executable
            "if [[ \$CI_RUNNER_EXECUTABLE_ARCH == \"linux/amd64\" ]]; then
  curl -Os https://cli.codecov.io/latest/linux/codecov
  chmod +x codecov
  mv ./codecov /usr/local/bin/
else
  apt update && apt install -y python3-pip
  pip3 install --break-system-packages codecov-cli
fi",
            "codecov --version",
            "env -i CODECOV_TOKEN=\$CODECOV_TOKEN bash -c \"codecov -v \
            create-commit \
            --git-service github \
            --branch feature2 \
            --sha 345asds2 --pr 13 \
            --slug MaxMusterman/do.jl\"",
            "env -i CODECOV_TOKEN=\$CODECOV_TOKEN bash -c \"codecov -v \
            create-report \
            --git-service github \
            --sha 345asds2 --pr 13 \
            --slug MaxMusterman/do.jl\"",
            "env -i CODECOV_TOKEN=\$CODECOV_TOKEN bash -c \"codecov -v \
            do-upload \
            --git-service github \
            --branch feature2 \
            --sha 345asds2 --pr 13 \
            --slug MaxMusterman/do.jl\"",
        ]
    )

    @test (
        @assert job_dict[job_name]["script"] == expected_script yaml_diff(
            job_dict[job_name]["script"], expected_script
        );
        true
    )
end
