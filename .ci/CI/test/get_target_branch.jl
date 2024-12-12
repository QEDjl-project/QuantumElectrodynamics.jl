@testset "test is_pull_request()" begin
    @testset "empty CI_COMMIT_REF_NAME" begin
        @test CI.is_pull_request("") == false
    end

    for (ref_name, expected_result) in (
        ("pr-41/SimeonEhrig/QuantumElectrodynamics.jl/setDevDepDeps", true),
        ("main", false),
        ("dev", false),
        ("v0.1.0", false),
    )
        @testset "CI_COMMIT_REF_NAME=$(ref_name)" begin
            @test CI.is_pull_request(ref_name) == expected_result
        end
    end
end

@testset "test parse_non_pull_request()" begin
    for (ref_name, expected_result) in (
        (
            "pr-41/SimeonEhrig/QuantumElectrodynamics.jl/setDevDepDeps",
            "pr-41/SimeonEhrig/QuantumElectrodynamics.jl/setDevDepDeps",
        ),
        ("main", "main"),
        ("dev", "dev"),
        ("v0.1.0", "main"),
        ("v0.asd.0", "v0.asd.0"),
        ("feature3", "feature3"),
    )
        @testset "CI_COMMIT_REF_NAME=$(ref_name)" begin
            @test CI.parse_non_pull_request(ref_name) == expected_result
        end
    end
end
