using CI
using Test

include("test_utils.jl")

if haskey(ENV, "DISABLE_CI_SHORT_TESTS")
    @warn "disable short running tests"
else
    include("get_target_branch.jl")
    include("unit_test/runtests.jl")
    include("integration_test/runtests.jl")
    include("util/runtests.jl")
    include("setup_dev_env/runtests.jl")
    include("gitlab_ci_conf/runtests.jl")
end

if haskey(ENV, "DISABLE_CI_LONG_TESTS")
    @warn "disable long running tests"
else
    include("bootloader/runtests.jl")
end
