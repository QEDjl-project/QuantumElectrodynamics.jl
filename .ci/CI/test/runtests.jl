using CI
using Test

include("./test_utils.jl")
include("./get_target_branch.jl")
include("./generate_job_yaml.jl")
include("./setup_dev_env.jl")
include("./UnitTest/runtests.jl")
include("./Util/runtests.jl")
