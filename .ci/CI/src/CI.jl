module CI
include("./modules/IntegTest.jl")
using .IntegGen

include("./modules/GitLabTargetBranch.jl")
using .GitLabTargetBranch

include("./SetupDevEnv.jl")
using .SetupDevEnv

end
