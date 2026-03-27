using Logging

"""
Returns all unit tests configurations configured by script arguments and environment variables.
"""
function get_unit_test_configs(args::Dict{String, Any})::Vector{Tuple{JuliaVersionType, TestPlatform}}
    unit_test_types = Vector{Tuple{JuliaVersionType, TestPlatform}}()
    for julia_version in get_unit_test_julia_versions()
        if julia_version == "nightly" && is_cpu_tests(args)
            push!(
                unit_test_types,
                (
                    Nightly(get_unit_test_nightly_baseimage()),
                    CPU(),
                )
            )

        elseif julia_version == "rc" && is_cpu_tests(args)
            push!(
                unit_test_types,
                (
                    ReleaseCandidate(),
                    CPU(),
                )
            )
            continue
        else
            # normal, release Julia versions
            if is_cpu_tests(args)
                push!(
                    unit_test_types,
                    (
                        ReleaseVersion(julia_version),
                        CPU(),
                    )
                )
            end

            if is_cuda_tests(args)
                push!(
                    unit_test_types,
                    (
                        ReleaseVersion(julia_version),
                        CUDA(),
                    )
                )
            end

            if is_amdgpu_tests(args)
                push!(
                    unit_test_types,
                    (
                        ReleaseVersion(julia_version),
                        AMDGPU(),
                    )
                )
            end
        end
    end
    return unit_test_types
end

"""
Returns all integration tests configurations configured by script arguments and environment variables.
"""
function get_integration_test_configs(
        args::Dict{String, Any},
    )::Vector{Tuple{JuliaVersionType, TestPlatform}}
    integ_test_types = Vector{Tuple{JuliaVersionType, TestPlatform}}()

    if !is_integ_tests(args) || !is_pull_request(args)
        return integ_test_types
    end

    for julia_version in get_integration_test_julia_versions()
        if julia_version == "nightly" || julia_version == "rc"
            continue
        end
        # normal, release Julia versions
        if is_cpu_tests(args)
            push!(
                integ_test_types,
                (
                    ReleaseVersion(julia_version),
                    CPU(),
                )
            )
        end

        if is_cuda_tests(args)
            push!(
                integ_test_types,
                (
                    ReleaseVersion(julia_version),
                    CUDA(),
                )
            )
        end

        if is_amdgpu_tests(args)
            push!(
                integ_test_types,
                (
                    ReleaseVersion(julia_version),
                    AMDGPU(),
                )
            )
        end
    end
    return integ_test_types
end

"""
Print all test configurations via logger.

# Args

- `test_type_name::AbstractString`: Name of the test type
- `test_configs::Vector{Tuple{UnitTestType, TestPlatform}}`: Test configurations
"""
function info_test_configs(
        test_type::Type{T},
        test_configs::Dict
    ) where {T <: TestType}
    job_configurations::Vector{Tuple{JuliaVersionType, TestPlatform}} = test_configs[test_type]

    output = string(test_type) * ":\n"
    if isempty(job_configurations)
        output *= "  no configurations"
    else
        for (julia_version_type, platform) in job_configurations
            output *= "  " * string(julia_version_type) * " + " * string(platform) * "\n"
        end
    end
    return @info output
end

"""
    get_latest_julia_cpu_release(unit_test::Vector{Tuple{JuliaVersionType, TestPlatform}})::String

Take a list of unit test configuration and return the latest Julia version of the ReleaseTests.

# Args
- `unit_test::Vector{Tuple{JuliaVersionType, TestPlatform}}`: A list of unit test configurations.

# Return
- A versions string. Returns 0.0 if no CPU test with a release version was in `unit_test`.
"""
function get_latest_julia_cpu_release(unit_test::Vector{Tuple{JuliaVersionType, TestPlatform}})::String
    cpu_tests = filter(t -> typeof(t[1]) == ReleaseVersion && t[2] == CI.CPU(), unit_test)
    if isempty(cpu_tests)
        return "0.0"
    else
        return findmax(t -> t[1].version, cpu_tests)[1]
    end
end
