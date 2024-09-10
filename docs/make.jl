using QuantumElectrodynamics
using Documenter

DocMeta.setdocmeta!(
    QuantumElectrodynamics, :DocTestSetup, :(using QuantumElectrodynamics); recursive=true
)

makedocs(;
    modules=[QuantumElectrodynamics],
    authors="Uwe Hernandez Acosta <u.hernandez@hzdr.de>, Simeon Ehrig, Klaus Steiniger, Tom Jungnickel, Anton Reinhard",
    repo=Documenter.Remotes.GitHub("QEDjl-project", "QuantumElectrodynamics.jl"),
    sitename="QuantumElectrodynamics.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://qedjl-project.github.io/QuantumElectrodynamics.jl/",
        edit_link="dev",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Automatic Testing" => "ci.md",
        "Development Guide" => "dev_guide.md",
    ],
)

deploydocs(;
    repo="github.com/QEDjl-project/QuantumElectrodynamics.jl.git", push_preview=false
)
