"""
    _add_julia_rocm_environment!(job_yaml::Dict, unit_test_type::ReleaseVersion)

Adding instructions to a CI job to set up a container environment with Julia and ROCm installation.

# Args
- `job_yaml::Dict:` Dict in which the new job is added.
- `unit_test_type::ReleaseVersion`: Julia version to be installed.
"""
function _add_julia_rocm_environment!(job_yaml::Dict, unit_test_type::ReleaseVersion)
    job_yaml["image"] = "rocm/dev-ubuntu-24.04:6.2.4-complete"
    return job_yaml["before_script"] = [
        "curl -fsSL https://install.julialang.org | sh -s -- -y -p /julia",
        "export PATH=/julia/bin:\$PATH",
        "echo \$PATH",
        "juliaup add $(unit_test_type.version)",
        "juliaup default $(unit_test_type.version)",
    ]
end
