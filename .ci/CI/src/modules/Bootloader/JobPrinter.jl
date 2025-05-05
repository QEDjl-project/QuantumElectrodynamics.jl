using YAML

"""
    print_job_yaml(job_yaml::Dict, io::IO=stdout)

Prints to dict as human readable GitLab CI job yaml.

# Args
- `job_yaml::Dict`: Contains job descriptions.
- `io::IO=stdout`: Output for the rendered yaml.
"""
function print_job_yaml(job_yaml::Dict, io::IO = stdout)
    job_yaml_copy = deepcopy(job_yaml)

    # print all stages first
    if "stages" in keys(job_yaml_copy)
        YAML.write(io, "stages" => job_yaml["stages"])
        println(io, "")
        delete!(job_yaml_copy, "stages")
    end

    # print all unit tests with an empty line between
    for (top_level_object, top_level_object_value) in job_yaml_copy
        if startswith(top_level_object, "unit_test_julia_")
            YAML.write(io, top_level_object => top_level_object_value)
            println(io, "")
            delete!(job_yaml_copy, top_level_object)
        end
    end

    # print all integration tests with an empty line between
    for (top_level_object, top_level_object_value) in job_yaml_copy
        if startswith(top_level_object, "integration_test_")
            YAML.write(io, top_level_object => top_level_object_value)
            println(io, "")
            delete!(job_yaml_copy, top_level_object)
        end
    end

    # print everything, which was not already printed
    return if !isempty(job_yaml_copy)
        YAML.write(io, job_yaml_copy)
    end
end
