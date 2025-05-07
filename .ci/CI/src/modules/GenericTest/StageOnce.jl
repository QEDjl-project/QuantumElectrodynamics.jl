"""
    _add_stage_once!(job_dict::Dict, stage_name::AbstractString)

Check whether the stage section and stage name exist. If one or both are not available, add them to
the job.

# Args
- `job_dict::Dict`: The job dict.
- `stage_name::AbstractString`: Name of the stage.
"""
function _add_stage_once!(job_dict::Dict, stage_name::AbstractString)
    if !haskey(job_dict, "stages")
        job_dict["stages"] = []
    end

    return if !(stage_name in job_dict["stages"])
        push!(job_dict["stages"], stage_name)
    end
end
