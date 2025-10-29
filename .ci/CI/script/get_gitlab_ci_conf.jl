using CI

if abspath(PROGRAM_FILE) == @__FILE__
    if !haskey(ENV, "CI_COMMIT_REF_NAME")
        @error "Environment variable CI_COMMIT_REF_NAME is not set."
        exit(1)
    end

    ci_commit_ref_name = ENV["CI_COMMIT_REF_NAME"]
    @info "CI_COMMIT_REF_NAME: $(ci_commit_ref_name)"

    output_env_vars = CI.get_output_variables()

    pull_request = CI.is_pull_request(ci_commit_ref_name)
    if pull_request
        CI.handle_pull_request!(ci_commit_ref_name, output_env_vars)
    else
        CI.handle_normal_commit!(ci_commit_ref_name, output_env_vars)
    end

    # get commit hash of current git commit
    output_env_vars["CI_QED_COMMIT_HASH"] = strip(read(`git rev-parse HEAD`, String))

    if output_env_vars["CI_QED_TARGET_BRANCH"] != "main"
        CI.read_commit_message!(output_env_vars)
    end

    if !CI.check_output_variables(output_env_vars)
        exit(1)
    end

    local env_info_output = "Environment variables:\n"
    for (name, value) in output_env_vars
        env_info_output *= "  $(name)=$(value)\n"
    end
    @info env_info_output

    for (name, value) in output_env_vars
        println("export $(name)=$(value)")
    end

end
