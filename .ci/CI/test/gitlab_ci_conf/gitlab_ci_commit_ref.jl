@testset "is_github_pull_request()" begin
    @testset "pull request branch names" begin
        for name in [
                "pr-92/AntonReinhard/QEDprocesses.jl/setDevDepDeps",
                "pr-41/SimeonEhrig/QuantumElectrodynamics.jl/setDevDepDeps",
            ]
            @test CI.is_github_pull_request(name)
        end
    end

    @testset "normal commit names" begin
        for name in [
                "dev",
                "main",
                "1.0.0",
                "0.3.7-alpha",
                "feature1",
            ]
            @test CI.is_github_pull_request(name) == false
        end
    end
end

@testset "parse_gitlab_ci_pull_request()" begin
    @testset "working strings, default user" begin
        for (name, expected_gh_info) in [
                (
                    "pr-92/AntonReinhard/QEDprocesses.jl/setDevDepDeps",
                    CI.GitHubPR("QEDjl-project", "QEDprocesses.jl", 92),
                ), (
                    "pr-41/SimeonEhrig/QuantumElectrodynamics.jl/setDevDepDeps",
                    CI.GitHubPR("QEDjl-project", "QuantumElectrodynamics.jl", 41),

                ),
            ]
            gh_info = CI.parse_gitlab_ci_pull_request(name)
            @test gh_info.user == expected_gh_info.user
            @test gh_info.project == expected_gh_info.project
            @test gh_info.pr_number == expected_gh_info.pr_number
        end
    end

    @testset "working strings, custom user" begin
        gh_info = CI.parse_gitlab_ci_pull_request("pr-42/Group/Project/branch", "CustomGroup")
        @test gh_info.user == "CustomGroup"
        @test gh_info.project == "Project"
        @test gh_info.pr_number == 42
    end

    @testset "wrong strings" begin
        # missing project
        @test_throws ErrorException CI.parse_gitlab_ci_pull_request("pr-42/Group")
        # missing project
        @test_throws ErrorException CI.parse_gitlab_ci_pull_request("pr-42/Group/")
        # pr- prefix missing
        @test_throws ErrorException CI.parse_gitlab_ci_pull_request("42/Group/Project")
        # wrong prefix
        @test_throws ErrorException CI.parse_gitlab_ci_pull_request("p-42/Group/Project")
        # negativ pr number
        @test_throws ErrorException CI.parse_gitlab_ci_pull_request("pr--42/Group/Project")
    end
end
