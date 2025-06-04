@testset "calculate_linear_dependency_ordering()" begin
    disable_info_logger_output() do
        pkg_dependecy_list = Vector{Set{String}}()
        push!(pkg_dependecy_list, Set(["QEDbase"]))
        push!(pkg_dependecy_list, Set(["QEDcore"]))
        push!(pkg_dependecy_list, Set(["QEDevents", "QEDfields", "QEDprocesses"]))
        push!(pkg_dependecy_list, Set(["QuantumElectrodynamics"]))

        # For the real world code, it does not matter what is the ordering of
        # entries in a set.
        # For the tests it does matter.
        # Therefore the current expected behavoir if we create a list from a set
        # is, that the output list has the same odering than the input list.
        # This behavior is implementation depend and can change
        @test [a for a in Set(["QEDevents", "QEDfields", "QEDprocesses"])] == ["QEDevents", "QEDfields", "QEDprocesses"]

        @test CI.calculate_linear_dependency_ordering(pkg_dependecy_list, ["NotInclude"]) == []

        @test CI.calculate_linear_dependency_ordering(pkg_dependecy_list, ["QEDbase"]) ==
            ["QEDbase"]
        @test CI.calculate_linear_dependency_ordering(
            pkg_dependecy_list, ["QEDbase", "QEDcore"]
        ) == ["QEDbase", "QEDcore"]

        @test CI.calculate_linear_dependency_ordering(pkg_dependecy_list, ["QEDcore"]) ==
            ["QEDbase", "QEDcore"]

        @test CI.calculate_linear_dependency_ordering(pkg_dependecy_list, ["QEDfields"]) ==
            ["QEDbase", "QEDcore", "QEDfields"]

        expected_processes_fields = vcat(
            ["QEDbase", "QEDcore"], [a for a in Set(["QEDfields", "QEDprocesses"])]
        )

        @test CI.calculate_linear_dependency_ordering(
            pkg_dependecy_list, ["QEDprocesses", "QEDfields"]
        ) == expected_processes_fields

        @test CI.calculate_linear_dependency_ordering(
            pkg_dependecy_list, ["QEDfields", "QEDprocesses"]
        ) == expected_processes_fields

        @test CI.calculate_linear_dependency_ordering(
            pkg_dependecy_list, ["QEDcore", "QEDfields"]
        ) == ["QEDbase", "QEDcore", "QEDfields"]

        # needs to be constructed from a set, because how a set is iterated is
        # implementation depend
        expected_QuantumElectrodynamics = vcat(
            ["QEDbase", "QEDcore"],
            [a for a in Set(["QEDevents", "QEDfields", "QEDprocesses"])],
            ["QuantumElectrodynamics"],
        )

        @test CI.calculate_linear_dependency_ordering(
            pkg_dependecy_list, ["QuantumElectrodynamics"]
        ) == expected_QuantumElectrodynamics
    end
end
