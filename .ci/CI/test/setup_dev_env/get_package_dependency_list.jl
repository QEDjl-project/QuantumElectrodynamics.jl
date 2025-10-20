@testset "get_package_dependency_list.jl: 4-level graph" begin
    graph = Dict{Any, Any}(
        "QuantumElectrodynamics" => Dict{Any, Any}(
            "QEDevents" => Dict{Any, Any}(
                "QEDbase" => Dict{Any, Any}(),
                "QEDcore" => Dict{Any, Any}(
                    "QEDbase" => Dict{Any, Any}()
                )
            ),
            "QEDfields" => Dict{Any, Any}(
                "QEDbase" => Dict{Any, Any}(),
                "QEDcore" => Dict{Any, Any}(
                    "QEDbase" => Dict{Any, Any}()
                )
            ),
            "QEDprocesses" => Dict{Any, Any}(
                "QEDbase" => Dict{Any, Any}(),
                "QEDcore" => Dict{Any, Any}(
                    "QEDbase" => Dict{Any, Any}()
                )
            ),
            "QEDbase" => Dict{Any, Any}(),
            "QEDFeynmanDiagrams" => Dict{Any, Any}(
                "QEDbase" => Dict{Any, Any}(),
                "QEDcore" => Dict{Any, Any}(
                    "QEDbase" => Dict{Any, Any}()
                )
            ),
            "QEDcore" => Dict{Any, Any}(
                "QEDbase" => Dict{Any, Any}()
            )
        )
    )

    @testset "stop: QuantumElectrodynamics" begin
        disable_info_logger_output() do
            original_graph = deepcopy(graph)

            pkg_ordering = CI.get_package_dependency_list(graph, "QuantumElectrodynamics", "QuantumElectrodynamics")

            # verify that CI.get_package_dependency_list does not modify the graph
            @test original_graph == graph
            @test length(pkg_ordering) == 4
            @test pkg_ordering[1] == Set{String}(["QEDbase"])
            @test pkg_ordering[2] == Set{String}(["QEDcore"])
            @test pkg_ordering[3] == Set{String}(
                [
                    "QEDevents",
                    "QEDfields",
                    "QEDprocesses",
                    "QEDFeynmanDiagrams",
                ]
            )
            @test pkg_ordering[4] == Set{String}(["QuantumElectrodynamics"])
        end
    end

    @testset "stop: QEDfields" begin
        disable_info_logger_output() do
            pkg_ordering = CI.get_package_dependency_list(graph, "QuantumElectrodynamics", "QEDfields")

            @test length(pkg_ordering) == 3
            @test pkg_ordering[1] == Set{String}(["QEDbase"])
            @test pkg_ordering[2] == Set{String}(["QEDcore"])
            @test pkg_ordering[3] == Set{String}(["QEDfields"])
        end
    end

    @testset "stop: QEDcore" begin
        disable_info_logger_output() do
            pkg_ordering = CI.get_package_dependency_list(graph, "QuantumElectrodynamics", "QEDcore")

            @test length(pkg_ordering) == 2
            @test pkg_ordering[1] == Set{String}(["QEDbase"])
            @test pkg_ordering[2] == Set{String}(["QEDcore"])
        end
    end

    @testset "stop: QEDbase" begin
        disable_info_logger_output() do
            pkg_ordering = CI.get_package_dependency_list(graph, "QuantumElectrodynamics", "QEDbase")

            @test length(pkg_ordering) == 1
            @test pkg_ordering[1] == Set{String}(["QEDbase"])
        end
    end

    @testset "stop: NoStop" begin
        disable_info_logger_output() do
            pkg_ordering = CI.get_package_dependency_list(graph, "QuantumElectrodynamics", "NoStop")

            @test length(pkg_ordering) == 4
            @test pkg_ordering[1] == Set{String}(["QEDbase"])
            @test pkg_ordering[2] == Set{String}(["QEDcore"])
            @test pkg_ordering[3] == Set{String}(
                [
                    "QEDevents",
                    "QEDfields",
                    "QEDprocesses",
                    "QEDFeynmanDiagrams",
                ]
            )
            @test pkg_ordering[4] == Set{String}(["QuantumElectrodynamics"])
        end
    end
end

@testset "get_package_dependency_list.jl: 5-level graph" begin
    graph = Dict{Any, Any}(
        "QuantumElectrodynamics" => Dict{Any, Any}(
            "QEDBigWhoop" => Dict{Any, Any}(
                "QEDFeynmanDiagrams" => Dict{Any, Any}(
                    "QEDbase" => Dict{Any, Any}(),
                    "QEDcore" => Dict{Any, Any}(
                        "QEDbase" => Dict{Any, Any}()
                    )
                ),
                "QEDevents" => Dict{Any, Any}(
                    "QEDbase" => Dict{Any, Any}(),
                    "QEDcore" => Dict{Any, Any}(
                        "QEDbase" => Dict{Any, Any}()
                    )
                ),
            ),
            "QEDevents" => Dict{Any, Any}(
                "QEDbase" => Dict{Any, Any}(),
                "QEDcore" => Dict{Any, Any}(
                    "QEDbase" => Dict{Any, Any}()
                )
            ),
            "QEDfields" => Dict{Any, Any}(
                "QEDbase" => Dict{Any, Any}(),
                "QEDcore" => Dict{Any, Any}(
                    "QEDbase" => Dict{Any, Any}()
                )
            ),
            "QEDprocesses" => Dict{Any, Any}(
                "QEDbase" => Dict{Any, Any}(),
                "QEDcore" => Dict{Any, Any}(
                    "QEDbase" => Dict{Any, Any}()
                )
            ),
            "QEDbase" => Dict{Any, Any}(),
            "QEDFeynmanDiagrams" => Dict{Any, Any}(
                "QEDbase" => Dict{Any, Any}(),
                "QEDcore" => Dict{Any, Any}(
                    "QEDbase" => Dict{Any, Any}()
                )
            ),
            "QEDcore" => Dict{Any, Any}(
                "QEDbase" => Dict{Any, Any}()
            )
        )
    )

    @testset "stop: QuantumElectrodynamics" begin
        disable_info_logger_output() do
            pkg_ordering = CI.get_package_dependency_list(graph, "QuantumElectrodynamics", "QuantumElectrodynamics")

            @test length(pkg_ordering) == 5
            @test pkg_ordering[1] == Set{String}(["QEDbase"])
            @test pkg_ordering[2] == Set{String}(["QEDcore"])
            @test pkg_ordering[3] == Set{String}(
                [
                    "QEDevents",
                    "QEDfields",
                    "QEDprocesses",
                    "QEDFeynmanDiagrams",
                ]
            )
            @test pkg_ordering[4] == Set{String}(["QEDBigWhoop"])
            @test pkg_ordering[5] == Set{String}(["QuantumElectrodynamics"])
        end
    end

    @testset "stop: QEDBigWhoop" begin
        disable_info_logger_output() do
            pkg_ordering = CI.get_package_dependency_list(graph, "QuantumElectrodynamics", "QEDBigWhoop")

            @test length(pkg_ordering) == 4
            @test pkg_ordering[1] == Set{String}(["QEDbase"])
            @test pkg_ordering[2] == Set{String}(["QEDcore"])
            @test pkg_ordering[3] == Set{String}(
                [
                    "QEDevents",
                    "QEDfields",
                    "QEDprocesses",
                    "QEDFeynmanDiagrams",
                ]
            )
            @test pkg_ordering[4] == Set{String}(["QEDBigWhoop"])
        end
    end

    @testset "stop: QEDFeynmanDiagrams" begin
        disable_info_logger_output() do
            pkg_ordering = CI.get_package_dependency_list(graph, "QuantumElectrodynamics", "QEDFeynmanDiagrams")

            @test length(pkg_ordering) == 3
            @test pkg_ordering[1] == Set{String}(["QEDbase"])
            @test pkg_ordering[2] == Set{String}(["QEDcore"])
            @test pkg_ordering[3] == Set{String}(["QEDFeynmanDiagrams"])
        end
    end

    @testset "stop: QEDfields" begin
        disable_info_logger_output() do
            pkg_ordering = CI.get_package_dependency_list(graph, "QuantumElectrodynamics", "QEDfields")

            @test length(pkg_ordering) == 3
            @test pkg_ordering[1] == Set{String}(["QEDbase"])
            @test pkg_ordering[2] == Set{String}(["QEDcore"])
            @test pkg_ordering[3] == Set{String}(["QEDfields"])
        end
    end
end
