"""
    generate_dummy_job_yaml!(job_yaml::Dict)

Generates a GitLab CI dummy job, if required.

# Args
- `job_yaml::Dict`: Add generated job to this dict.
- `message::AbstractString`: Message to be displayed in the CI job.
- `stage_name::AbstractString`: Set stage name if is not a empty string.
"""
function generate_dummy_job_yaml!(
        job_yaml::Dict,
        message::AbstractString = "This is a dummy job so that the CI does not fail.",
        stage_name::AbstractString = ""
    )
    job_yaml["DummyJob"] = Dict(
        "image" => "alpine:latest",
        "interruptible" => true,
        "script" => ["echo \"$(message)\""],
    )

    if stage_name != ""
        job_yaml["DummyJob"]["stage"] = stage_name
    end

    return nothing
end
