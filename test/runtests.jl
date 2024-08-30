using QED
using SafeTestsets

@time @safetestset "Reexport" begin
    include("reexport.jl")
end
