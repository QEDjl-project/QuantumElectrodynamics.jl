using Pkg

"""
    get_project_version_name()::Tuple{String,String}

# Return

Returns project name and version number
"""
function get_project_version_name_path()::Tuple{String,String,String}
    return (Pkg.project().name, string(Pkg.project().version), dirname(Pkg.project().path))
end

# the script be directly executed in bash to set the environment variables
# $(julia --project=/path/to/the/actual/project get_project_version_name)
if abspath(PROGRAM_FILE) == @__FILE__
    (name, version, path) = get_project_version_name_path()
    println("export CI_DEV_PKG_NAME=$(name)")
    println("export CI_DEV_PKG_VERSION=$(version)")
    println("export CI_DEV_PKG_PATH=$(path)")
end
