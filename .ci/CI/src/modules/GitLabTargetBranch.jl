using HTTP
using JSON
using Pkg

"""
    is_pull_request(ci_commit_ref_name::AbstractString)::Bool

Checks whether the GitLab CI mirror branch was created by a GitHub pull request.

# Args
- `ci_commit_ref_name::AbstractString`: The name of the GitLab CI branch of the mirror branch of a
    GitHub branch. The name encodes various information, e.g. whether it is a mirror branch of a 
    pull request. See find_target_branch()

# Return
    true if is a Pull Request branch, otherwise false
"""
function is_pull_request(ci_commit_ref_name::AbstractString)::Bool
    return startswith(ci_commit_ref_name, "pr-")
end

"""
    parse_non_pull_request(ci_commit_ref_name::AbstractString)::AbstractString

The function handles GitHub version tags. If `ci_commit_ref_name` does not target a pull request,
it contains either the tag or the name of the target branch. If it is tagged with a version number,
the branch main is returned, otherwise the content of `ci_commit_ref_name`.

# Args
- `ci_commit_ref_name::AbstractString`: The name of the GitLab CI branch of the mirror branch of a
    GitHub branch. The name encodes various information, e.g. whether it is a mirror branch of a 
    pull request. See find_target_branch()

# Return
    build branch name
"""
function parse_non_pull_request(ci_commit_ref_name::AbstractString)::AbstractString
    try
        VersionNumber(ci_commit_ref_name)
        # branch is a version tag
        return "main"
    catch
        return ci_commit_ref_name
    end
end

"""
    get_target_branch_pull_request(ci_commit_ref_name::AbstractString)::AbstractString

# Args
- `ci_commit_ref_name::AbstractString`: The name of the GitLab CI branch of the mirror branch of a
    GitHub branch. The name encodes various information, e.g. whether it is a mirror branch of a 
    pull request. See find_target_branch()

Returns the name of the target branch of the pull request. The function is required for our special
setup where we mirror a PR from GitHub to GitLab CI. No merge request will be open on GitLab.
Instead, a feature branch will be created and the commit will be pushed. As a result, we lose
information about the original PR. So we need to use the GitHub Rest API to get the information
depending on the repository name and PR number.
"""
function get_target_branch_pull_request(ci_commit_ref_name::AbstractString)::AbstractString
    split_commit_ref_name = split(ci_commit_ref_name, "/")

    if (!startswith(split_commit_ref_name[1], "pr-"))
        # fallback for unknown branches and dev branch
        return "dev"
    end

    # parse to Int only to check if it is a number
    pr_number = parse(Int, split_commit_ref_name[1][(length("pr-") + 1):end])
    if (pr_number <= 0)
        error(
            "a PR number always needs to be a positive integer number bigger than 0: $pr_number",
        )
    end

    repository_name = split_commit_ref_name[3]

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
    find_target_branch(ci_commit_ref_name::AbstractString)::AbstractString

Return the correct target branch name for our GitLab CI mirror setup.

# Args
- `ci_commit_ref_name::AbstractString`: The name of the GitLab CI branch of the mirror branch of a
    GitHub branch. The name encodes various information, e.g. whether it is a mirror branch of a 
    pull request.

The pattern of the branch name defined in ci_commit_ref_name is:
pr-<PR number>/<repo owner of the source branch>/<project name>/<source branch name> 
e.g. pr-41/SimeonEhrig/QuantumElectrodynamics.jl/setDevDepDeps

# Return

    target branch name
"""
function find_target_branch(ci_commit_ref_name::AbstractString)::AbstractString
    if is_pull_request(ci_commit_ref_name)
        return get_target_branch_pull_request(ci_commit_ref_name)
    else
        return parse_non_pull_request(ci_commit_ref_name)
    end
end
