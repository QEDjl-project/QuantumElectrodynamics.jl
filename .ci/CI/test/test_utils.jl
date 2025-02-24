using YAML

"""
    yaml_diff(given::Dict, expected::Dict)::String

Generates an error string that shows a given and an expected data structure in yaml 
representation.

# Returns
- Human readable error message for the comparison of two job yaml's.
"""
function yaml_diff(given::Dict, expected::Dict)::String
    output = "\n***given***\n"
    output *= String(YAML.yaml(given))
    output *= "\n***expected***\n"
    output *= String(YAML.yaml(expected))
    return output
end

"""
    compare_lists(expected_list::Vector, given_list::Vector)::String

Compares two lists and displays different lines.

# Returns
- Human readable error message for the comparison of two lists.
"""
function compare_lists(expected_list::Vector, given_list::Vector)::String
    text = "\n"
    if length(expected_list) != length(given_list)
        text *= "length of expected_list and given_list is different: $(length(expected_list)) != $(length(given_list))\n"
    end

    min_length = min(length(expected_list), length(given_list))

    text *= "different lines: \n"
    for i in 1:min_length
        if expected_list[i] != given_list[i]
            text *= "$(i): $(expected_list[i])\n"
            text *= "   $(given_list[i])\n\n"
        end
    end

    return text
end

"""
    disable_info_logger_output(test_function::Function)

Deactivate the info level logger output for the code running in the do block.

```
    disable_info_logger_output() do
        @test my_code_with_info_logger_output()
    end
```
"""
function disable_info_logger_output(test_function::Function)
    info_logger_io = IOBuffer()
    info_logger = CI.Logging.ConsoleLogger(info_logger_io, CI.Logging.Info)

    CI.Logging.with_logger(info_logger) do
        test_function()
    end
end
