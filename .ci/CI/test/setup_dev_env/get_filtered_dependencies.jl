@testset "get_filtered_dependencies()" begin
    tmp_path = mktempdir()

    @testset "no dependencies" begin
        project_path = joinpath(tmp_path, "Project1.toml")
        open(project_path, "w") do f
            write(
                f,
                """
                name = "QuantumElectrodynamics"
                uuid = "bb1fba1d-cf9b-41b3-874e-4b81465537b9"
                authors = ["Uwe Hernandez Acosta <u.hernandez@hzdr.de>", "Simeon Ehrig", "Klaus Steiniger", "Tom Jungnickel", "Anton Reinhard"]
                version = "0.1.0"

                [compat]
                julia = "1.9"
                """,
            )
        end

        disable_info_logger_output() do
            @test isempty(CI.get_filtered_dependencies(r".*", project_path))
        end
    end


    @testset "test filter" begin
        project_path = joinpath(tmp_path, "Project2.toml")
        open(project_path, "w") do f
            write(
                f,
                """
                name = "QuantumElectrodynamics"
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

        disable_info_logger_output() do
            @test length(CI.get_filtered_dependencies(r".*", project_path)) == 8
            @test length(CI.get_filtered_dependencies(r"^QED", project_path)) == 4
            @test length(CI.get_filtered_dependencies(r"^Simple", project_path)) == 1
            @test length(CI.get_filtered_dependencies(r"^S", project_path)) == 2
            @test length(CI.get_filtered_dependencies(r"SparseArrays", project_path)) == 1
        end
    end
end
