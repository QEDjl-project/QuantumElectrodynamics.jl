using Pkg

include("./modules/Utils.jl")

# the script be directly executed in bash to set the environment variables
# $(julia --project=/path/to/the/actual/project get_project_version_name)
if abspath(PROGRAM_FILE) == @__FILE__
    (name, version, path) = get_project_version_name_path()
    println("export CI_DEV_PKG_NAME=$(name)")
    println("export CI_DEV_PKG_VERSION=$(version)")
    println("export CI_DEV_PKG_PATH=$(path)")
end
