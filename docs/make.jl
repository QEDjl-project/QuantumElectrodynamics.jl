using QED
using Documenter

DocMeta.setdocmeta!(QED, :DocTestSetup, :(using QED); recursive=true)

makedocs(;
    modules=[QED],
    authors="Uwe Hernandez Acosta <u.hernandez@hzdr.de>, Simeon Ehrig, Klaus Steiniger, Tom Jungnickel, Anton Reinhard",
    repo=Documenter.Remotes.GitHub("QEDjl-project", "QED.jl"),
    sitename="QED.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://qedjl-project.github.io/QED.jl/",
        edit_link="dev",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Automatic Testing" => "ci.md",
        "Development Guide" => "dev_guide.md",
    ],
)

deploydocs(; repo="github.com/QEDjl-project/QED.jl.git", push_preview=false)
