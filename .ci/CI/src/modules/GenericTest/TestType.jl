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
