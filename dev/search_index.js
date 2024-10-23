var documenterSearchIndex = {"docs":
[{"location":"ci/#Automatic-Testing","page":"Automatic Testing","title":"Automatic Testing","text":"","category":"section"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"In the QuantumElectrodynamics.jl eco-system, we use Continuous integration (CIs) for running automatic tests. Each time, when a pull request is opened on GitHub.com or changes are committed to an existing pull request, the CI pipeline is triggered and starts a test script. The result of the tests will be reported in the pull request. In QuantumElectrodynamics.jl, we distinguish between two kinds of tests","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"Unit tests: tests which check the functionality of the modified (sub-) package. Those tests can either run standalone or use the functionality of other (third-party) packages.\nIntegration tests: tests which check the interoperatebility of the modified package with all sub-packages. For example, if package A depends on package B and you change package B, the integration test will check, if package A still works with the new version of package B.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"The CI will first execute the unit tests. Then, if all unit tests are passed, the integration tests will be started.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"Our CI uses the GitLab CI because it allows us to use CI resources provided by HIFIS. There, we can use strong CPU runners and special runners for testing on Nvidia and AMD GPUs.","category":"page"},{"location":"ci/#Unit-Tests-for-CI-Users","page":"Automatic Testing","title":"Unit Tests for CI Users","text":"","category":"section"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"The unit tests are automatically triggered, if you open a pull request, which target the main or dev branch. Before the tests start, the CI sets up the test environment.  Thus, the Project.toml of the project is taken and the latest development version of each QuantumElectrodynamics.jl dependency is added. Other dependencies will regularly be resolved by the Julia Package manager. Afterwards the unit tests will be executed.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"You can also modify which version of a QuantumElectrodynamics.jl dependency should be used. For example if you need to test your code with a function, which is not merged in the development branch yet. Thus, you need to add a specific line to your commit message with the following format:","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"CI_UNIT_PKG_URL_<dep_name>: https://github.com/<user>/<dep_name>#<commit_hash>","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"You can find the <dep_name> name in the Project.toml of the dependent project. For example, let's assume the name of the dependent package is depLibrary. The url of the fork is https://github.com/user/depLibrary.jl and the required feature has the commit sha 45a753b.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"This commit extends function foo with a new\nfunction argument.\n\nThe function argument is required to control\nthe new functionality.\n\nIf you pass a 0, it has a special meaning.\n\nCI_UNIT_PKG_URL_depLibrary: https://github.com/user/depLibrary.jl#45a753b","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"It is also possible to set a custom URL for more than one package. Simply add an additional line with the format CI_UNIT_PKG_URL_<dep_name>: https://github.com/<user>/<dep_name>#<commit_hash> to the commit message.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"note: Note\nYou don't need to add a new commit to set custom URLs. You can modify the commit message with git commit --amend and force push to the branch. This also starts the CI pipeline again.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"There is a last job, which checks if lines starting with CI_UNIT_PKG_URL_ exist in the commit message of the latest commit. If so, the unit test will fail. This is required, because otherwise the merged code would depend on non merged changes in sub-packages and would be non-compatible.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"note: Note\nIf you use CI_UNIT_PKG_URL_, the CI pipeline will fail which does not mean that the actual tests are failing.","category":"page"},{"location":"ci/#Integration-Tests-for-CI-Users","page":"Automatic Testing","title":"Integration Tests for CI Users","text":"","category":"section"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"The integration tests are automatically triggered if you open a pull request that targets the main or dev branch, and the unit tests have passed. The integration tests itself are in an extra stage of the CI.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"(Image: CI pipeline with unit and integration tests)","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"If the tests pass successfully, you don't need to do anything. If they fail, i.e. the change breaks the interoperability with another package in the QuantumElectrodynamics.jl ecosystem, the pull request will suspend, and one has two options to proceed:","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"One can solve the problem locally, by changing the code of the modified (sub-) package. The workflow is the same as for fixing unit tests.\nOne needs to modify the depending package, which failed in the integration test. In the following, we describe how to provide the necessary changes to the downstream package and make the CI pass the integration tests, which will resume the pull request.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"For better understanding, the package currently modified by the pull request is called orig, and the package that depends on it is referred to as dep. This means in practice, the Project.toml of the project dep contains the dependency to orig. First, one should fork the package dep and checkout a new feature branch on this fork. The fix of the integration issue for dep is now developed on the feature branch. Once finished, the changes to dep are push to GitHub, and a pull request on dep is opened to check in the changes. By default, the unit test for dep should fail, because the CI in dep needs to use the modified version of orig. The solution for this problem is explained in the section Unit Test for CI Users. Using this, one should develop the fix on the feature branch until the CI of dep passes all unit tests. In this case, the original pull request in the upstream package orig can be resumed. Therefore, one needs to tell the CI of orig that the integration tests should use the fixed version package dep, which is still on the feature branch in a pull request on dep. In order to proceed, the CI on orig needs information on where the fix for dep is located. This is given to the CI of orig in a commit message on the origin branch of the pull request on orig, one just needs to add a new line with the following format to the commit message:","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"CI_INTG_PKG_URL_<dep_name>: https://github.com/<user>/<dep_name>#<commit_hash>","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"You can find the names of the environment variables in the section Environment Variables. For an example let's assume the name of the dep package is dep1.jl, user1 forked the package and the commit hash of the fix for package dep1.jl is 45a723b. Then, an example message could look like this:","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"This commit extends function foo with a new\nfunction argument.\n\nThe function argument is required to control\nthe new functionality.\n\nIf you pass a 0, it has a special meaning.\n\nCI_INTG_PKG_URL_DEP1JL: https://github.com/user1/dep1.jl#45a723b","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"It is also possible to set a custom URL for more than one package, which depends on orig. Simply add an additional line of the shape CI_INTG_PKG_URL_<dep_name>: https://github.com/<user>/<dep_name>#<commit_hash> to the commit message.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"note: Note\nYou don't need to add a new commit to set custom URLs. You can modify the commit message with git commit --amend and force push to the branch. This also starts the CI pipeline again.","category":"page"},{"location":"ci/#Environment-Variables","page":"Automatic Testing","title":"Environment Variables","text":"","category":"section"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"The following table shows the names of the environment variables to use custom URLs for the unit and integration tests.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"Package Name Unit Test Integration Test\nQEDbase.jl CI_UNIT_PKG_URL_QEDbase CI_INTG_PKG_URL_QEDbase\nQEDcore.jl CI_UNIT_PKG_URL_QEDcore CI_INTG_PKG_URL_QEDcore\nQEDevents.jl CI_UNIT_PKG_URL_QEDevents CI_INTG_PKG_URL_QEDevents\nQEDfields.jl CI_UNIT_PKG_URL_QEDfields CI_INTG_PKG_URL_QEDfields\nQEDprocesses.jl CI_UNIT_PKG_URL_QEDprocesses CI_INTG_PKG_URL_QEDprocesses","category":"page"},{"location":"ci/#Unit-Tests-for-CI-Develops","page":"Automatic Testing","title":"Unit Tests for CI Develops","text":"","category":"section"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"In this section, we explain how the unit tests are prepared and executed. It is not mandatory to read the section if you only want to use the CI.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"Before the unit tests are executed, the SetupDevEnv.jl is executed, which prepares the project environment for the unit test. It reads the Project.toml of the current project and adds the version of the dev branch of all QED dependency (Pkg.develop()) if no line starting with CI_UNIT_PKG_URL_ was defined in the commit message. If CI_UNIT_PKG_URL_ was defined, it will use the custom URL.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"The commit message is defined in the environment variable CI_COMMIT_MESSAGE by GitLab CI. If the variable is not defined, the script ignores the commit message. If you want to disable reading the commit message, you can set the name of the commit message variable to an undefined variable via the first argument of the integTestGen.jl script. We use this when executing the CI on the main or dev branch. On these branches, it should not be possible to use custom URLs for unit or integration tests. Therefore we disable it, which also allows the use of CI_INTG_PKG_URL_ variables as regular part of the merge commit message.","category":"page"},{"location":"ci/#Running-Locally","page":"Automatic Testing","title":"Running Locally","text":"","category":"section"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"If you want to run the script locally, you can set custom URLs via environment variables. For example:","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"CI_UNIT_PKG_URL_QEDbase=\"www.github.com/User/QEDbase#0e1593b\" CI_UNIT_PKG_URL_QEDfields=\"www.github.com/User/QEDfields#60324ad\" julia --project=/path/to/QED/repo SetupDevEnv.jl`","category":"page"},{"location":"ci/#Integration-Tests-for-CI-Develops","page":"Automatic Testing","title":"Integration Tests for CI Develops","text":"","category":"section"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"In this section, we explain how the integration tests are created and executed. It is not mandatory to read the section if you only want to use the CI. The following figure shows the stages of the CI pipeline:","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"(Image: detailed CI pipeline of the integration tests)","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"All of the following stages are executed in the CI pipeline of the package, where the code is modified. We name the package orig for easier understanding of the documentation. A package who uses orig is called user. In practice, this means the Project.toml of the project user contains the dependency to orig. A list of user is called users.","category":"page"},{"location":"ci/#Stage:-Unit-Tests","page":"Automatic Testing","title":"Stage: Unit Tests","text":"","category":"section"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"This stage executes the unit tests of orig via Pkg.test(). The integration tests are only executed, when the unit tests are passed. If the unit tests would not pass, it would test other (sub-) packages with the broken package orig and therefore we cannot expect, that the integration tests pass.","category":"page"},{"location":"ci/#Stage:-Generate-integration-Tests","page":"Automatic Testing","title":"Stage: Generate integration Tests","text":"","category":"section"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"The integration tests checks, if all (sub-) packages which use the package orig as dependency still work with the code modification of the current pull request.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"Before we talk about the details, here is a small overview on what the integTestGen.jl script is doing. First the CI needs to determine, which (sub-) packages has orig as dependency. Therefore the CI downloads the integTestGen.jl script from the QuantumElectrodynamics.jl project via git clone. The integTestGen.jl script finds out, which (sub-) package use orig and generates for each (sub-) package a new CI test job. So the output of the integTestGen.jl is a GitLab CI yaml file, which can be executed via GitLab CI child pipeline.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"The integTestGen.jl script traverses the dependency tree of QuantumElectrodynamics.jl package. Because each QED sub-package is a dependency of the QuantumElectrodynamics.jl package, the QuantumElectrodynamics.jl dependency tree contains implicitly all dependency trees of the sub-packages. So the script is traversing the tree and creating a list of sub-packages who depends on orig. This list is called users.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"For each user from the list of users we need to define a separate CI job. First, the job checkouts the dev branch of the git repository of user. Then it sets the modified version of orig as dependency (Pkg.develop(path=\"$CI_package_DIR\")). Finally, it executes the unit tests of user. The unit tests of user are tested with the code changes of the current pull request.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"If the dev branch of user does not work, it is also possible to define a custom git commit to a working commit via the git commit message of the pull request of orig. For more details see Integration Tests for CI Users.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"note: Note\nIf a sub-package triggers an integration test, the main package QuantumElectrodynamics.jl is passive. It does not get any notification or trigger any script. The repository is simply cloned.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"note: Note\nThe commit message is defined in the environment variable CI_COMMIT_MESSAGE by GitLab CI.  If the variable is not defined, the script ignores the commit message. If you want to disable reading the commit message, you can set the name of the commit message variable to an  undefined variable via the first argument of the integTestGen.jl script. We use this when  executing the CI on the main or dev branch. On these branches, it should not be possible  to use custom URLs for unit or integration tests. Therefore we disable it, which also allows  the use of CI_INTG_PKG_URL_ variables as regular part of the merge commit message.","category":"page"},{"location":"ci/#Stage:-Run-Integration-Tests","page":"Automatic Testing","title":"Stage: Run Integration Tests","text":"","category":"section"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"This stage uses the generated job yaml to create and run new test jobs. It uses the GitLab CI child pipeline mechanism.","category":"page"},{"location":"ci/#Stage:-Integration-Tests-of-Sub-Packages-N","page":"Automatic Testing","title":"Stage: Integration Tests of Sub-Packages N","text":"","category":"section"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"Each job clones the repository of the sub-package. After the clone, it uses the Julia function Pkg.develop(path=\"$CI_package_DIR\") to replace the dependency to the package orig with the modified version of the pull request and execute the tests of the sub-package via Pkg.test().","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"The integration tests of each sub-package are executed in parallel. So, if the integration tests of a package fails, the integration tests of the other packages are still executed and can pass.","category":"page"},{"location":"ci/#Running-Locally-2","page":"Automatic Testing","title":"Running Locally","text":"","category":"section"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"The integTestGen.jl script has a special behavior. It creates its own Project.toml in a temporary folder and switches its project environment to it. Therefore, you need to start the script with the project path --project=ci/integTestGen. You also need to set two environment variables:","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"CI_DEPENDENCY_NAME: Name of the orig. For example QEDbase.\nCI_PROJECT_DIR: Path to the project root directory of orig. This path is used in the generated integration test, to set the dependency the modified code of orig.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"The following example assumes that the QuantumElectrodynamics.jl project is located at $HOME/projects/QuantumElectrodynamics.jl and the project to test is QEDbase.jl and is located at $HOME/projects/QEDbase.jl.","category":"page"},{"location":"ci/","page":"Automatic Testing","title":"Automatic Testing","text":"CI_DEV_PKG_NAME=QEDbase CI_PROJECT_DIR=\"$HOME/projects/QEDbase.jl\" julia --project=$HOME/projects/QuantumElectrodynamics.jl/ci/integTestGen $HOME/projects/QuantumElectrodynamics.jl/ci/integTestGen/src/integTestGen.jl","category":"page"},{"location":"dev_guide/#Development-Guide","page":"Development Guide","title":"Development Guide","text":"","category":"section"},{"location":"dev_guide/","page":"Development Guide","title":"Development Guide","text":"In this file we explain the release and developing processes we follow in all of the QED-project Julia packages.","category":"page"},{"location":"dev_guide/#General","page":"Development Guide","title":"General","text":"","category":"section"},{"location":"dev_guide/","page":"Development Guide","title":"Development Guide","text":"We use the GitFlow workflow. In short, this means we use a dev branch to continuously develop on, and a main branch that has the latest released version. Once enough changes have been merged into dev to warrant a new release, a release branch is created from dev, adding the latest changelog and increasing the version number. It is then merged into main and also back into dev to create the new common root of the two branches.","category":"page"},{"location":"dev_guide/","page":"Development Guide","title":"Development Guide","text":"In the following, the different possible situations are explained in more detail.","category":"page"},{"location":"dev_guide/#Merging-a-Feature-Branch","page":"Development Guide","title":"Merging a Feature Branch","text":"","category":"section"},{"location":"dev_guide/","page":"Development Guide","title":"Development Guide","text":"To create a new feature, create a new branch from the current dev and push it onto a fork. Once you have developed, committed, and pushed the changes to the repository, open a pull request to dev of the official repository. Automatic tests will then check that the code is properly formatted, that the documentation builds, and that tests pass. If all of these succeed, the feature branch can be merged after approval of one of the maintainers of the repository.","category":"page"},{"location":"dev_guide/#CI-Testing","page":"Development Guide","title":"CI Testing","text":"","category":"section"},{"location":"dev_guide/","page":"Development Guide","title":"Development Guide","text":"There are two types of tests that run automatically when a pull request is opened: Unit tests, which only test the functionality in the current repository, and integration tests, which check whether other downstream packages (i.e. packages that depend on the current repository) still work with the code updates.","category":"page"},{"location":"dev_guide/","page":"Development Guide","title":"Development Guide","text":"In case breaking changes are introduced by the pull request the integration tests will fail and an additional pull request has to be opened in each breaking package, fixing the incompatibility. For details on how this works, refer to the CI documentation.","category":"page"},{"location":"dev_guide/#Releasing-a-New-Version","page":"Development Guide","title":"Releasing a New Version","text":"","category":"section"},{"location":"dev_guide/","page":"Development Guide","title":"Development Guide","text":"Several steps are involved in releasing a new version of a package. For versioning, we follow Julia's versioning guidelines. However, we do not provide patches for previous minor or major versions.","category":"page"},{"location":"dev_guide/#Release-Issue-Template","page":"Development Guide","title":"Release Issue Template","text":"","category":"section"},{"location":"dev_guide/","page":"Development Guide","title":"Development Guide","text":"The following is a template that can be used to open issues for a specific release of one of the QED-project packages. Customize it by simply replacing <version> with the version to-be-released.","category":"page"},{"location":"dev_guide/","page":"Development Guide","title":"Development Guide","text":"With this issue, we keep track of the workflow for version `<version>` release.\n\n## Preparation for the release\n\n- [ ] Tag all PRs that are part of this release by adding them to a milestone named `Release-<version>`.\n- [ ] Create a release branch `release-<version>` on your fork.\n- [ ] Adjust `./Project.toml` on the new `release-<version>` branch by ticking up the version.\n- [ ] Check if it is necessary to adjust the `compat` entry of upstream QED-project packages.\n- [ ] Add/Update the file `./CHANGELOG.md` on the `release-<version>` branch by appending a summary section. This can be done by using the tagged PRs associated with this release.\n\n## Release procedure\n\n- [ ] Open a PR for merging `release-<version>` into the `main`-branch of the QEDjl-project repository with at least one reviewer who only needs to check the points above, the code additions were reviewed in the respective PRs. Do not delete the `release-<version>` branch yet. :warning: **Do not squash this PR, use a simple merge commit** :warning:\n- [ ] *After* the release branch is merged into `main`, open another PR for merging `release-<version>` into the `dev`-branch of the QEDjl-project repository. This can be merged without much review because the relevant changes were already reviewed in the PR `release-<version> -> main`. After this merge, you are free to delete the `release-<version>`-branch on your fork. :warning: **Do not squash this PR, use a simple merge commit** :warning:\n- [ ] Registration: Go to the issues and search for `Release`. There, write a comment with `<at>JuliaRegistrator register(branch=\"main\")` with a real `@` to trigger the registration bot opening a PR on Julia's general registry. Also add a small general description of the release, so TagBot adds it to the GitHub release later.\n- [ ] Once the registration is completed, check that the TagBot correctly tagged the version and built a GitHub release.","category":"page"},{"location":"dev_guide/#Releasing-Breaking-Changes","page":"Development Guide","title":"Releasing Breaking Changes","text":"","category":"section"},{"location":"dev_guide/","page":"Development Guide","title":"Development Guide","text":"Just as with merging breaking changes into dev, when releasing breaking changes, extra care has to be taken. When a release contains breaking changes, some of the release-version integration tests will fail. In this case, the major version should be increased (or the minor version for versions 0.x.y). This prevents the released downstream packages from failing since they have a compat entry, choosing the latest working version. ","category":"page"},{"location":"dev_guide/","page":"Development Guide","title":"Development Guide","text":"The dev-integration tests assure that the latest devs of all packages still work together. This means that the depending package can now be released, after changing the compat entry of the base package in the release branch accordingly.","category":"page"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = QuantumElectrodynamics","category":"page"},{"location":"#QuantumElectrodynamics.jl","page":"Home","title":"QuantumElectrodynamics.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"This is the documentation for QuantumElectrodynamics.jl. It represents the combination of the following subpackages:","category":"page"},{"location":"","page":"Home","title":"Home","text":"The two fundamental packages:","category":"page"},{"location":"","page":"Home","title":"Home","text":"QEDbase.jl: Interfaces and some functionality on abstract types. Docs\nQEDcore.jl: Implementation of core functionality that is needed across all or most content packages. Docs","category":"page"},{"location":"","page":"Home","title":"Home","text":"The content packages:","category":"page"},{"location":"","page":"Home","title":"Home","text":"QEDprocesses.jl: Scattering process definitions, models, and calculation of cross-sections and probabilities. Docs\nQEDevents.jl: Monte-Carlo event generation for scattering processes. Docs\nQEDfields.jl: Description of classical electromagnetic fields used in background-field approximations. Docs","category":"page"},{"location":"","page":"Home","title":"Home","text":"For detailed information on the packages, please refer to their respective docs, linked above.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [QuantumElectrodynamics]","category":"page"}]
}
