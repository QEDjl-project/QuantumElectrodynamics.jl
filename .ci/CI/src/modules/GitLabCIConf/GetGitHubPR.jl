using GitHub

# cache pull request information
github_pr_cache = Dict{GitHubPR, GitHub.PullRequest}()

"""
    pull_github_pull_request(gh_pr::GitHubPR)::GitHub.PullRequest

Do a web request and get information about an pull request.

# Args

- `github_pull_request_info::GitHubPR`: Contains "address" of the pull request.

# Return

All information about the pull request.
"""
function pull_github_pull_request(github_pull_request_info::GitHubPR)::GitHub.PullRequest
    if haskey(github_pr_cache, github_pull_request_info)
        @info "use cached pull request object"
        return github_pr_cache[github_pull_request_info]
    end

    pr_object = GitHub.pull_request(
        "$(github_pull_request_info.user)/$(github_pull_request_info.project)",
        github_pull_request_info.pr_number
    )
    github_pr_cache[github_pull_request_info] = pr_object
    return pr_object
end
