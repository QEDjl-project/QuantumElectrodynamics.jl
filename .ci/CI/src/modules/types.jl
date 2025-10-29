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
get_test_type_env_var_prefix(::UnitTest) = "CI_QED_UNIT_PKG_URL_"
get_test_type_env_var_prefix(::IntegrationTest) = "CI_QED_INTG_PKG_URL_"

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

"""
    get_test_specific_custom_urls(::TestType, urls::CustomDependencyUrls)::Dict{String, String}

Return a reference to the dict containing the custom repository URLs for the given test type.

# Returns

The key is the name of the package and the value the custom URL.
"""
function get_test_specific_custom_urls end

get_test_specific_custom_urls(
    ::UnitTest, urls::CustomDependencyUrls
)::Dict{String, String} = urls.unit

get_test_specific_custom_urls(
    ::IntegrationTest, urls::CustomDependencyUrls
)::Dict{String, String} = urls.integ


"""
    struct GitHubPR

# Members
- `user::AbstractString`: GitHub user or group
- `project::AbstractString`: repository name
- `pr_number::Int`: Pull Request Number
"""
struct GitHubPR
    user::AbstractString
    project::AbstractString
    pr_number::Int
end

Base.:(==)(a::GitHubPR, b::GitHubPR) = a.user == b.user && a.project == b.project && a.pr_number == b.pr_number

"Get String representation of GitHubPR"
github_pr_to_string(gh_pr::GitHubPR) = "User: $(gh_pr.user)\nProject: $(gh_pr.project)\nPR number: $(gh_pr.pr_number)"

"""
    struct CodeCoverageConf

Contains all information, which are required to upload a code coverage to codecov.io

# Members
- `project_name::AbstractString`: Fully qualified name of the Github project. 
    Contains user/group and project name. E.g. qed-project/QEDbase.jl
- `commit_hash::AbstractString`: Git commit hash where code coverage is related to.
- `feature_branch::AbstractString`: Name of the feature branch of a pull request or 
    branch name to be tested if it is not a pull request.
- `pr_number::Integer`: Pull Reqeust number. If it is not a pull request, the number is 0.
"""
struct CodeCoverageConf
    project_name::AbstractString
    commit_hash::AbstractString
    feature_branch::AbstractString
    pr_number::Integer
end

"""
    is_code_coverage(conf::CodeCoverageConf)

Checks if a CodeCoverageConf object is valid triggers code generation.

# Args
- `conf::CodeCoverageConf:` Configuration object to be tested.

# Return
Return true, if the project_name, commit_hash or feature_branch is not empty.
"""
function is_code_coverage(conf::CodeCoverageConf)::Bool
    return !isempty(conf.project_name) && !isempty(conf.commit_hash) && !isempty(conf.feature_branch)
end
