# Changelog

## Version 0.1.0

**Initial Release**

This release includes the incorporation of the following packages:
- [`QEDbase.jl`](https://github.com/QEDjl-project/QEDbase.jl)
- [`QEDcore.jl`](https://github.com/QEDjl-project/QEDcore.jl)
- [`QEDprocesses.jl`](https://github.com/QEDjl-project/QEDprocesses.jl)
- [`QEDevents.jl`](https://github.com/QEDjl-project/QEDevents.jl)
- [`QEDfields.jl`](https://github.com/QEDjl-project/QEDfields.jl)

Most of the functionality outside of these packages is concerned with continuous integration workflow files and generating integration tests.

### New features

- [#2](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/2): Add QED subpackages as dependencies
- [#3](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/3): Enable unit testing with custom URLs via commit message
- [#4](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/4): Add integration test generation
- [#15](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/15): Add code formatting to CI
- [#20](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/20): Add compat helper to CI
- [#24](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/24): Add documentation build job to CI
- [#41](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/41): Add script to set dependencies to their dev versions in integration tests for PRs to `main`
- [#43](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/43): Add script to determine PR target branch in GitLab CI
- [#44](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/44): Add script to set all dependencies to their `dev` versions
- [#45](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/45): Set dependencies to dev versions in doc building job when target is not main

### Fixes

- [#5](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/5): Disable custom subpackage URLs in dependent packages on `dev` and `main` branches
- [#10](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/10): Remove Compat helper
- [#14](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/14): Remove `Manifest.toml` since libraries should not rely on this
- [#19](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/19): Use dev branches instead of the registry to build dependency graph for integration tests
- [#25](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/25): Run compat helper only on upstream repositories
- [#31](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/31): Fix integration test generation after dependency updated
- [#32](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/32): Second fix for dependency update, changed overlooked function signature

### Maintenance

- [#11](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/11): Add install instructions
- [#17](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/17): Run unit tests with Julia versions `1.6` to `1.10` and `rc`
- [#26](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/26): Add compat entry for QEDprocesses (`v0.1`)
- [#38](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/38): Remove QEDprocesses compat
- [#39](https://github.com/QEDjl-project/QuantumElectrodynamics.jl/pull/39): Add new package QEDcore.jl to integration test package info
