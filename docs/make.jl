using QED
using Documenter

DocMeta.setdocmeta!(QED, :DocTestSetup, :(using QED); recursive=true)

makedocs(;
    modules=[QED],
    authors="Uwe Hernandez Acosta <u.hernandez@hzdr.de>, Simeon Ehrig, Klaus Steiniger, Tom Jungnickel, Anton Reinhard",
    repo="https://www.github.com/szabo137/QED.jl/blob/{commit}{path}#{line}",
    sitename="QED.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://szabo137.github.io/QED.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="www.github.com/szabo137/QED.jl",
    devbranch="main",
)
