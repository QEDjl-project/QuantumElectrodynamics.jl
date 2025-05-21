using CI
using Test

include("test_utils.jl")

if haskey(ENV, "DISABLE_CI_SHORT_TESTS")
    @warn "disable short running tests"
else
    include("get_target_branch.jl")
    include("UnitTest/runtests.jl")
    include("IntegrationTest/runtests.jl")
    include("Util/runtests.jl")
    include("SetupDevEnv/runtests.jl")
end

if haskey(ENV, "DISABLE_CI_LONG_TESTS")
    @warn "disable long running tests"
else
    include("Bootloader/runtests.jl")
end
