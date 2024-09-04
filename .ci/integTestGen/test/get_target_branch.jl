@testset "test is_pull_request()" begin
    @testset "no environemnt variable CI_COMMIT_REF_NAME set" begin
        if haskey(ENV, "CI_COMMIT_REF_NAME")
            delete!(ENV, "CI_COMMIT_REF_NAME")
        end
        @test_throws ErrorException integTestGen.is_pull_request()
    end

    @testset "empty CI_COMMIT_REF_NAME" begin
        ENV["CI_COMMIT_REF_NAME"] = ""
        @test integTestGen.is_pull_request() == false
    end

    for (ref_name, expected_result) in (
        ("pr-41/SimeonEhrig/QED.jl/setDevDepDeps", true),
        ("main", false),
        ("dev", false),
        ("v0.1.0", false),
    )
        @testset "CI_COMMIT_REF_NAME=$(ref_name)" begin
            ENV["CI_COMMIT_REF_NAME"] = ref_name
            @test integTestGen.is_pull_request() == expected_result
        end
    end
end

@testset "test get_build_branch()" begin
    @testset "no environemnt variable CI_COMMIT_REF_NAME set" begin
        if haskey(ENV, "CI_COMMIT_REF_NAME")
            delete!(ENV, "CI_COMMIT_REF_NAME")
        end
        @test_throws ErrorException integTestGen.get_build_branch()
    end

    for (ref_name, expected_result) in (
        (
            "pr-41/SimeonEhrig/QED.jl/setDevDepDeps",
            "pr-41/SimeonEhrig/QED.jl/setDevDepDeps",
        ),
        ("main", "main"),
        ("dev", "dev"),
        ("v0.1.0", "main"),
        ("v0.asd.0", "v0.asd.0"),
        ("feature3", "feature3"),
    )
        @testset "CI_COMMIT_REF_NAME=$(ref_name)" begin
            ENV["CI_COMMIT_REF_NAME"] = ref_name
            @test integTestGen.get_build_branch() == expected_result
        end
    end
end

@testset "test get_target_branch_pull_request()" begin
    @testset "no environemnt variable CI_COMMIT_REF_NAME set" begin
        if haskey(ENV, "CI_COMMIT_REF_NAME")
            delete!(ENV, "CI_COMMIT_REF_NAME")
        end
        @test_throws ErrorException integTestGen.get_target_branch_pull_request()
    end
end
