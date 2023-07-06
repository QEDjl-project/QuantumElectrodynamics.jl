# Usage

The application `SetupDevEnv` takes a `Project.toml` and add all dependencies which match a filter rule as develop version to the current julia environment. The path to the `Project.toml` is set via first application parameter.

```bash
julia --project=/path/to/the/julia/environment src/SetupDevEnv.jl /path/to/Project.toml
```

# Optional Environment variables

By default, all dependencies are added via `Pkg.develop("dep_name")`. Therefore the default develop branch is used. You can define the environment variables `CI_UNIT_PKG_URL_<dep_name>` to set a custom url. For example, you set environment variable `CI_UNIT_PKG_URL_QEDbase=https://github.com/User/QEDbase.jl#feature1`, the script will execute the command `Pkg.develop(url="https://github.com/User/QEDbase.jl#feature1")`, when the dependency `QEDbase` was found and matched in the `Project.toml`. Then the branch `feature1` from `https://github.com/User/QEDbase.jl` is used as dependency.
