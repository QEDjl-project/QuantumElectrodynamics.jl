"""
    is_github_pull_request(ci_commit_ref_name::AbstractString)::Bool

Check if `ci_commit_ref_name` could point to a GitHub Pull Request.
`CI_COMMIT_REF_NAME` has a special shape in GitLab CI if it points to a GitHub Pull Request.
The shape is `pr-<PR number>/<repo owner of the source branch>/<project name>/<source branch name>`, 
e.g: `pr-41/SimeonEhrig/QuantumElectrodynamics.jl/setDevDepDeps`
"""
is_github_pull_request(ci_commit_ref_name::AbstractString)::Bool = startswith(ci_commit_ref_name, "pr-")


"""
    parse_gitlab_ci_pull_request(
        ci_commit_ref_name::AbstractString,
        github_user::AbstractString = "QEDjl-project"
    )::GitHubPR
   
Parse `ci_commit_ref_name` and return GitHubPR information object.

# Args
- `ci_commit_ref_name::AbstractString`: String to be parsed. See docstring of `is_github_pull_request`.
- `github_user::AbstractString`: Overwrites GitHub user with this value in the returned object (default: "QEDjl-project")

# Return

Information about the related GitHub Pull Request 
"""
function parse_gitlab_ci_pull_request(
        ci_commit_ref_name::AbstractString,
        github_user::AbstractString = "QEDjl-project"
    )::GitHubPR
    split_commit_ref_name = split(ci_commit_ref_name, "/")

    if length(split_commit_ref_name) < 3
        throw(ErrorException("ci_commit_ref_name cannot be spited in 3 or more components."))
    end

    for component in split_commit_ref_name
        if component == ""
            throw(ErrorException("one of the components of ci_commit_ref_name is empty."))
        end
    end

    if (!startswith(split_commit_ref_name[1], "pr-"))
        throw(ErrorException("ci_commit_ref_name needs to start with `pr-`"))
    end

    # parse to Int only to check if it is a number
    pr_number = parse(Int, split_commit_ref_name[1][(length("pr-") + 1):end])
    if (pr_number <= 0)
        throw(
            ErrorException(
                "a PR number always needs to be a positive integer number bigger than 0: $pr_number",
            )
        )
    end

    repository_name = split_commit_ref_name[3]

    return GitHubPR(github_user, repository_name, pr_number)
end
