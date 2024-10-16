# Usage

The application `integTestGen.jl` searches for all packages that depend on the searched package. For each package found, a job yaml is generated. The script is configured via environment variables.

## Required Environment Variables

- **CI_DEV_PKG_NAME**: Name of the searched dependency.
- **CI_PROJECT_DIR**: Directory path of a package (containing the `Project.toml`) providing the dependency graph. Usually it is the absolute base path of the `QuantumElectrodynamics.jl` project.

You can set the environment variables in two different ways:

1. Permanent for the terminal session via: `export CI_PROJECT_DIR=/path/to/the/project`
2. Only for a single command (Julia call): `CI_PROJECT_DIR=/path/to/the/project CI_DEV_PKG_NAME=QEDproject julia --project=. src/integTestGen.jl`

## Optional Environment Variables

By default, if an integration test is generated it clones the develop branch of the upstream project. The clone can be overwritten by the environment variable `CI_INTG_PKG_URL_<dep_name>=https://url/to/the/repository#<commit_hash>`. You can find all available environment variables in the dictionary `package_infos` in the `integTestGen.jl`.

Set the environment variable `CI_COMMIT_REF_NAME` to determine the target branch of a GitHub pull request. The form must be `CI_COMMIT_REF_NAME=pr-<PR number>/<repo owner of source branch>/<project name>/<source branch name>`. Here is an example: `CI_COMMIT_REF_NAME=pr-41/SimeonEhrig/QuantumElectrodynamics.jl/setDevDepDeps`. If the environment variable is not set, the default target branch `dev` is used.
