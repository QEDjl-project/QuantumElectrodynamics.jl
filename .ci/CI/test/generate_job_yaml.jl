@testset "generate_job_yaml()" begin
    package_infos = CI.get_package_info()

    @testset "target main branch, no PR" begin
        job_yaml = Dict()
        CI.generate_job_yaml!(
            "QEDcore",
            CI.TestPackage("QEDtest", "1.0.0", "/path/to/QEDcore.jl"),
            "main",
            job_yaml,
            package_infos,
            CI.ToolsGitRepo("", ""),
        )
        @test length(job_yaml) == 1

        expected_job_yaml = Dict()
        expected_job_yaml["integration_test_QEDcore"] = Dict(
            "image" => "julia:1.10",
            "variables" => Dict(
                "CI_DEV_PKG_NAME" => "QEDtest",
                "CI_DEV_PKG_VERSION" => "1.0.0",
                "CI_DEV_PKG_PATH" => "/path/to/QEDcore.jl",
            ),
            "interruptible" => true,
            "tags" => ["cpuonly"],
            "script" => [
                "apt update",
                "apt install -y git",
                "cd /",
                "git clone -b main $(package_infos["QEDcore"].url) integration_test",
                "cd integration_test",
                "julia --project=. -e 'import Pkg; Pkg.develop(path=\"/path/to/QEDcore.jl\");'",
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

    @testset "target non main branch, if PR or not is the same" begin
        job_yaml = Dict()
        CI.generate_job_yaml!(
            "QEDcore",
            CI.TestPackage("QEDtest", "1.0.0", "/path/to/QEDcore.jl"),
            "feature3",
            job_yaml,
            package_infos,
            CI.ToolsGitRepo(
                "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git", "dev"
            ),
        )
        @test length(job_yaml) == 1

        expected_job_yaml = Dict()
        expected_job_yaml["integration_test_QEDcore"] = Dict(
            "image" => "julia:1.10",
            "variables" => Dict(
                "CI_DEV_PKG_NAME" => "QEDtest",
                "CI_DEV_PKG_VERSION" => "1.0.0",
                "CI_DEV_PKG_PATH" => "/path/to/QEDcore.jl",
            ),
            "interruptible" => true,
            "tags" => ["cpuonly"],
            "script" => [
                "apt update",
                "apt install -y git",
                "cd /",
                "git clone -b feature3 $(package_infos["QEDcore"].url) integration_test",
                "git clone -b dev https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git /integration_test_tools",
                "cd integration_test",
                "julia --project=. /integration_test_tools/.ci/CI/src/SetupDevEnv.jl",
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

    @testset "target main branch, PR" begin
        job_yaml = Dict()
        CI.generate_job_yaml!(
            "QEDcore",
            CI.TestPackage("QEDtest", "1.0.0", "/path/to/QEDcore.jl"),
            "dev",
            job_yaml,
            package_infos,
            CI.ToolsGitRepo("https://github.com/fork/QEDTest.jl.git", "ciDev"),
            "integ-test",
        )
        CI.generate_job_yaml!(
            "QEDcore",
            CI.TestPackage("QEDtest", "1.0.0", "/path/to/QEDcore.jl"),
            "main",
            job_yaml,
            package_infos,
            CI.ToolsGitRepo("https://github.com/fork_other/QEDTest.jl.git", "ciDevOther"),
            "integ-test",
            true,
        )
        @test length(job_yaml) == 2

        expected_job_yaml = Dict()
        expected_job_yaml["integration_test_QEDcore"] = Dict(
            "image" => "julia:1.10",
            "stage" => "integ-test",
            "variables" => Dict(
                "CI_DEV_PKG_NAME" => "QEDtest",
                "CI_DEV_PKG_VERSION" => "1.0.0",
                "CI_DEV_PKG_PATH" => "/path/to/QEDcore.jl",
            ),
            "interruptible" => true,
            "tags" => ["cpuonly"],
            "script" => [
                "apt update",
                "apt install -y git",
                "cd /",
                "git clone -b dev $(package_infos["QEDcore"].url) integration_test",
                "git clone -b ciDev https://github.com/fork/QEDTest.jl.git /integration_test_tools",
                "cd integration_test",
                "julia --project=. /integration_test_tools/.ci/CI/src/SetupDevEnv.jl",
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

        expected_job_yaml["integration_test_QEDcore_release_test"] = Dict(
            "image" => "julia:1.10",
            "stage" => "integ-test",
            "variables" => Dict(
                "CI_DEV_PKG_NAME" => "QEDtest",
                "CI_DEV_PKG_VERSION" => "1.0.0",
                "CI_DEV_PKG_PATH" => "/path/to/QEDcore.jl",
            ),
            "interruptible" => true,
            "tags" => ["cpuonly"],
            "allow_failure" => true,
            "script" => [
                "apt update",
                "apt install -y git",
                "cd /",
                "git clone -b main $(package_infos["QEDcore"].url) integration_test",
                "cd integration_test",
                "julia --project=. -e 'import Pkg; Pkg.develop(path=\"/path/to/QEDcore.jl\");'",
                "julia --project=. -e 'import Pkg; Pkg.instantiate()'",
                "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
            ],
        )

        @test (
            @assert job_yaml["integration_test_QEDcore_release_test"]["script"] ==
                expected_job_yaml["integration_test_QEDcore_release_test"]["script"] yaml_diff(
                job_yaml["integration_test_QEDcore_release_test"]["script"],
                expected_job_yaml["integration_test_QEDcore_release_test"]["script"],
            );
            true
        )

        @test (
            @assert job_yaml["integration_test_QEDcore_release_test"] ==
                expected_job_yaml["integration_test_QEDcore_release_test"] yaml_diff(
                job_yaml["integration_test_QEDcore_release_test"],
                expected_job_yaml["integration_test_QEDcore_release_test"],
            );
            true
        )
    end
end
