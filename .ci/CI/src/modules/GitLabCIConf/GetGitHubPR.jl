using GitHub

# cache pull request information
github_pr_cache = Dict{GitHubPR, GitHub.PullRequest}()

"""
    pull_github_pull_request(
        github_pull_request_info::GitHubPR,
        max_retries::Integer = 5,
        wait_time::Integer = 20
    )::GitHub.PullRequest

Do a web request and get information about an pull request.

# Args

- `github_pull_request_info::GitHubPR`: Contains "address" of the pull request.
- `max_retries::Integer`: Number of attempts to pull the GitHub pull request information in case of
    a connection problem.
- `wait_time::Integer`: Time in seconds that is waited between two attempts.

# Return

All information about the pull request.
"""
function pull_github_pull_request(
        github_pull_request_info::GitHubPR,
        max_retries::Integer = 5,
        wait_time::Integer = 20
    )::GitHub.PullRequest
    if haskey(github_pr_cache, github_pull_request_info)
        @info "use cached pull request object"
        return github_pr_cache[github_pull_request_info]
    end


    for i in 1:max_retries
        try
            pr_object = GitHub.pull_request(
                "$(github_pull_request_info.user)/$(github_pull_request_info.project)",
                github_pull_request_info.pr_number
            )
            github_pr_cache[github_pull_request_info] = pr_object
            return pr_object
        catch e
            if i < max_retries
                @warn "Time out for fetching pull request information.\n" *
                    "Sleep $(wait_time) seconds and try again."
                sleep(wait_time)
            else
                throw(e)
            end
        end
    end
    return
end
