@testset "extract custom dependency URLs from environment variables" begin
    @testset "no environment variables" begin
        disable_info_logger_output() do
            custom_dependency_urls = CI.CustomDependencyUrls()
            CI.append_custom_dependency_urls_from_env_var!(
                custom_dependency_urls, Dict{String,String}()
            )
            @test isempty(custom_dependency_urls.unit)
            @test isempty(custom_dependency_urls.integ)
        end
    end

    @testset "single unit test" begin
        disable_info_logger_output() do
            custom_dependency_urls = CI.CustomDependencyUrls()
            CI.append_custom_dependency_urls_from_env_var!(
                custom_dependency_urls,
                Dict{String,String}(
                    "CI_UNIT_PKG_URL_QEDcore" => "https://github.com/unit/QEDcore#master"
                ),
            )
            @test custom_dependency_urls.unit ==
                Dict("QEDcore" => "https://github.com/unit/QEDcore#master")
            @test isempty(custom_dependency_urls.integ)
        end
    end

    @testset "multiple integration tests" begin
        disable_info_logger_output() do
            custom_dependency_urls = CI.CustomDependencyUrls()
            CI.append_custom_dependency_urls_from_env_var!(
                custom_dependency_urls,
                Dict{String,String}(
                    "CI_INTG_PKG_URL_QEDfields" => "https://github.com/integ/QEDfields",
                    "CI_UNIT_PKG_URL_QEDprocess" => "https://github.com/unit/QEDprocess",
                    "CI_UNIT_PKG_URL_QEDbase" => "https://github.com/unit/QEDbase#feature1",
                    "CI_INTG_PKG_URL_QEDbase" => "https://github.com/integ/QEDbase",
                ),
            )
            @test custom_dependency_urls.unit == Dict(
                "QEDprocess" => "https://github.com/unit/QEDprocess",
                "QEDbase" => "https://github.com/unit/QEDbase#feature1",
            )
            @test custom_dependency_urls.integ == Dict(
                "QEDfields" => "https://github.com/integ/QEDfields",
                "QEDbase" => "https://github.com/integ/QEDbase",
            )
        end
    end

    @testset "mixed unit and integration tests" begin
        disable_info_logger_output() do
            custom_dependency_urls = CI.CustomDependencyUrls()
            CI.append_custom_dependency_urls_from_env_var!(
                custom_dependency_urls,
                Dict{String,String}(
                    "CI_INTG_PKG_URL_QEDfields" => "https://github.com/integ/QEDfields",
                    "CI_INTG_PKG_URL_QEDbase" => "https://github.com/integ/QEDbase",
                ),
            )
            @test isempty(custom_dependency_urls.unit)
            @test custom_dependency_urls.integ == Dict(
                "QEDbase" => "https://github.com/integ/QEDbase",
                "QEDfields" => "https://github.com/integ/QEDfields",
            )
        end
    end
end

@testset "extract custom dependency URLs from git commit messages" begin
    @testset "no CI_COMMIT_MESSAGE environment variables set" begin
        disable_info_logger_output() do
            custom_dependency_urls = CI.CustomDependencyUrls()
            CI.append_custom_dependency_urls_from_git_message!(
                custom_dependency_urls, Dict{String,String}()
            )
            @test isempty(custom_dependency_urls.unit)
            @test isempty(custom_dependency_urls.integ)
        end
    end

    @testset "multiple custom unit test dependency URLs" begin
        disable_info_logger_output() do
            custom_dependency_urls = CI.CustomDependencyUrls()
            CI.append_custom_dependency_urls_from_git_message!(
                custom_dependency_urls,
                Dict{String,String}(
                    "CI_COMMIT_MESSAGE" => """Git headline

                                           This is a nice message.
                                           And another line.

                                           CI_UNIT_PKG_URL_QEDcore: https://github.com/unit/QEDcore
                                           CI_UNIT_PKG_URL_QED: https://github.com/unit/QED#f456j3
                                           """,
                ),
            )
            @test custom_dependency_urls.unit == Dict(
                "QEDcore" => "https://github.com/unit/QEDcore",
                "QED" => "https://github.com/unit/QED#f456j3",
            )
            @test isempty(custom_dependency_urls.integ)
        end
    end

    @testset "single custom integration test dependency URL" begin
        disable_info_logger_output() do
            custom_dependency_urls = CI.CustomDependencyUrls()
            CI.append_custom_dependency_urls_from_git_message!(
                custom_dependency_urls,
                Dict{String,String}(
                    "CI_COMMIT_MESSAGE" => """Git headline

                                           This is a nice message.
                                           And another line.

                                           CI_INTG_PKG_URL_QEDfields: https://github.com/integ/QEDfields
                                           """,
                ),
            )
            @test isempty(custom_dependency_urls.unit)
            @test custom_dependency_urls.integ ==
                Dict("QEDfields" => "https://github.com/integ/QEDfields")
        end
    end

    @testset "mixed custom unit and integration test dependency URLs" begin
        disable_info_logger_output() do
            custom_dependency_urls = CI.CustomDependencyUrls()
            CI.append_custom_dependency_urls_from_git_message!(
                custom_dependency_urls,
                Dict{String,String}(
                    "CI_COMMIT_MESSAGE" => """Git headline

                                           This is a nice message.
                                           And another line.

                                           CI_INTG_PKG_URL_QEDfields: https://github.com/integ/QEDfields#dev
                                           CI_INTG_PKG_URL_QEDprocesses: https://github.com/integ/QEDprocesses
                                           CI_INTG_PKG_URL_QEDbase: https://github.com/integ/QEDbase
                                           CI_UNIT_PKG_URL_QEDbase: https://github.com/unit/QEDbase#f156134
                                           CI_UNIT_PKG_URL_QEDcore: https://github.com/unit/QEDcore
                                           """,
                ),
            )
            @test custom_dependency_urls.unit == Dict(
                "QEDbase" => "https://github.com/unit/QEDbase#f156134",
                "QEDcore" => "https://github.com/unit/QEDcore",
            )
            @test custom_dependency_urls.integ == Dict(
                "QEDfields" => "https://github.com/integ/QEDfields#dev",
                "QEDprocesses" => "https://github.com/integ/QEDprocesses",
                "QEDbase" => "https://github.com/integ/QEDbase",
            )
        end
    end

    @testset "wrong custom integration test dependency URL" begin
        disable_info_logger_output() do
            custom_dependency_urls = CI.CustomDependencyUrls()
            @test_throws ErrorException CI.append_custom_dependency_urls_from_git_message!(
                custom_dependency_urls,
                Dict{String,String}(
                    "CI_COMMIT_MESSAGE" => """Git headline

                                           This is a nice message.
                                           And another line.

                                           CI_INTG_PKG_URL_QEDfields=https//github.com/integ/QEDfields
                                           """,
                ),
            )

            @test_throws ErrorException CI.append_custom_dependency_urls_from_git_message!(
                custom_dependency_urls,
                Dict{String,String}(
                    "CI_COMMIT_MESSAGE" => """Git headline

                                           This is a nice message.
                                           And another line.

                                           CI_INTG_PKG_URL_QEDfields=https://github.com/integ/QEDfields
                                           """,
                ),
            )
        end
    end

    @testset "wrong custom unit test dependency URL" begin
        disable_info_logger_output() do
            custom_dependency_urls = CI.CustomDependencyUrls()
            @test_throws ErrorException CI.append_custom_dependency_urls_from_git_message!(
                custom_dependency_urls,
                Dict{String,String}(
                    "CI_COMMIT_MESSAGE" => """Git headline

                                           This is a nice message.
                                           And another line.

                                           CI_UNIT_PKG_URL_QEDfields=https://github.com/integ/QEDfields
                                           """,
                ),
            )
        end
    end
end

@testset "mixed append_custom_dependency_urls!() and append_custom_dependency_urls_from_git_message!" begin
    disable_info_logger_output() do
        custom_dependency_urls = CI.CustomDependencyUrls()
        CI.append_custom_dependency_urls_from_env_var!(
            custom_dependency_urls,
            Dict{String,String}(
                "CI_INTG_PKG_URL_QEDfields" => "https://github.com/integ/QEDfieldsEnv",
                "CI_UNIT_PKG_URL_QEDprocess" => "https://github.com/unit/QEDprocessEnv",
                "CI_UNIT_PKG_URL_QEDbase" => "https://github.com/unit/QEDbaseEnv",
                "CI_INTG_PKG_URL_QEDbase" => "https://github.com/integ/QEDbaseEnv",
            ),
        )

        CI.append_custom_dependency_urls_from_git_message!(
            custom_dependency_urls,
            Dict{String,String}(
                "CI_COMMIT_MESSAGE" => """Git headline

                                       This is a nice message.
                                       And another line.

                                       CI_INTG_PKG_URL_QEDfields: https://github.com/integ/QEDfieldsMsg
                                       CI_INTG_PKG_URL_QEDprocesses: https://github.com/integ/QEDprocessesMsg
                                       CI_UNIT_PKG_URL_QEDbase: https://github.com/unit/QEDbaseMsg
                                       CI_UNIT_PKG_URL_QEDcore: https://github.com/unit/QEDcoreMsg
                                       """,
            ),
        )
        @test custom_dependency_urls.unit == Dict(
            "QEDbase" => "https://github.com/unit/QEDbaseMsg",
            "QEDcore" => "https://github.com/unit/QEDcoreMsg",
            "QEDprocess" => "https://github.com/unit/QEDprocessEnv",
        )
        @test custom_dependency_urls.integ == Dict(
            "QEDfields" => "https://github.com/integ/QEDfieldsMsg",
            "QEDprocesses" => "https://github.com/integ/QEDprocessesMsg",
            "QEDbase" => "https://github.com/integ/QEDbaseEnv",
        )
    end
end
