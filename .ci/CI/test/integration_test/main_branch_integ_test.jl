@testset "integration test: no SetupDevEnv" begin
    job_yaml = Dict()
    @testset "target main branch" begin
        CI.add_integration_test_job_yaml!(
            job_yaml,
            CI.TestPackage("QEDtest", "1.0.0", "/path/to/QEDcore.jl"),
            false, # setup_dev_env
            true,
            "QEDcore",
            CI.GitRepoAddress(
                "https://github.com/QEDjl-project/QEDcore.jl.git",
                "main"
            ),
            CI.ReleaseVersion("1.10"),
            CI.CPU(),
            CI.GitRepoAddress("", "")
        )

        @test length(job_yaml) == 2
        @test job_yaml["stages"] == ["integ-test"]

        expected_job_yaml_main = Dict()
        expected_job_yaml_main["integration_test_QEDcore"] = Dict(
            "image" => "julia:1.10",
            "stage" => "integ-test",
            "allow_failure" => true,
            "variables" => Dict(
                "CI_QED_DEV_PKG_NAME" => "QEDtest",
                "CI_QED_DEV_PKG_VERSION" => "1.0.0",
                "CI_QED_DEV_PKG_PATH" => "/path/to/QEDcore.jl",
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
                "git clone --depth 1 -b main https://github.com/QEDjl-project/QEDcore.jl.git integration_test",
                "cd integration_test",
                "julia --project=. -e 'import Pkg; Pkg.develop(path=\"/path/to/QEDcore.jl\");'",
                "julia --project=. -e 'import Pkg; Pkg.instantiate()'",
                "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
            ],
        )

        @test (
            @assert job_yaml["integration_test_QEDcore"]["script"] ==
                expected_job_yaml_main["integration_test_QEDcore"]["script"] yaml_diff(
                job_yaml["integration_test_QEDcore"]["script"],
                expected_job_yaml_main["integration_test_QEDcore"]["script"],
            );
            true
        )

        @test (
            @assert job_yaml["integration_test_QEDcore"] ==
                expected_job_yaml_main["integration_test_QEDcore"] yaml_diff(
                job_yaml["integration_test_QEDcore"],
                expected_job_yaml_main["integration_test_QEDcore"],
            );
            true
        )
    end

    @testset "target feature branch" begin
        CI.add_integration_test_job_yaml!(
            job_yaml,
            CI.TestPackage("QEDtest", "2.0.0", "/path/to/QEDcore.jl"),
            false, # setup_dev_env
            false,
            "QEDcore_prefix",
            CI.GitRepoAddress(
                "https://github.com/QEDjl-project/QEDcore.jl.git",
                "feature1"
            ),
            CI.ReleaseVersion("1.12"),
            CI.CPU(),
            CI.GitRepoAddress("", "")
        )

        @test length(job_yaml) == 3
        @test job_yaml["stages"] == ["integ-test"]

        expected_job_yaml_feature = Dict()
        expected_job_yaml_feature["integration_test_QEDcore_prefix"] = Dict(
            "image" => "julia:1.12",
            "stage" => "integ-test",
            "variables" => Dict(
                "CI_QED_DEV_PKG_NAME" => "QEDtest",
                "CI_QED_DEV_PKG_VERSION" => "2.0.0",
                "CI_QED_DEV_PKG_PATH" => "/path/to/QEDcore.jl",
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
                "git clone --depth 1 -b feature1 https://github.com/QEDjl-project/QEDcore.jl.git integration_test",
                "cd integration_test",
                "julia --project=. -e 'import Pkg; Pkg.develop(path=\"/path/to/QEDcore.jl\");'",
                "julia --project=. -e 'import Pkg; Pkg.instantiate()'",
                "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
            ],
        )

        @test (
            @assert job_yaml["integration_test_QEDcore_prefix"]["script"] ==
                expected_job_yaml_feature["integration_test_QEDcore_prefix"]["script"] yaml_diff(
                job_yaml["integration_test_QEDcore_prefix"]["script"],
                expected_job_yaml_feature["integration_test_QEDcore_prefix"]["script"],
            );
            true
        )

        @test (
            @assert job_yaml["integration_test_QEDcore_prefix"] ==
                expected_job_yaml_feature["integration_test_QEDcore_prefix"] yaml_diff(
                job_yaml["integration_test_QEDcore_prefix"],
                expected_job_yaml_feature["integration_test_QEDcore_prefix"],
            );
            true
        )
    end
end
