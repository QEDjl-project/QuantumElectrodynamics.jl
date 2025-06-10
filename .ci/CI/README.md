# bootloader.jl

## Usage

The `bootloader.jl` script generates the unit and integration tests depending on environment variables and script arguments. It also uses the dependencies in the `Project.toml` of a specific project to generate the integration tests for this project.

## Environment Variables

All environment variables are optional or have an alternative script argument. Please run `julia --project script/bootloader.jl --help` to display all script arguments.

- **CI_PROJECT_DIR**: Directory path of the package (containing the `Project.toml`) where the tests are generated for.
- **CI_COMMIT_REF_NAME**: Name of the target branch. In the case of a pull request, the environment variable must have a special pattern: `pr-<PR number>/<repo owner of the source branch>/<project name>/<source branch name>`, e.g: `pr-41/SimeonEhrig/QuantumElectrodynamics.jl/setDevDepDeps`.
- **CI_QED_UNIT_PKG_URL_<QED_PACKAGE_NAME>**: By default, the versions of the `dev` branch of the QED packages are used for the unit tests. The git clone can be overwritten by the environment variable `CI_QED_UNIT_PKG_URL_<QED_PACKAGE_NAME>=https://url/to/the/repository#<commit_hash>`.
- **CI_QED_INTG_PKG_URL_<QED_PACKAGE_NAME>**: When an integration test is created, the development branch of the upstream project is cloned by default. The clone can be overwritten by the environment variable `CI_QED_INTG_PKG_URL_<QED_PACKAGE_NAME>=https://url/to/the/repository#<commit_hash>`.
- **CI_COMMIT_MESSAGE**: Contains the git message. If a line begins with `CI_QED_UNIT_PKG_URL` or `CI_QED_INTG_PKG_URL_`, the same function is triggered as setting the environment variable `CI_QED_UNIT_PKG_URL_<QED_PACKAGE_NAME>` or `CI_QED_INTG_PKG_URL_<QED_PACKAGE_NAME>`.
- **CI_QED_UNIT_TEST_VERSIONS**: Set the Julia versions for the unit tests (e.g: `CI_QED_UNIT_TEST_VERSIONS=1.11, 1.12, rc, nightly`).
- **CI_QED_INTEG_TEST_VERSIONS**: Set the Julia versions for the integration tests (e.g: `CI_QED_INTEG_TEST_VERSIONS=1.11, 1.12, rc, nightly`).
- **CI_QED_ENABLE_CPU_TESTS**: Enable or disable generating unit tests for CPU.
- **CI_QED_ENABLE_CUDA_TESTS**: Enable or disable generating unit tests for Nvidia GPU.
- **CI_QED_ENABLE_AMDGPU_TESTS**: Enable or disable generating unit tests for AMD GPU.
- **CI_QED_ENABLE_INTEG_TESTS**: Enable or disable generating integration tests. Depending the enabled unit tests, integration tests for CPU, Nvidia and AMD GPU are generated.

You can set the environment variables in two different ways:

1. Permanent for the terminal session via: `export CI_PROJECT_DIR=/path/to/the/project`
2. Only for a single command (Julia call): `CI_PROJECT_DIR=/path/to/the/project CI_QED_DEV_PKG_NAME=QEDproject julia --project=. src/integTestGen.jl`

## Integration Tests for Pull Requests targeting the main branch

If we want to merge in the main branch, we do it because we want to publish the package. Therefore, we need to be sure that there is an existing version of the dependent QED packages that works with the new version of the package we want to release. The integration tests are tested against the development branch and the release version.

- The dev branch version must pass, as this means that the latest version of the other QED packages is compatible with our release version.
- The release version integration tests may or may not pass.
    1. If all of these pass, we will not need to increase the minor version of this package.
    2. If they do not all pass, the minor version must be increased and the failing packages must also be released later with an updated compat entry. In either case the release can proceed, as the released packages will continue to work because of their current compat entries.

# setup_dev_env.jl

## Usage

The script `setup_dev_env.jl` checks the dependencies of the current project and provides a Julia environment that provides all current development versions of the QED dependencies.

```bash
julia --project=. script/setup_dev_env.jl /path/to/the/julia/environment
```

# get_gitlab_ci_conf.jl

`get_gitlab_ci_conf.jl` reads the environment variable `CI_COMMIT_REF_NAME`. Depending on the value, it creates the environment variables for `bootloader.jl`. If the value of `CI_COMMIT_REF_NAME` encodes a reference to a GitHub pull request, all public information is pulled from it. The following information is grepped from the pull request.

## Pull Request Label support

If the pull request sets labels starting with `CI:`, `get_gitlab_ci_conf.jl` will parse them and compare them with dict [know_tags](./src/modules/GitLabCIConf/SetEnvVariables.jl). It removes the prefix `CI: ` (including spaces), strip the string and checks if it is defined in the `know_tags`. If it is defined, the corresponding environment variables are set.

## Optional Environment variables

All dependencies are added via `Pkg.develop("dep_name")` by default. Therefore the default development branch is used. To set a custom URL, you can define the environment variables `CI_QED_UNIT_PKG_URL_<dep_name>`. For example, you set the environment variable `CI_QED_UNIT_PKG_URL_QEDbase=https://github.com/User/QEDbase.jl#feature1`, the script will execute the command `Pkg.develop(url="https://github.com/User/QEDbase.jl#feature1")`, when the dependency QEDbase was found and matched in the `Project.toml`. Then the branch `feature1` from `https://github.com/User/QEDbase.jl` is used as a dependency.

The environment variable `CI_QED_SETUP_DEV_ENV_DRY_RUN=ON` can be set to activate the dry-run mode. In this mode, the project environment is not modified, only displaying logging information.

# Test Environment variables

The Julia tests are divided into two categories of tests - short and long running tests. The categories can be deactivated with the environment variables `DISABLE_CI_SHORT_TESTS=ON` and `CI_QED_DISABLE_LONG_TESTS=ON`.
