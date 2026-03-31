```@meta
CurrentModule = QuantumElectrodynamics
```

# QuantumElectrodynamics.jl

[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)
[![DOI](https://rodare.hzdr.de/badge/DOI/10.14278/rodare.4584.svg)](https://doi.org/10.14278/rodare.4584)

This is the documentation for [`QuantumElectrodynamics.jl`](https://github.com/QEDjl-project/QuantumElectrodynamics.jl). It represents the combination of the following subpackages:

**The two fundamental packages**:
- [`QEDbase.jl`](https://github.com/QEDjl-project/QEDbase.jl): Interfaces and some functionality on abstract types. [Docs](https://qedjl-project.github.io/QEDbase.jl/stable/)
- [`QEDcore.jl`](https://github.com/QEDjl-project/QEDcore.jl): Implementation of core functionality that is needed across all or most content packages. [Docs](https://qedjl-project.github.io/QEDcore.jl/stable/)

**The content packages**:
- [`QEDFeynmanDiagrams.jl`](https://github.com/QEDjl-project/QEDFeynmanDiagrams.jl): Generate functions for matrix element computation for arbitrary QED scattering processes. [Docs](https://qedjl-project.github.io/QEDFeynmanDiagrams.jl/stable/)
- [`QEDprocesses.jl`](https://github.com/QEDjl-project/QEDprocesses.jl): Scattering process definitions, models, and calculation of cross-sections and probabilities. [Docs](https://qedjl-project.github.io/QEDprocesses.jl/stable/)
- [`QEDevents.jl`](https://github.com/QEDjl-project/QEDevents.jl): Monte-Carlo event generation for scattering processes. [Docs](https://qedjl-project.github.io/QEDevents.jl/stable/)
- [`QEDfields.jl`](https://github.com/QEDjl-project/QEDfields.jl): Description of classical electromagnetic fields used in background-field approximations. [Docs](https://qedjl-project.github.io/QEDfields.jl/stable/)

For detailed information on the packages, please refer to their respective docs, linked above.

```@index
```

```@autodocs
Modules = [QuantumElectrodynamics]
```
