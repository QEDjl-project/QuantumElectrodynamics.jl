module UnitTest
function add_unit_test_job_yaml!(
    job_dict::Dict,
    julia_versions::Vector{String},
    target_branch::String,
    dev_package_name::AbstractString,
    dev_package_version::AbstractString,
    dev_package_path::AbstractString,
    git_ci_tools_url::String="https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git",
    git_ci_tools_branch::String="dev",
    nightly_base_image::AbstractString="debian:bookworm-slim",
)
    if !haskey(job_dict, "stages")
        job_dict["stages"] = []
    end

    push!(job_dict["stages"], "unit-test")

    for version in julia_versions
        if version != "nightly"
            job_dict["unit_test_julia_$(replace(version, "." => "_"))"] = get_normal_unit_test(
                version,
                target_branch,
                dev_package_name,
                dev_package_version,
                dev_package_path,
                git_ci_tools_url,
                git_ci_tools_branch,
            )
        else
            job_dict["unit_test_julia_nightly"] = get_nightly_unit_test(
                target_branch,
                dev_package_name,
                dev_package_version,
                dev_package_path,
                git_ci_tools_url,
                git_ci_tools_branch,
                nightly_base_image,
            )
        end
    end
end

function add_unit_test_verify_job_yaml!(
    job_dict::Dict,
    target_branch::String,
    git_ci_tools_url::String="https://github.com/QEDjl-project/QuantumElectrodynamics.jl.git",
    git_ci_tools_branch::String="dev",
)
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
            "tags" => ["cpuonly"],
        )
    end
end

function get_normal_unit_test(
    version::String,
    target_branch::String,
    dev_package_name::AbstractString,
    dev_package_version::AbstractString,
    dev_package_path::AbstractString,
    git_ci_tools_url::String,
    git_ci_tools_branch::String,
)::Dict
    job_yaml = Dict()
    job_yaml["stage"] = "unit-test"
    job_yaml["variables"] = Dict(
        "CI_DEV_PKG_NAME" => dev_package_name,
        "CI_DEV_PKG_VERSION" => dev_package_version,
        "CI_DEV_PKG_PATH" => dev_package_path,
    )
    job_yaml["image"] = "julia:$(version)"

    script = [
        "apt update && apt install -y git",
        "git clone --depth 1 -b $(git_ci_tools_branch) $(git_ci_tools_url) /tmp/integration_test_tools/",
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

function get_nightly_unit_test(
    target_branch::String,
    dev_package_name::AbstractString,
    dev_package_version::AbstractString,
    dev_package_path::AbstractString,
    git_ci_tools_url::String,
    git_ci_tools_branch::String,
    nightly_base_image::AbstractString,
)
    job_yaml = get_normal_unit_test(
        "1",
        target_branch,
        dev_package_name,
        dev_package_version,
        dev_package_path,
        git_ci_tools_url,
        git_ci_tools_branch,
    )
    job_yaml["image"] = nightly_base_image

    if !haskey(job_yaml, "variables")
        job_yaml["variables"] = Dict()
    end
    job_yaml["variables"]["JULIA_DOWNLOAD"] = "/julia/download"
    job_yaml["variables"]["JULIA_EXTRACT"] = "/julia/extract"

    job_yaml["before_script"] = [
        "apt update && apt install -y wget",
        "mkdir -p \$JULIA_DOWNLOAD",
        "mkdir -p \$JULIA_EXTRACT",
        "if [[ \$CI_RUNNER_EXECUTABLE_ARCH == \"linux/arm64\" ]]; then
  wget https://julialangnightlies-s3.julialang.org/bin/linux/aarch64/julia-latest-linux-aarch64.tar.gz -O \$JULIA_DOWNLOAD/julia-nightly.tar.gz
elif [[ \$CI_RUNNER_EXECUTABLE_ARCH == \"linux/amd64\" ]]; then
  wget https://julialangnightlies-s3.julialang.org/bin/linux/x86_64/julia-latest-linux-x86_64.tar.gz -O \$JULIA_DOWNLOAD/julia-nightly.tar.gz
else
  echo \"unknown runner architecture -> \$CI_RUNNER_EXECUTABLE_ARCH\"
  exit 1
fi",
        "tar -xf \$JULIA_DOWNLOAD/julia-nightly.tar.gz -C \$JULIA_EXTRACT",
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
end
