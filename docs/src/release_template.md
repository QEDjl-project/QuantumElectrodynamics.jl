# Release Pipeline

The following is a template that can be used to open issues for a specific release of one of the QED-project packages. Customize it by simply replacing `<version>` with the version to-be-released.

```md
With this issue, we keep track of the workflow for version `<version>` release.

## Preparation for the release

- [ ] Tag all PRs that are part of this release by adding them to a milestone named `Release-<version>`.
- [ ] Create a release branch `release-<version>` on your fork.
- [ ] Adjust `./Project.toml` on the new `release-<version>` branch by ticking up the version.
- [ ] Add/Update the file `./CHANGELOG.md` on the `release-<version>` branch by appending a summary section. This can be done by using the tagged PRs associated with this release.

## Release procedure

- [ ] Open a PR for merging `release-<version>` into the `main`-branch of the QEDjl-project repository with at least one reviewer who only needs to check the points above, the code additions were reviewed in the respective PRs. Do not delete the `release-<version>` branch yet. :warning: **Do not squash this PR, use a simple merge commit** :warning:
- [ ] *After* the release branch is merged into `main`, open another PR for merging `release-<version>` into the `dev`-branch of the QEDjl-project repository. This can be merged without much review because the relevant changes were already reviewed in the PR `release-<version> -> main`. After this merge, you are free to delete the `release-<version>`-branch on your fork. :warning: **Do not squash this PR, use a simple merge commit** :warning:
- [ ] Registration: Go to the issues and search for `Release`. There, write a comment with `<at>JuliaRegistrator register(branch="main")` with a real `@` to trigger the registration bot opening a PR on Julia's general registry. 
- [ ] *After* the registration bot reports back the correct registration, tag the HEAD of `main` (which should still be the merge commit from the release branch merge) with `v<version>`. This will trigger a new deployment of the stable docs for the new version.
- [ ] Build a GitHub release from the latest tagged commit on `main` and add the respective section from `CHANGELOG.md` to the release notes.
```
