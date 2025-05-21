# Note: This file is used by SetupDevEnv.jl
#       It is not allowed to use third party packages.
#       Only standard library packages are allowed.

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
abstract type TestPlatform end
struct CPU <: TestPlatform end
struct CUDA <: TestPlatform end
struct AMDGPU <: TestPlatform end
struct ONEAPI <: TestPlatform end
struct METAL <: TestPlatform end

TestPlatforms = [CPU(), CUDA(), AMDGPU(), ONEAPI(), METAL()]

"""
Get string representation
"""
function get_platform_name(::Type{T}) where {T <: TestPlatform}
    return string(nameof(T))
end

function get_platform_name(::T) where {T <: TestPlatform}
    return get_platform_name(T)
end

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

"""
    struct TestPackage

Contains information about the package to test.

# Members
- `name::String`: Name of the package.
- `version::String`: Version of the package.
- `path::String`: Path of the package root.

"""
struct TestPackage
    name::String
    version::String
    path::String
end

"""
    struct GitRepoAddress

Url and branch of the Git repository.

# Members
- `url::String`: Git repository URL.
- `branch::String`: Git branch.

"""
struct GitRepoAddress
    url::String
    branch::String

    GitRepoAddress(url::AbstractString, branch::AbstractString) = new(url, branch)

    """
        GitRepoAddress(julia_repo_address::AbstractString)

    # Args
    - `julia_repo_address::AbstractString`: The repository address is parsed. Two different
        patterns are permitted.

    1. Pure Git repository URL, e.g. www.github.com/user/repo. In this case, the member `url` is
        set to the specified URL and the member `branch` is set to `dev`.
    2. URL of the Git repository and name of the branch. The branch name is appended to the URL
        with a `#branchname`, e.g. www.github.com/user/repo#featurebranch.
    """
    function GitRepoAddress(julia_repo_address::AbstractString)
        split_url = split(julia_repo_address, "#")

        if length(split_url) > 2
            error("ill-formed url: $(url)")
        end

        url = split_url[1]
        branch = "dev"
        if length(split_url) > 1
            branch = split_url[2]
        end

        return new(url, branch)
    end
end

"""
    struct CustomDependencyUrls

Stores custom repository URLs for QED packages which are dependency of the project to be tested.

# Members
- `unit::Dict{String,String}`: Custom dependencies of the unit tests
- `integ::Dict{String,String}`: Custom dependencies of the integration tests

"""
struct CustomDependencyUrls
    unit::Dict{String, String}
    integ::Dict{String, String}

    CustomDependencyUrls() = new(Dict{String, String}(), Dict{String, String}())
end
