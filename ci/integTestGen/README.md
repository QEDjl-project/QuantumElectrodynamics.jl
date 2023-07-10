# Usage

The application `integTestGen.jl` is searching for all packages who are depend on the searched package. For each found package, it generates a job yaml. The script is configured via environment variables.

## Required Environment variables

- **CI_DEPENDENCY_NAME**: Name of the searched dependency.
- **CI_PROJECT_DIR**: Directory path of a package (containing the `Project.toml`) providing the dependency graph. Normally it is the absolute base path of the `QED.jl` project.

## Optional Environment variables

By default, if an integration test is generated it clones the develop branch of the upstream project. The clone can be overwritten by the environment variable `CI_INTG_PKG_URL_<dep_name>=https://url/to/the/repository#<commit_hash>`. You can find all available environment variables in the dictionary `package_infos` in the `integTestGen.jl`.
