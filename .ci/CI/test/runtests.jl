#using Logging
using CI
using Test

function disable_info_logger_output(test_function::Function)
    info_logger_io = IOBuffer()
    info_logger = CI.Logging.ConsoleLogger(info_logger_io, CI.Logging.Info)

    CI.Logging.with_logger(info_logger) do
        test_function()
    end
end

include("./utils.jl")
include("./get_target_branch.jl")
include("./generate_job_yaml.jl")
include("./setup_dev_env.jl")
include("./UnitTest/runtests.jl")
include("./Util/runtests.jl")
