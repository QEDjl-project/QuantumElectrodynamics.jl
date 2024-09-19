# Development Guide

In this file we explain the release and developing processes we follow in all of the QED-project Julia packages.

## General

We use the [GitFlow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) workflow. In short, this means we use a `dev` branch to continuously develop on, and a `main` branch that has the latest released version. Once enough changes have been merged into dev to warrant a new release, a release branch is created from `dev`, adding the latest changelog and increasing the version number. It is then merged into `main` and also back into `dev` to create the new common root of the two branches.

In the following, the different possible situations are explained in more detail.

## Merging a Feature Branch

To create a new feature, create a new branch from the current `dev` and push it onto a fork. Once you have developed, committed, and pushed the changes to the repository, open a pull request to `dev` of the official repository. Automatic tests will then check that the code is properly formatted, that the documentation builds, and that tests pass. If all of these succeed, the feature branch can be merged after approval of one of the maintainers of the repository.

### CI Testing

There are two types of tests that run automatically when a pull request is opened: Unit tests, which only test the functionality in the current repository, and integration tests, which check whether other downstream packages (i.e. packages that depend on the current repository) still work with the code updates.

In case breaking changes are introduced by the pull request the integration tests will fail and an additional pull request has to be opened in each breaking package, fixing the incompatibility. For details on how this works, refer to the [CI documentation](ci.md#Integration-Tests-for-CI-Users).

## Releasing a New Version

Several steps are involved in releasing a new version of a package. For versioning, we follow [Julia's versioning guidelines](https://julialang.org/blog/2019/08/release-process/). However, we do not provide patches for previous minor or major versions.

### Release Issue Template

The following is a template that can be used to open issues for a specific release of one of the QED-project packages. Customize it by simply replacing `<version>` with the version to-be-released.

```md
With this issue, we keep track of the workflow for version `<version>` release.

## Preparation for the release

- [ ] Tag all PRs that are part of this release by adding them to a milestone named `Release-<version>`.
- [ ] Create a release branch `release-<version>` on your fork.
- [ ] Adjust `./Project.toml` on the new `release-<version>` branch by ticking up the version.
- [ ] Check if it is necessary to adjust the `compat` entry of upstream QED-project packages.
- [ ] Add/Update the file `./CHANGELOG.md` on the `release-<version>` branch by appending a summary section. This can be done by using the tagged PRs associated with this release.

## Release procedure

- [ ] Open a PR for merging `release-<version>` into the `main`-branch of the QEDjl-project repository with at least one reviewer who only needs to check the points above, the code additions were reviewed in the respective PRs. Do not delete the `release-<version>` branch yet. :warning: **Do not squash this PR, use a simple merge commit** :warning:
- [ ] *After* the release branch is merged into `main`, open another PR for merging `release-<version>` into the `dev`-branch of the QEDjl-project repository. This can be merged without much review because the relevant changes were already reviewed in the PR `release-<version> -> main`. After this merge, you are free to delete the `release-<version>`-branch on your fork. :warning: **Do not squash this PR, use a simple merge commit** :warning:
- [ ] Registration: Go to the issues and search for `Release`. There, write a comment with `<at>JuliaRegistrator register(branch="main")` with a real `@` to trigger the registration bot opening a PR on Julia's general registry. Also add a small general description of the release, so TagBot adds it to the GitHub release later.
- [ ] Once the registration is completed, check that the TagBot correctly tagged the version and built a GitHub release.
```

### Releasing Breaking Changes

Just as with merging breaking changes into `dev`, when releasing breaking changes, extra care has to be taken. When a release contains breaking changes, some of the release-version integration tests will fail. In this case, the major version should be increased (or the minor version for versions `0.x.y`). This prevents the released downstream packages from failing since they have a `compat` entry, choosing the latest working version. 

The dev-integration tests assure that the latest `dev`s of all packages still work together. This means that the depending package can now be released, after changing the `compat` entry of the base package in the release branch accordingly.
