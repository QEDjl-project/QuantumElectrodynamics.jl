using SetupDevEnv
using Test

@testset "SetupDevEnv.jl" begin
    message_var_name = "TEST_CI_COMMIT_MESSAGE"

    @testset "test extraction from Git Message" begin
        @test !haskey(ENV, message_var_name)
        # should not throw an error if the environment CI_COMMIT_MESSAGE does not exist
        SetupDevEnv.extract_env_vars_from_git_message!(message_var_name)

        ENV[message_var_name] = """This is a normal feature.

        The feature can do someting useful.

        Be carful, when you use the feature.
        """
        SetupDevEnv.extract_env_vars_from_git_message!(message_var_name)
        @test isempty(
            filter((env_name) -> startswith(env_name, "CI_UNIT_PKG_URL_"), keys(ENV))
        )

        ENV[message_var_name] = """This is a normal feature.

        The feature can do someting useful.

        Be carful, when you use the feature.
        CI_UNIT_PKG_URL_QEDbase: https://foo.com
        """
        SetupDevEnv.extract_env_vars_from_git_message!(message_var_name)
        deps = (filter((env_name) -> startswith(env_name, "CI_UNIT_PKG_URL_"), keys(ENV)))
        @test length(deps) == 1

        ENV[message_var_name] = """This is a normal feature.

        The feature can do someting useful.

        Be carful, when you use the feature.
        CI_UNIT_PKG_URL_QEDbase: https://foo.com
        CI_UNIT_PKG_URL_QEDbase: https://bar.com
        """
        SetupDevEnv.extract_env_vars_from_git_message!(message_var_name)
        deps = (filter((env_name) -> startswith(env_name, "CI_UNIT_PKG_URL_"), keys(ENV)))
        @test length(deps) == 1

        ENV[message_var_name] = """This is a normal feature.

        The feature can do someting useful.

        Be carful, when you use the feature.
        CI_UNIT_PKG_URL_QEDbase: https://foo.com
        CI_UNIT_PKG_URL_QEDfields: https://bar.com
        """
        SetupDevEnv.extract_env_vars_from_git_message!(message_var_name)
        deps = (filter((env_name) -> startswith(env_name, "CI_UNIT_PKG_URL_"), keys(ENV)))
        @test length(deps) == 2

        ENV[message_var_name] = """This is a normal feature.

        The feature can do someting useful.

        Be carful, when you use the feature.
        CI_UNIT_PKG_URL_QEDbase: https://foo.com
        CI_UNIT_PKG_URL_QEDfields: https://bar.com
        CI_UNIT_PKG_URL_QEDevents: https://foobar.com
        """
        SetupDevEnv.extract_env_vars_from_git_message!(message_var_name)
        deps = (filter((env_name) -> startswith(env_name, "CI_UNIT_PKG_URL_"), keys(ENV)))
        @test length(deps) == 3
    end

    @testset "test dependency extraction from Poject.toml" begin
        tmp_path = mktempdir()

        @testset "no dependencies" begin
            project_path = joinpath(tmp_path, "Project1.toml")
            open(project_path, "w") do f
                write(
                    f,
                    """
           name = "QED"
           uuid = "bb1fba1d-cf9b-41b3-874e-4b81465537b9"
           authors = ["Uwe Hernandez Acosta <u.hernandez@hzdr.de>", "Simeon Ehrig", "Klaus Steiniger", "Tom Jungnickel", "Anton Reinhard"]
           version = "0.1.0"

           [compat]
           julia = "1.9"    
           """,
                )
            end

            @test isempty(SetupDevEnv.get_dependencies(project_path))
        end

        @testset "test filter" begin
            project_path = joinpath(tmp_path, "Project2.toml")
            open(project_path, "w") do f
                write(
                    f,
                    """
           name = "QED"
           uuid = "bb1fba1d-cf9b-41b3-874e-4b81465537b9"
           authors = ["Uwe Hernandez Acosta <u.hernandez@hzdr.de>", "Simeon Ehrig", "Klaus Steiniger", "Tom Jungnickel", "Anton Reinhard"]
           version = "0.1.0"

           [deps]
           QEDbase = "10e22c08-3ccb-4172-bfcf-7d7aa3d04d93"
           QEDevents = "fc3ce04a-5be5-4f3a-acff-eceaab723759"
           QEDfields = "ac3a6c97-e859-4b9f-96bb-63d2a216042c"
           QEDprocesses = "46de9c38-1bb3-4547-a1ec-da24d767fdad"
           PhysicalConstants = "5ad8b20f-a522-5ce9-bfc9-ddf1d5bda6ab"
           Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
           SimpleTraits = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
           SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

           [compat]
           julia = "1.9"    
           """,
                )
            end
            @test length(SetupDevEnv.get_dependencies(project_path)) == 8
            @test length(SetupDevEnv.get_dependencies(project_path, r"^QED")) == 4
            @test length(SetupDevEnv.get_dependencies(project_path, r"^Simple")) == 1
            @test length(SetupDevEnv.get_dependencies(project_path, r"^S")) == 2
            @test length(SetupDevEnv.get_dependencies(project_path, "SparseArrays")) == 1
        end
    end
end
