module CI
include("./integTestGen.jl")
using .integTestGen

include("./SetupDevEnv.jl")
using .SetupDevEnv

include("./get_target_branch.jl")
using .TargetBranch

end
