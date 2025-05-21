using TOML

@testset "set_compat_helper()" begin
    project_toml_string = """
    name = "QuantumElectrodynamics"
    uuid = "bb1fba1d-cf9b-41b3-874e-4b81465537b9"
    authors = ["Uwe Hernandez Acosta <u.hernandez@hzdr.de>", "Simeon Ehrig", "Klaus Steiniger", "Tom Jungnickel", "Anton Reinhard"]
    version = "0.1.0"

    [deps]
    QEDFeynmanDiagrams = "3232ad24-8ec1-4588-843e-e2ed2eae1ff3"
    QEDbase = "10e22c08-3ccb-4172-bfcf-7d7aa3d04d93"
    QEDcore = "35dc0263-cb5f-4c33-a114-1d7f54ab753e"

    [compat]
    julia = "1.9"
    QEDFeynmanDiagrams = "0.1.0"
    QEDbase = "0.4"
    QEDcore = "0.3"    
    """

    project_toml = TOML.parse(project_toml_string)

    @testset "change single entry" begin
        tmp_path = mktempdir()
        project_path = joinpath(tmp_path, "Project.toml")
        open(project_path, "w") do f
            write(
                f,
                project_toml_string,
            )
        end

        disable_info_logger_output() do
            CI.set_compat_helper("QEDcore", "1.0", tmp_path)
        end

        modified_project_toml = TOML.parsefile(project_path)

        expected_project_toml = deepcopy(project_toml)
        expected_project_toml["compat"]["QEDcore"] = "1.0"

        @test modified_project_toml == expected_project_toml
    end

    @testset "change non existing entry" begin
        tmp_path = mktempdir()
        project_path = joinpath(tmp_path, "Project.toml")
        open(project_path, "w") do f
            write(
                f,
                project_toml_string,
            )
        end

        disable_info_logger_output() do
            CI.set_compat_helper("QEDBigWhoop", "1.0", tmp_path)
        end

        modified_project_toml = TOML.parsefile(project_path)

        @test modified_project_toml == project_toml
    end

end
