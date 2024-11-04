module Bootloader

include("./get_target_branch.jl")

using .TargetBranch
using TOML
using Logging
using YAML

function _check_env_vars()
    if !haskey(ENV, "CI_COMMIT_REF_NAME")
        @error "Environemnt variable CI_COMMIT_REF_NAME is not set. Required to determine target branch."
    end

    if !haskey(ENV, "CI_PROJECT_DIR")
        @error "Environemnt variable CI_PROJECT_DIR is not set. Defines the base path of the project to test."
    end
end

function get_package_name_version(package_path::AbstractString)::Tuple{String,String}
    project_toml_path = joinpath(package_path, "Project.toml")

    f = open(project_toml_path, "r")
    project_toml = TOML.parse(f)
    close(f)
    return (project_toml["name"], project_toml["version"])
end

function get_unit_test_julia_versions()::Vector{String}
    # TODO: support reading julia versions from env variables

    return ["1.10", "1.11", "rc", "nightly"]
end

function get_git_ci_tools_url_branch()::Tuple{String, String}
    url = "https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git"
    branch = "dev"

    if haskey(ENV, "CI_GIT_CI_TOOLS_URL")
        url = ENV["CI_GIT_CI_TOOLS_URL"]
        @warn "use custom git URL for CI tools: $(url)"
    end

    if haskey(ENV, "CI_GIT_CI_TOOLS_BRANCH")
        branch = ENV["CI_GIT_CI_TOOLS_BRANCH"]
        @warn "use custom git branch for CI tools: $(branch)"
    end

    return (url, branch)
end

function add_unit_test_job_yaml!(
    job_dict::Dict,
    julia_versions::Vector{String},
    target_branch::String,
    git_ci_tools_url::String="https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git",
    git_ci_tools_branch::String="dev",
)
    if !haskey(job_dict, "stages")
        job_dict["stages"] = []
    end

    push!(job_dict["stages"], "unit-test")

    for version in julia_versions
        if version != "nightly"
            job_dict["unit_test_julia_$(replace(version, "." => "_"))"] = get_normal_unit_test(
                version, target_branch
            )
        else
            job_dict["unit_test_julia_nightly"] = get_nighlty_unit_test(target_branch)
        end
    end

    # verification script that no custom URLs are used in unit tests
    if target_branch != "main"
        push!(job_dict["stages"], "verify-unit-test-deps")
        job_dict["verify-unit-test-deps"] = Dict(
            "image" => "julia:1.10",
            "stage" => "verify-unit-test-deps",
            "script" => [
                "apt update && apt install -y git",
                "git clone --depth 1 -b $(git_ci_tools_branch) $(git_ci_tools_url) /tools",
                "julia /tools/.ci/verify_env.jl",
            ],
            "interruptible" => true,
            "tags" => ["cpuonly"]
        )
    end
end

function get_normal_unit_test(version::String, target_branch::String)::Dict
    job_yaml = Dict()
    job_yaml["stage"] = "unit-test"
    job_yaml["image"] = "julia:$(version)"

    script = [
        "apt update && apt install -y git",
        "git clone --depth 1 -b dev https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git /tmp/integration_test_tools/",
        "\$(julia --project=. /tmp/integration_test_tools/.ci/integTestGen/src/get_project_name_version_path.jl)",
        "echo \"CI_DEV_PKG_NAME -> \$CI_DEV_PKG_NAME\"",
        "echo \"CI_DEV_PKG_VERSION -> \$CI_DEV_PKG_VERSION\"",
        "echo \"CI_DEV_PKG_PATH -> \$CI_DEV_PKG_PATH\"",
    ]

    if target_branch == "main"
        push!(
            script,
            "julia --project=. /tmp/integration_test_tools/.ci/CI/src/SetupDevEnv.jl \${CI_PROJECT_DIR}/Project.toml NO_MESSAGE",
        )
    else
        push!(
            script,
            "julia --project=. /tmp/integration_test_tools/.ci/CI/src/SetupDevEnv.jl \${CI_PROJECT_DIR}/Project.toml",
        )
    end

    script = vcat(
        script,
        [
            "julia --project=. -e 'import Pkg; Pkg.instantiate()'",
            "julia --project=. -e 'import Pkg; Pkg.test(; coverage = true)'",
        ],
    )
    job_yaml["script"] = script

    job_yaml["interruptible"] = true
    job_yaml["tags"] = ["cpuonly"]

    return job_yaml
end

function get_nighlty_unit_test(target_branch::String)
    job_yaml = get_normal_unit_test("1", target_branch)
    job_yaml["image"] = "debian:bookworm-slim"

    job_yaml["variables"] = Dict()
    job_yaml["variables"]["JULIA_DONWLOAD"] = "/julia/download"
    job_yaml["variables"]["JULIA_EXTRACT"] = "/julia/extract"

    job_yaml["before_script"] = [
        "apt update && apt install -y wget",
        "mkdir -p \$JULIA_DONWLOAD",
        "mkdir -p \$JULIA_EXTRACT",
        "if [[ \$CI_RUNNER_EXECUTABLE_ARCH == \"linux/arm64\" ]]; then
  wget https://julialangnightlies-s3.julialang.org/bin/linux/aarch64/julia-latest-linux-aarch64.tar.gz -O \$JULIA_DONWLOAD/julia-nightly.tar.gz
elif [[ \$CI_RUNNER_EXECUTABLE_ARCH == \"linux/amd64\" ]]; then
  wget https://julialangnightlies-s3.julialang.org/bin/linux/x86_64/julia-latest-linux-x86_64.tar.gz -O \$JULIA_DONWLOAD/julia-nightly.tar.gz
else
  echo \"unknown runner architecture -> \$CI_RUNNER_EXECUTABLE_ARCH\"
  exit 1
fi",
        "tar -xf \$JULIA_DONWLOAD/julia-nightly.tar.gz -C \$JULIA_EXTRACT",
        # we need to search for the julia base folder name, because the second part of the name is the git commit hash
        # e.g. julia-b0c6781676f
        "JULIA_EXTRACT_FOLDER=\${JULIA_EXTRACT}/\$(ls \$JULIA_EXTRACT | grep -m1 julia)",
        # copy everything to /usr to make julia public available
        # mv is not possible, because it cannot merge folder
        "cp -r \$JULIA_EXTRACT_FOLDER/* /usr",
    ]

    job_yaml["image"] = "debian:bookworm-slim"

    job_yaml["allow_failure"] = true
    return job_yaml
end

function print_job_yaml(job_yaml::Dict, io::IO=stdout)
    job_yaml_copy = deepcopy(job_yaml)

    # print all stages first
    if "stages" in keys(job_yaml_copy)
        YAML.write(io, "stages" => job_yaml["stages"])
        println()
        delete!(job_yaml_copy, "stages")
    end

    # print all unit tests with an empty line between
    for (top_level_object, top_level_object_value) in job_yaml_copy
        if startswith(top_level_object, "unit_test_julia_")
            YAML.write(io, top_level_object => top_level_object_value)
            println()
            delete!(job_yaml_copy, top_level_object)
        end
    end

    # print everything, which was not already printed
    if !isempty(job_yaml_copy)
        YAML.write(io, job_yaml_copy)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    _check_env_vars()

    package_path = ENV["CI_PROJECT_DIR"]
    (package_name, package_version) = get_package_name_version(package_path)
    target_branch = TargetBranch.get_target()

    @info "Test package name: $(package_name)"
    @info "Test package version: $(package_version)"
    @info "Test package path: $(package_path)"
    @info "PR target branch: $(target_branch)"

    unit_test_julia_versions = get_unit_test_julia_versions()
    @info "Julia versions for the unit tests: $(unit_test_julia_versions)"

    job_yaml = Dict()

    (git_ci_tools_url, git_ci_tools_branch) = get_git_ci_tools_url_branch()

    add_unit_test_job_yaml!(job_yaml, unit_test_julia_versions, target_branch, git_ci_tools_url, git_ci_tools_branch)

    print_job_yaml(job_yaml)
end

end
