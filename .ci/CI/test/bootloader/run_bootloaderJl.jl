using TOML
using YAML

"""
Get project path of CI.jl
"""
function get_ci_jl_project_path()
    # Search for Project.toml, because Test.jl uses an temporary Julia environment. Therefore we cannot
    # simply ask for it.
    # Also avoid, that the test file, which calls this function needs to be on a specific postion in the
    # folder hierarchy.
    path = dirname(Base.source_path())

    if path == ""
        throw(ErrorException("Not supported for REPL mode."))
    end

    while true
        if "Project.toml" in readdir(path)
            project_toml = TOML.parsefile(joinpath(path, "Project.toml"))
            if haskey(project_toml, "name") && project_toml["name"] == "CI"
                return path
            end
        end

        if path == "/"
            throw(ErrorException("could not find CI Project.toml"))
        end
        path = realpath(joinpath(path, ".."))
    end
    return
end

"""
Returns the path of the Bootloader.jl script.
"""
get_bootloader_jl_path() = joinpath(get_ci_jl_project_path(), "src", "Bootloader.jl")

"""
    run_process(command::Vector{String})

Run bash process and return error code and stdout and stderr as string.

# Args
- `command::Vector{String}`: Call command including arguments.

# Return

Error code, stdout and stderr as String.
"""
function run_process(command::Vector{String})::Tuple{Int, String, String}
    out = Pipe()
    err = Pipe()
    process = run(
        pipeline(
            Cmd(command),
            stdout = out,
            stderr = err,
        )
    )
    close(out.in)
    close(err.in)

    return (process.exitcode, String(read(out)), String(read(err)))
end

"""
    count_keys_contains(name::Regex, yaml_dict::Dict)::Number

Counts the number of job names, which matches the regex.

# Args
- `name::Regex`: Name regex to be matched
- `yaml_dict::Dict`: Job dict with job names

# Return

Return number of matches.
"""
function count_keys_contains(name::Regex, yaml_dict::Dict)::Number
    return length(filter(job_name -> contains(job_name, name), keys(yaml_dict)))
end

"""
    script_region_contains(name::Regex, job::Dict)::Bool

Check if a given string is the script section of a job.

# Args
- `name::Regex`: String be searched
- `yaml_dict::Dict`: Job dict with script section

# Return

`true`, if string was found.
"""
function script_region_contains(name::Regex, job::Dict)::Bool
    for script_lines in job["script"]
        if contains(script_lines, name)
            return true
        end
    end
    return false
end

@testset "run bootloader.jl" begin
    # clone QEDcore.jl for generating tests
    QED_PROJECT_PATH = joinpath(tempdir(), "QEDcore")
    if !isdir(QED_PROJECT_PATH)
        disable_info_logger_output() do
            CI._git_clone("https://github.com/QEDjl-project/QEDcore.jl#dev", QED_PROJECT_PATH)
        end
    end

    @testset "target branch dev, no pull request" begin
        (error_code, stdout_output, stderr_output) = run_process(
            [
                "julia",
                "--project=$(get_ci_jl_project_path())",
                get_bootloader_jl_path(),
                "--project-path=$(QED_PROJECT_PATH)",
                "--target-branch=dev",
                "--no-pr",
                "--cuda",
                "--amdgpu",
            ]
        )
        @test error_code == 0
        job_data = YAML.load(stdout_output)
        @test count_keys_contains(r"^unit_test*", job_data) > 0
        @test count_keys_contains(r"^integration_test*", job_data) == 0
        @test count_keys_contains(r"^unit_test.*cuda", job_data) > 0
        @test count_keys_contains(r"^unit_test.*amdgpu", job_data) > 0

        @test haskey(job_data, "verify-unit-test-deps")
        @test script_region_contains(r"VerifyEnv\.jl", job_data["verify-unit-test-deps"])
    end

    @testset "target branch dev, pull request" begin
        (error_code, stdout_output, stderr_output) = run_process(
            [
                "julia",
                "--project=$(get_ci_jl_project_path())",
                get_bootloader_jl_path(),
                "--project-path=$(QED_PROJECT_PATH)",
                "--target-branch=dev",
                "--pr",
                "--cuda",
                "--amdgpu",
            ]
        )
        @test error_code == 0
        job_data = YAML.load(stdout_output)
        @test count_keys_contains(r"^unit_test*", job_data) > 0
        @test count_keys_contains(r"^integration_test*", job_data) > 0
        @test count_keys_contains(r"^unit_test.*cuda", job_data) > 0
        @test count_keys_contains(r"^unit_test.*amdgpu", job_data) > 0
        @test count_keys_contains(r"^integration_test.*cuda", job_data) > 0
        @test count_keys_contains(r"^integration_test.*amdgpu", job_data) > 0

        @test haskey(job_data, "verify-unit-test-deps")
        @test script_region_contains(r"VerifyEnv\.jl", job_data["verify-unit-test-deps"])
    end

    @testset "target branch main, no pull request" begin
        result_folder = mktempdir()
        cpu_output = joinpath(result_folder, "cpu.yaml")
        gpu_output = joinpath(result_folder, "gpu.yaml")
        verify_output = joinpath(result_folder, "verify.yaml")
        (error_code, stdout_output, stderr_output) = run_process(
            [
                "julia",
                "--project=$(get_ci_jl_project_path())",
                get_bootloader_jl_path(),
                "--project-path=$(QED_PROJECT_PATH)",
                "--target-branch=main",
                "--no-pr",
                "--cuda",
                "--amdgpu",
                "--output-cpu=$(cpu_output)",
                "--output-gpu=$(gpu_output)",
                "--output-unit-test-verify=$(verify_output)",
            ]
        )
        @test error_code == 0
        cpu_yaml = YAML.load_file(cpu_output)
        gpu_yaml = YAML.load_file(gpu_output)
        verify_yaml = YAML.load_file(verify_output)
        @test count_keys_contains(r"^unit_test*", cpu_yaml) > 0
        @test count_keys_contains(r"^unit_test*", gpu_yaml) > 0
        @test count_keys_contains(r"^integration_test*", cpu_yaml) == 0
        @test count_keys_contains(r"^integration_test*", gpu_yaml) == 0
        @test count_keys_contains(r"^unit_test.*cuda", cpu_yaml) == 0
        @test count_keys_contains(r"^unit_test.*amdgpu", cpu_yaml) == 0
        @test count_keys_contains(r"^unit_test.*cuda", gpu_yaml) > 0
        @test count_keys_contains(r"^unit_test.*amdgpu", gpu_yaml) > 0

        @test haskey(verify_yaml, "DummyJob")
        @test script_region_contains(r"VerifyEnv\.jl", verify_yaml["DummyJob"]) == false
    end

    @testset "target branch main, pull request" begin
        result_folder = mktempdir()
        cpu_output = joinpath(result_folder, "cpu.yaml")
        gpu_output = joinpath(result_folder, "gpu.yaml")
        verify_output = joinpath(result_folder, "verify.yaml")
        (error_code, stdout_output, stderr_output) = run_process(
            [
                "julia",
                "--project=$(get_ci_jl_project_path())",
                get_bootloader_jl_path(),
                "--project-path=$(QED_PROJECT_PATH)",
                "--target-branch=main",
                "--pr",
                "--cuda",
                "--amdgpu",
                "--output-cpu=$(cpu_output)",
                "--output-gpu=$(gpu_output)",
                "--output-unit-test-verify=$(verify_output)",
            ]
        )
        @test error_code == 0
        cpu_yaml = YAML.load_file(cpu_output)
        gpu_yaml = YAML.load_file(gpu_output)
        verify_yaml = YAML.load_file(verify_output)
        @test count_keys_contains(r"^unit_test*", cpu_yaml) > 0
        @test count_keys_contains(r"^unit_test*", gpu_yaml) > 0
        @test count_keys_contains(r"^unit_test.*cuda", cpu_yaml) == 0
        @test count_keys_contains(r"^unit_test.*amdgpu", cpu_yaml) == 0
        @test count_keys_contains(r"^unit_test.*cuda", gpu_yaml) > 0
        @test count_keys_contains(r"^unit_test.*amdgpu", gpu_yaml) > 0
        @test count_keys_contains(r"^integration_test*", cpu_yaml) > 0
        @test count_keys_contains(r"^integration_test.*_release_test", cpu_yaml) > 0
        @test count_keys_contains(r"^integration_test*", gpu_yaml) > 0
        @test count_keys_contains(r"^integration_test.*_release_test", gpu_yaml) > 0
        @test count_keys_contains(r"^integration_test.*cuda", cpu_yaml) == 0
        @test count_keys_contains(r"^integration_test.*amdgpu", cpu_yaml) == 0
        @test count_keys_contains(r"^integration_test.*cuda", gpu_yaml) > 0
        @test count_keys_contains(r"^integration_test.*amdgpu", gpu_yaml) > 0

        @test haskey(verify_yaml, "DummyJob")
        @test script_region_contains(r"VerifyEnv\.jl", verify_yaml["DummyJob"]) == false
    end
end
