using Pkg: Pkg
using YAML: YAML
using Logging
using IntegrationTests

"""
    generate_job_yaml!(
        package_name::String,
        test_package::TestPackage,
        target_branch::AbstractString,
        job_yaml::Dict,
        package_infos::AbstractDict{String,PackageInfo},
        tools_git_repo::ToolsGitRepo,
        stage::AbstractString="",
        can_fail::Bool=false,
    )

Creating a single job for integration tests of a specific package. Yaml is GitLab CI yaml.

# Args
- `package_name::String`: Name of the package to test.
- `test_package::TestPackage`: Contains name, version and base path of the package to test.
- `target_branch::AbstractString`: Name of the target branch of the pull request.
- `job_yaml::Dict`: Add generated job to this dict.
- `package_infos::AbstractDict{String,PackageInfo}`: Contains serveral information about QED
    packages
- `tools_git_repo::ToolsGitRepo`: Contains the URL of the Git repository and the branch from which
    the integration test tools are to be cloned.
- `stage::AbstractString=""`: Stage of the individual integration jobs. If the character string is
    empty, no stage property is set.
- `can_fail::Bool=false`: If true add `allow_failure=true` to the job yaml
"""
function generate_job_yaml!(
    package_name::String,
    test_package::TestPackage,
    target_branch::AbstractString,
    job_yaml::Dict,
    custom_urls::Dict{String,String},
    tools_git_repo::ToolsGitRepo,
    stage::AbstractString="",
    can_fail::Bool=false,
)
    if haskey(custom_urls, package_name)
        url = custom_urls[package_name]
    else
        url = "https://github.com/QEDjl-project/$(package_name).jl.git"
    end

    script = ["apt update", "apt install -y git", "cd /"]

    split_url = split(url, "#")
    if length(split_url) > 2
        error("Ill formed url: $(url)")
    end

    push!(script, "git clone -b $target_branch $(split_url[1]) integration_test")
    if (target_branch != "main")
        push!(
            script,
            "git clone -b $(tools_git_repo.branch) $(tools_git_repo.url) /integration_test_tools",
        )
    end
    push!(script, "cd integration_test")

    # checkout specfic branch given by the environemnt variable
    # CI_INTG_PKG_URL_<dep_name>=https://url/to/the/repository#<commit_hash>
    if length(split_url) == 2
        push!(script, "git checkout $(split_url[2])")
    end

    if (target_branch == "main")
        push!(
            script,
            "julia --project=. -e 'import Pkg; Pkg.develop(path=\"$(test_package.path)\");'",
        )
    else
        push!(script, "julia --project=. /integration_test_tools/.ci/CI/src/SetupDevEnv.jl")
    end
    push!(script, "julia --project=. -e 'import Pkg; Pkg.instantiate()'")
    push!(script, "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'")

    current_job_yaml = Dict(
        "image" => "julia:1.10",
        "variables" => Dict(
            "CI_DEV_PKG_NAME" => test_package.name,
            "CI_DEV_PKG_VERSION" => test_package.version,
            "CI_DEV_PKG_PATH" => test_package.path,
            "CI_TEST_TYPE" => "integ",
        ),
        "interruptible" => true,
        "tags" => ["cpuonly"],
        "script" => script,
    )

    if stage != ""
        current_job_yaml["stage"] = stage
    end

    if can_fail
        current_job_yaml["allow_failure"] = true
        return job_yaml["integration_test_$(package_name)_release_test"] = current_job_yaml
    else
        return job_yaml["integration_test_$package_name"] = current_job_yaml
    end
end

"""
    generate_dummy_job_yaml!(job_yaml::Dict)

Generates a GitLab CI dummy job, if required.

# Args
- `job_yaml::Dict`: Add generated job to this dict.
"""
function generate_dummy_job_yaml!(job_yaml::Dict)
    return job_yaml["DummyJob"] = Dict(
        "image" => "alpine:latest",
        "interruptible" => true,
        "script" => ["echo \"This is a dummy job so that the CI does not fail.\""],
    )
end

"""
    add_integration_test_job_yaml!(
        job_dict::Dict,
        test_package::TestPackage,
        target_branch::AbstractString,
        tools_git_repo::ToolsGitRepo,
    )

Generates all integration tests for the specified test_package. The jobs written in GitLab CI yaml
are added to job_dict.

# Args
- `job_dict::Dict`: Adds GitLab CI yaml to the dict.
- `test_package::TestPackage`: Contains information about the package to test.
- `target_branch::AbstractString`: Name of the target branch of the pull request.
- `tools_git_repo::ToolsGitRepo`: Contains the URL of the Git repository and the branch from which
    the integration test tools are to be cloned.
"""
function add_integration_test_job_yaml!(
    job_dict::Dict,
    test_package::TestPackage,
    target_branch::AbstractString,
    custom_urls::Dict{String,String},
    tools_git_repo::ToolsGitRepo,
)
    _add_stage_once!(job_dict, "integ-test")

    if target_branch == "main"
        empty!(custom_urls)
    end

    qed_path = mktempdir(; cleanup=false)
    compat_changes = Dict{String,String}()

    pkg_tree = build_qed_dependency_graph!(qed_path, compat_changes, custom_urls)
    depending_pkg = IntegrationTests.depending_projects(
        test_package.name, r"^QED*|^QuantumElectrodynamics$", pkg_tree
    )

    if isempty(depending_pkg)
        return Nothing
    end

    for p in depending_pkg
        # Handles the case of merging in the main branch. If we want to merge in the main branch, 
        # we do it because we want to publish the package. Therefore, we need to be sure that there 
        # is an existing version of the dependent QED packages that works with the new version of 
        # the package we want to release. The integration tests are tested against the development 
        # branch and the release version.
        #  - The dev branch version must pass, as this means that the latest version of the other 
        #    QED packages is compatible with our release version.
        #  - The release version integration tests may or may not pass. 
        #    1. If all of these pass, we will not need to increase the minor version of this package. 
        #    2. If they do not all pass, the minor version must be increased and the failing packages 
        #    must also be released later with an updated compat entry.
        #    In either case the release can proceed, as the released packages will continue to work
        #    because of their current compat entries.
        if target_branch == "main" && is_pull_request()
            generate_job_yaml!(
                p, test_package, "dev", job_dict, custom_urls, tools_git_repo, "integ-test"
            )
            generate_job_yaml!(
                p,
                test_package,
                "main",
                job_dict,
                custom_urls,
                tools_git_repo,
                "integ-test",
                true,
            )
        else
            generate_job_yaml!(
                p,
                test_package,
                # TODO: `dev` is the "default" branch
                # a possible, different branch is stored in package_info
                # simplify the interface
                "dev",
                job_dict,
                custom_urls,
                tools_git_repo,
                "integ-test",
            )
        end
    end
    return Nothing
end
