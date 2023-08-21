# Usage

The application `SetupDevEnv.jl` takes a `Project.toml` and adds all dependencies which match a filter rule as the development version to the current Julia environment. The first application parameter sets the Project.toml path.

```bash
julia --project=/path/to/the/julia/environment src/SetupDevEnv.jl /path/to/Project.toml
```

# Optional Environment variables

All dependencies are added via `Pkg.develop("dep_name")` by default. Therefore the default development branch is used. To set a custom URL, you can define the environment variables `CI_UNIT_PKG_URL_<dep_name>`. For example, you set the environment variable `CI_UNIT_PKG_URL_QEDbase=https://github.com/User/QEDbase.jl#feature1`, the script will execute the command `Pkg.develop(url="https://github.com/User/QEDbase.jl#feature1")`, when the dependency QEDbase was found and matched in the `Project.toml`. Then the branch `feature1` from `https://github.com/User/QEDbase.jl` is used as a dependency.
