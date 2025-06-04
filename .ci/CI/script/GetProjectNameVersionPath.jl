using Pkg
using CI

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        @error "Define path to target Project as first argument."
        exit(1)
    end

    Pkg.activate(ARGS[1])

    (name, version, path) = CI.get_project_version_name_path()
    println("export CI_DEV_PKG_NAME=$(name)")
    println("export CI_DEV_PKG_VERSION=$(version)")
    println("export CI_DEV_PKG_PATH=$(path)")
end
