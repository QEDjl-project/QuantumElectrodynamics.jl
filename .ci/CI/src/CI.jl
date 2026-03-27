module CI
include("modules/types.jl")
include("modules/generic_test.jl")
include("modules/utils.jl")
include("modules/unit_test.jl")
include("modules/integ_test.jl")
include("modules/gitlab_target_branch.jl")
include("modules/setup_dev_env.jl")
include("modules/gitlab_ci_conf.jl")
include("modules/bootloader.jl")
end
