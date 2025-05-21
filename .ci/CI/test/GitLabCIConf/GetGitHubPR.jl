@testset "pull_github_pull_request()" begin
    @test isempty(CI.github_pr_cache)

    @testset "target dev branch" begin
        pr_info = CI.GitHubPR("QEDjl-project", "QuantumElectrodynamics.jl", 41)
        pr = CI.pull_github_pull_request(pr_info)

        @test pr.base.ref == "dev"
        @test pr.number == 41

        @test length(CI.github_pr_cache) == 1
        @test pr_info in keys(CI.github_pr_cache)
    end

    @testset "target main branch" begin
        pr_info = CI.GitHubPR("QEDjl-project", "QEDprocesses.jl", 92)
        pr = CI.pull_github_pull_request(pr_info)

        @test pr.base.ref == "main"
        @test pr.number == 92

        @test length(CI.github_pr_cache) == 2
        @test pr_info in keys(CI.github_pr_cache)

        @testset "call cached pull request" begin
            info_logger_io = IOBuffer()
            info_logger = CI.Logging.ConsoleLogger(info_logger_io, CI.Logging.Info)
            CI.Logging.with_logger(info_logger) do
                CI.pull_github_pull_request(pr_info)
            end

            @test length(CI.github_pr_cache) == 2
            logger_output = String(take!(info_logger_io))

            @test contains(logger_output, "use cached pull request object")
        end
    end
end
