using QuantumElectrodynamics

# just test one basic symbol of each project to make sure the project has been reexported into QuantumElectrodynamics.jl
@testset "QEDbase" begin
    @test isdefined(QuantumElectrodynamics, :AbstractParticle)
end
@testset "QEDcore" begin
    @test isdefined(QuantumElectrodynamics, :ParticleStateful)
end
@testset "QEDprocesses" begin
    @test isdefined(QuantumElectrodynamics, :Compton)
end
@testset "QEDfields" begin
    @test isdefined(QuantumElectrodynamics, :AbstractBackgroundField)
end
@testset "QEDevents" begin
    @test isdefined(QuantumElectrodynamics, :SingleParticleDistribution)
end
