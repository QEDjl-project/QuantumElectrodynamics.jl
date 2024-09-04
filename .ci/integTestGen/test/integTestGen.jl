using PkgDependency

import Term.Trees: Tree
import PkgDependency.PkgTree

# set environment variable PRINTTREE=on to visualize the project trees of the testsets
# TODO(SimeonEhrig): add type ::Bool , when minimum version is Julia 1.9
printTree = haskey(ENV, "PRINTTREE")

@testset "direct dependency to main" begin
    project_tree = [PkgTree("MyMainProject.jl 1.0.0", [PkgTree("MyDep1.jl 1.0.0", [])])]

    if printTree
        display(
            PkgDependency.Tree(
                PkgTree("Direct dependency to main tree", project_tree);
                printkeys=false,
                print_node_function=PkgDependency.writenode,
            ),
        )
    end

    # dependency exist and prefix is correct
    @test integTestGen.depending_projects(
        "MyDep1.jl", ["MyMainProject.jl"], project_tree
    ) == ["MyMainProject.jl"]
    # dependency does not exist and prefix is correct
    @test isempty(
        integTestGen.depending_projects("MyDep2.jl", ["MyMainProject.jl"], project_tree)
    )
    # dependency exist and prefix is incorrect
    @test isempty(
        integTestGen.depending_projects("MyDep1.jl", ["ExternProject.jl"], project_tree)
    )
    # dependency does not exist and prefix is incorrect
    @test isempty(
        integTestGen.depending_projects("MyDep2.jl", ["ExternProject.jl"], project_tree)
    )
end

@testset "complex dependencies" begin
    #! format: off
    project_tree = [
        PkgTree("MyMainProject.jl 1.0.0", [
            PkgTree("MyDep1.jl 1.0.0", []),
            PkgTree("MyDep2.jl 1.0.0", [
                PkgTree("MyDep3.jl 1.0.0", []),
                PkgTree("ForeignDep1.jl 1.0.0", [])
            ]),
            PkgTree("ForeignDep2.jl 1.0.0", [
                PkgTree("ForeignDep3.jl 1.0.0", []),
                PkgTree("ForeignDep4.jl 1.0.0", [])
            ]),
            PkgTree("MyDep4.jl 1.0.0", [
                PkgTree("MyDep5.jl 1.0.0", [
                    PkgTree("MyDep3.jl 1.0.0", [])
                ])
            ]),
            PkgTree("ForeignDep2.jl 1.0.0", [
                PkgTree("MyDep5.jl 1.0.0", [
                    PkgTree("MyDep3.jl 1.0.0", [])
                ]),
                PkgTree("MyDep3.jl 1.0.0", []),
                PkgTree("MyDep6.jl 1.0.0", [
                    PkgTree("MyDep3.jl 1.0.0", [])
                ])
            ]),
            PkgTree("MyDep7.jl 1.0.0", [
                PkgTree("MyDep5.jl 1.0.0", [
                    PkgTree("MyDep3.jl 1.0.0", [])
                ]),
                PkgTree("MyDep3.jl 1.0.0", [])
            ])
        ])
    ]
    #! format: on
    if printTree
        display(
            PkgDependency.Tree(
                PkgTree("Complex dependency tree", project_tree);
                printkeys=false,
                print_node_function=PkgDependency.writenode,
            ),
        )
    end

    package_filter = [
        "MyMainProject.jl",
        "MyDep1.jl",
        "MyDep2.jl",
        "MyDep3.jl",
        "MyDep4.jl",
        "MyDep5.jl",
        "MyDep6.jl",
        "MyDep7.jl",
    ]

    # sort all vectors to guaranty the same order -> guaranty is not important for the actual result, onyl for comparison
    @test sort(
        integTestGen.depending_projects("MyDep1.jl", package_filter, project_tree)
    ) == sort(["MyMainProject.jl"])
    @test sort(
        integTestGen.depending_projects("MyDep2.jl", package_filter, project_tree)
    ) == sort(["MyMainProject.jl"])
    # MyDep5.jl should only appears one time -> MyDep4.jl and MyDep7.jl has the same MyDep5.jl dependency
    @test sort(
        integTestGen.depending_projects("MyDep3.jl", package_filter, project_tree)
    ) == sort(["MyDep2.jl", "MyDep5.jl", "MyDep7.jl"])
    @test sort(
        integTestGen.depending_projects("MyDep5.jl", package_filter, project_tree)
    ) == sort(["MyDep4.jl", "MyDep7.jl"])
    # cannot find MyDep6.jl, because it is only a dependency of a foreign package
    @test isempty(
        integTestGen.depending_projects("MyDep6.jl", package_filter, project_tree)
    )
    @test isempty(integTestGen.depending_projects("MyDep3.jl", ["Foo"], project_tree))
end

@testset "circular dependency" begin
    # I cannot create a real circular dependency with this data structur, but if Circulation appears in an output, we passed MyDep1.jl and MyDep2.jl two times, which means it is a circle

    #! format: off
    project_tree = [
        PkgTree("MyMainProject.jl 1.0.0", [
            PkgTree("MyDep1.jl 1.0.0", [
                PkgTree("MyDep2.jl 1.0.0", [
                    PkgTree("MyDep1.jl 1.0.0", [
                        PkgTree("MyDep2.jl 1.0.0", [
                            PkgTree("Circulation", [])
                        ])
                    ])
                ])
            ])
        ])
    ]
    #! format: on

    if printTree
        display(
            PkgDependency.Tree(
                PkgTree("Circular dependency tree", project_tree);
                printkeys=false,
                print_node_function=PkgDependency.writenode,
            ),
        )
    end

    package_filter = ["MyMainProject.jl", "MyDep1.jl", "MyDep2.jl"]

    @test sort(
        integTestGen.depending_projects("MyDep1.jl", package_filter, project_tree)
    ) == sort(["MyMainProject.jl", "MyDep2.jl"])
    @test sort(
        integTestGen.depending_projects("MyDep2.jl", package_filter, project_tree)
    ) == sort(["MyDep1.jl"])
    @test isempty(integTestGen.depending_projects("MyDep2.jl", ["Foo"], project_tree))
    @test isempty(
        integTestGen.depending_projects("Circulation", package_filter, project_tree)
    )
end
