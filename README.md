# QED

[![Doc Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://qedjl-project.github.io/QED.jl/main)
[![Doc Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://qedjl-project.github.io/QED.jl/dev)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

## Installation

To install the current stable version of `QED.jl` you may use the standard julia package manager within the julia REPL

```julia
julia> using Pkg

# add local registry, where QED is registered
julia> Pkg.Registry.add(Pkg.RegistrySpec(url="https://github.com/QEDjl-project/registry"))
# add general registry again to have it join the local registry
julia> Pkg.Registry.add(Pkg.RegistrySpec(url="https://github.com/JuliaRegistries/General"))

julia> Pkg.add("QED")
```

or you use the Pkg prompt by hitting `]` within the Julia REPL and then type

```julia
# add local registry, where QED is registered
(@v1.9) pkg> registry add https://github.com/QEDjl-project/registry
# add general registry again to have it join the local registry
(@v1.9) pkg> registry add https://github.com/JuliaRegistries/General

(@v1.9) pkg> add QED
```

To install the locally downloaded package on Windows, change to the parent directory and type within the Pkg prompt

```julia
(@v1.9) pkg> add ./QED.jl
```
