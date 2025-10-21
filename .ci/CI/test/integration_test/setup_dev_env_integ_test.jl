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
            "CI_QED_DEV_PKG_NAME" => "QEDtestFeature2",
            "CI_QED_DEV_PKG_VERSION" => "1.0.0",
            "CI_QED_DEV_PKG_PATH" => "/path/to/QEDtestFeature2.jl",
            "CI_QED_TEST_TYPE" => "integ",
            "CI_QED_TEST_CPU" => "1",
            "CI_QED_TEST_METAL" => "0",
            "CI_QED_TEST_CUDA" => "0",
            "CI_QED_TEST_ONEAPI" => "0",
            "CI_QED_TEST_AMDGPU" => "0",
        ),
        "interruptible" => true,
        "tags" => CI.get_cpu_runner_tags(),
        "script" => [
            "env | grep CI_QED_",
            "apt update",
            "apt install -y git",
            "cd /",
            "git clone --depth 1 -b feature47 https://github.com/fork/QED.jl.git /integration_test_tools",
            "git clone --depth 1 -b feature42 https://github.com/fork/QEDcore42.jl.git integration_test",
            "cd integration_test",
            "julia --project=/integration_test_tools/.ci/CI -e 'import Pkg; Pkg.instantiate()'",
            "julia --project=/integration_test_tools/.ci/CI /integration_test_tools/.ci/CI/script/setup_dev_env.jl \$PWD",
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
