@testset "integration test: use SetupDevEnv" begin
    job_yaml = Dict()
    CI.add_integration_test_job_yaml!(
        job_yaml,
        CI.TestPackage("QEDtestFeature2", "1.0.0", "/path/to/QEDtestFeature2.jl"),
        true, # setup_dev_env
        true,
        "QEDcore",
        CI.GitRepoAddress(
            "https://github.com/fork/QEDcore42.jl.git",
            "feature42"
        ),
        CI.ReleaseVersion("1.9"),
        CI.CPU(),
        CI.GitRepoAddress(
            "https://github.com/fork/QED.jl.git",
            "feature47"
        )
    )

    @test length(job_yaml) == 2
    @test job_yaml["stages"] == ["integ-test"]

    expected_job_yaml = Dict()
    expected_job_yaml["integration_test_QEDcore"] = Dict(
        "image" => "julia:1.9",
        "stage" => "integ-test",
        "allow_failure" => true,
        "variables" => Dict(
            "CI_DEV_PKG_NAME" => "QEDtestFeature2",
            "CI_DEV_PKG_VERSION" => "1.0.0",
            "CI_DEV_PKG_PATH" => "/path/to/QEDtestFeature2.jl",
            "CI_TEST_TYPE" => "integ",
        ),
        "interruptible" => true,
        "tags" => ["cpuonly"],
        "script" => [
            "apt update",
            "apt install -y git",
            "cd /",
            "git clone --depth 1 -b feature47 https://github.com/fork/QED.jl.git /integration_test_tools",
            "git clone --depth 1 -b feature42 https://github.com/fork/QEDcore42.jl.git integration_test",
            "cd integration_test",
            "julia --project=. /integration_test_tools/.ci/CI/script/SetupDevEnv.jl",
            "julia --project=. -e 'import Pkg; Pkg.instantiate()'",
            "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
        ],
    )

    @test (
        @assert job_yaml["integration_test_QEDcore"]["script"] ==
            expected_job_yaml["integration_test_QEDcore"]["script"] yaml_diff(
            job_yaml["integration_test_QEDcore"]["script"],
            expected_job_yaml["integration_test_QEDcore"]["script"],
        );
        true
    )

    @test (
        @assert job_yaml["integration_test_QEDcore"] ==
            expected_job_yaml["integration_test_QEDcore"] yaml_diff(
            job_yaml["integration_test_QEDcore"],
            expected_job_yaml["integration_test_QEDcore"],
        );
        true
    )
end
