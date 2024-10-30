# Usage

The script `SetupDevEnv.jl` checks the dependencies of the current project and provides a Julia environment that provides all current development versions of the QED dependencies.

```bash
julia --project=/path/to/the/julia/environment src/SetupDevEnv.jl
```

# Optional Environment variables

All dependencies are added via `Pkg.develop("dep_name")` by default. Therefore the default development branch is used. To set a custom URL, you can define the environment variables `CI_UNIT_PKG_URL_<dep_name>`. For example, you set the environment variable `CI_UNIT_PKG_URL_QEDbase=https://github.com/User/QEDbase.jl#feature1`, the script will execute the command `Pkg.develop(url="https://github.com/User/QEDbase.jl#feature1")`, when the dependency QEDbase was found and matched in the `Project.toml`. Then the branch `feature1` from `https://github.com/User/QEDbase.jl` is used as a dependency.
