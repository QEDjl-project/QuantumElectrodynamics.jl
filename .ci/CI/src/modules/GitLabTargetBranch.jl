module GitLabTargetBranch

using HTTP
using JSON
using Pkg

"""
    is_pull_request()::Bool

Checks whether the GitLab CI mirror branch was created by a GitHub pull request.

# Return
    true if is a Pull Request branch, otherwise false
"""
function is_pull_request()::Bool
    # GitLab CI provides the environemnt variable with the following pattern
    # # pr-<PR number>/<repo owner of the source branch>/<project name>/<source branch name> 
    # e.g. pr-41/SimeonEhrig/QuantumElectrodynamics.jl/setDevDepDeps
    if !haskey(ENV, "CI_COMMIT_REF_NAME")
        error("Environment variable CI_COMMIT_REF_NAME is not set.")
    end

    return startswith(ENV["CI_COMMIT_REF_NAME"], "pr-")
end

"""
    get_build_branch()::AbstractString

Returns the build branch except for version tags. In this case, main is returned.
    
# Return
    build branch name
"""
function get_build_branch()::AbstractString
    if !haskey(ENV, "CI_COMMIT_REF_NAME")
        error("Environment variable CI_COMMIT_REF_NAME is not set.")
    end

    ci_commit_ref_name = string(ENV["CI_COMMIT_REF_NAME"])

    try
        VersionNumber(ci_commit_ref_name)
        # branch is a version tag
        return "main"
    catch
        return ci_commit_ref_name
    end
end

"""
    get_target_branch_pull_request()::AbstractString

Returns the name of the target branch of the pull request. The function is required for our special
setup where we mirror a PR from GitHub to GitLab CI. No merge request will be open on GitLab.
Instead, a feature branch will be created and the commit will be pushed. As a result, we lose
information about the original PR. So we need to use the GitHub Rest API to get the information
depending on the repository name and PR number.
"""
function get_target_branch_pull_request()::AbstractString
    # GitLab CI provides the environemnt variable with the following pattern
    # # pr-<PR number>/<repo owner of the source branch>/<project name>/<source branch name> 
    # e.g. pr-41/SimeonEhrig/QuantumElectrodynamics.jl/setDevDepDeps
    if !haskey(ENV, "CI_COMMIT_REF_NAME")
        error("Environment variable CI_COMMIT_REF_NAME is not set.")
    end

    splited_commit_ref_name = split(ENV["CI_COMMIT_REF_NAME"], "/")

    if (!startswith(splited_commit_ref_name[1], "pr-"))
        # fallback for unknown branches and dev branch
        return "dev"
    end

    # parse to Int only to check if it is a number
    pr_number = parse(Int, splited_commit_ref_name[1][(length("pr-") + 1):end])
    if (pr_number <= 0)
        error(
            "a PR number always needs to be a positive integer number bigger than 0: $pr_number",
        )
    end

    repository_name = splited_commit_ref_name[3]

    try
        headers = (
            ("Accept", "application/vnd.github+json"),
            ("X-GitHub-Api-Version", "2022-11-28"),
        )
        # in all cases, we assume that the PR targets the repositories in QEDjl-project
        # there is no environment variable with the information, if the target repository is
        # the upstream repository or a fork.
        url = "https://api.github.com/repos/QEDjl-project/$repository_name/pulls/$pr_number"
        response = HTTP.get(url, headers)
        response_text = String(response.body)
        repository_data = JSON.parse(response_text)
        return repository_data["base"]["ref"]
    catch e
        # if for unknown reason, the PR does not exist, use fallback the dev branch
        if isa(e, HTTP.Exceptions.StatusError) && e.status == 404
            return "dev"
        else
            # Only the HTML code 404, page does not exist is handled. All other error will abort
            # the script.  
            throw(e)
        end
    end

    return "dev"
end

"""
    get_target()::AbstractString

Return the correct target branch name for our GitLab CI mirror setup.

# Return

    target branch name
"""
function get_target()::AbstractString
    if is_pull_request()
        return get_target_branch_pull_request()
    else
        return get_build_branch()
    end
end

end
