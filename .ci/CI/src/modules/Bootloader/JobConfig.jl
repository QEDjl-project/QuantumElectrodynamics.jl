using Logging

include("../GenericTest/TestType.jl")

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
                    CPU,
                )
            )

        elseif julia_version == "rc" && is_cpu_tests(args)
            push!(
                unit_test_types,
                (
                    ReleaseCandidate(),
                    CPU,
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
                        CPU,
                    )
                )
            end

            if is_cuda_tests(args)
                push!(
                    unit_test_types,
                    (
                        ReleaseVersion(julia_version),
                        CUDA,
                    )
                )
            end

            if is_amdgpu_tests(args)
                push!(
                    unit_test_types,
                    (
                        ReleaseVersion(julia_version),
                        AMDGPU,
                    )
                )
            end
        end
    end
    return unit_test_types
end

"""
Print all test configurations via logger.

# Args

- `test_type_name::AbstractString`: Name of the test type
- `test_configs::Vector{Tuple{UnitTestType, TestPlatform}}`: Test configurations
"""
function info_test_configs(
        test_type_name::AbstractString,
        test_configs::Vector{Tuple{JuliaVersionType, TestPlatform}}
    )
    output = test_type_name * ":\n"
    if isempty(test_configs)
        output *= "  no configurations"
    else
        for (test_type_name, platform) in test_configs
            output *= "  " * string(test_type_name) * " + " * string(platform) * "\n"
        end
    end
    return @info output
end
