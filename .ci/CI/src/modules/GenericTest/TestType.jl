"""
Represent type of tests to be tested
"""
abstract type TestType end
struct UnitTest <: TestType end
struct IntegrationTest <: TestType end

"""
    get_test_type_env_var_prefix(::TestType)

Depending on the test type, a different prefix for a environment variable name is returned.
Environment starting with the prefix contains custom dependency URLs.

# Args
`::TestType` The test type

# Returns

Prefix of variable names that are read in order to obtain user-defined URLs.
"""
get_test_type_env_var_prefix(::TestType) = error("unknown test type")
get_test_type_env_var_prefix(::UnitTest) = "CI_UNIT_PKG_URL_"
get_test_type_env_var_prefix(::IntegrationTest) = "CI_INTG_PKG_URL_"

"""
    get_test_type_name(::TestType)

Return human readable name of the test type.

# Args
`::TestType` The test type

# Returns

test name
"""
get_test_type_name(::UnitTest) = "unit test"
get_test_type_name(::IntegrationTest) = "integration test"

Base.show(io::IO, obj::TestType) = print(io, get_test_type_name(obj))

"""
Specify target processor for the tests.
"""
@enum TestPlatform CPU CUDA AMDGPU ONEAPI METAL

abstract type JuliaVersionType end

"""
Creates a test job which tests with a specific Julia version.

# Args

- `version::AbstractString`: Julia version.
"""
struct ReleaseVersion <: JuliaVersionType
    version::AbstractString
end

"""
Creates a test job which uses the latest Julia release candidate.
"""
struct ReleaseCandidate <: JuliaVersionType end

"""
Creates a test job which uses the Julia nightly version.

# Args

- `container_image::AbstractString`: container base image used in the CI job.
"""
struct Nightly <: JuliaVersionType
    container_image::AbstractString
end
