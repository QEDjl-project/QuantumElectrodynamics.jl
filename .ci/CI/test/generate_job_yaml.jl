using YAML

"""
    yaml_diff(given, expected)::AbstractString

Generates an error string that shows a given and an expected data structure in yaml 
representation.

# Returns
- Human readable error message for the comparison of two job yaml's.
"""
function yaml_diff(given, expected)::AbstractString
    output = "\ngiven:\n"
    output *= String(YAML.yaml(given))
    output *= "\nexpected:\n"
    output *= String(YAML.yaml(expected))
    return output
end

@testset "generate_job_yaml()" begin
    package_infos = CI.integTestGen.get_package_info()

    @testset "target main branch, no PR" begin
        job_yaml = Dict()
        CI.integTestGen.generate_job_yaml!(
            "QEDcore", "main", "/path/to/QEDcore.jl", job_yaml, package_infos
        )
        @test length(job_yaml) == 1

        expected_job_yaml = Dict()
        expected_job_yaml["IntegrationTestQEDcore"] = Dict(
            "image" => "julia:1.10",
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
            @assert job_yaml["IntegrationTestQEDcore"]["script"] ==
                expected_job_yaml["IntegrationTestQEDcore"]["script"] yaml_diff(
                job_yaml["IntegrationTestQEDcore"]["script"],
                expected_job_yaml["IntegrationTestQEDcore"]["script"],
            );
            true
        )

        @test (
            @assert job_yaml["IntegrationTestQEDcore"] ==
                expected_job_yaml["IntegrationTestQEDcore"] yaml_diff(
                job_yaml["IntegrationTestQEDcore"],
                expected_job_yaml["IntegrationTestQEDcore"],
            );
            true
        )
    end

    @testset "target non main branch, if PR or not is the same" begin
        job_yaml = Dict()
        CI.integTestGen.generate_job_yaml!(
            "QEDcore", "feature3", "/path/to/QEDcore.jl", job_yaml, package_infos
        )
        @test length(job_yaml) == 1

        expected_job_yaml = Dict()
        expected_job_yaml["IntegrationTestQEDcore"] = Dict(
            "image" => "julia:1.10",
            "interruptible" => true,
            "tags" => ["cpuonly"],
            "script" => [
                "apt update",
                "apt install -y git",
                "cd /",
                "git clone -b feature3 $(package_infos["QEDcore"].url) integration_test",
                "git clone -b dev https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git /integration_test_tools",
                "cd integration_test",
                "julia --project=. /integration_test_tools/.ci/SetupDevEnv/src/SetupDevEnv.jl",
                "julia --project=. -e 'import Pkg; Pkg.instantiate()'",
                "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
            ],
        )

        @test (
            @assert job_yaml["IntegrationTestQEDcore"]["script"] ==
                expected_job_yaml["IntegrationTestQEDcore"]["script"] yaml_diff(
                job_yaml["IntegrationTestQEDcore"]["script"],
                expected_job_yaml["IntegrationTestQEDcore"]["script"],
            );
            true
        )

        @test (
            @assert job_yaml["IntegrationTestQEDcore"] ==
                expected_job_yaml["IntegrationTestQEDcore"] yaml_diff(
                job_yaml["IntegrationTestQEDcore"],
                expected_job_yaml["IntegrationTestQEDcore"],
            );
            true
        )
    end

    @testset "target main branch, PR" begin
        job_yaml = Dict()
        CI.integTestGen.generate_job_yaml!(
            "QEDcore", "dev", "/path/to/QEDcore.jl", job_yaml, package_infos
        )
        CI.integTestGen.generate_job_yaml!(
            "QEDcore", "main", "/path/to/QEDcore.jl", job_yaml, package_infos, true
        )
        @test length(job_yaml) == 2

        expected_job_yaml = Dict()
        expected_job_yaml["IntegrationTestQEDcore"] = Dict(
            "image" => "julia:1.10",
            "interruptible" => true,
            "tags" => ["cpuonly"],
            "script" => [
                "apt update",
                "apt install -y git",
                "cd /",
                "git clone -b dev $(package_infos["QEDcore"].url) integration_test",
                "git clone -b dev https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git /integration_test_tools",
                "cd integration_test",
                "julia --project=. /integration_test_tools/.ci/SetupDevEnv/src/SetupDevEnv.jl",
                "julia --project=. -e 'import Pkg; Pkg.instantiate()'",
                "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
            ],
        )

        @test (
            @assert job_yaml["IntegrationTestQEDcore"]["script"] ==
                expected_job_yaml["IntegrationTestQEDcore"]["script"] yaml_diff(
                job_yaml["IntegrationTestQEDcore"]["script"],
                expected_job_yaml["IntegrationTestQEDcore"]["script"],
            );
            true
        )

        @test (
            @assert job_yaml["IntegrationTestQEDcore"] ==
                expected_job_yaml["IntegrationTestQEDcore"] yaml_diff(
                job_yaml["IntegrationTestQEDcore"],
                expected_job_yaml["IntegrationTestQEDcore"],
            );
            true
        )

        expected_job_yaml["IntegrationTestQEDcoreReleaseTest"] = Dict(
            "image" => "julia:1.10",
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
            @assert job_yaml["IntegrationTestQEDcoreReleaseTest"]["script"] ==
                expected_job_yaml["IntegrationTestQEDcoreReleaseTest"]["script"] yaml_diff(
                job_yaml["IntegrationTestQEDcoreReleaseTest"]["script"],
                expected_job_yaml["IntegrationTestQEDcoreReleaseTest"]["script"],
            );
            true
        )

        @test (
            @assert job_yaml["IntegrationTestQEDcoreReleaseTest"] ==
                expected_job_yaml["IntegrationTestQEDcoreReleaseTest"] yaml_diff(
                job_yaml["IntegrationTestQEDcoreReleaseTest"],
                expected_job_yaml["IntegrationTestQEDcoreReleaseTest"],
            );
            true
        )
    end
end
