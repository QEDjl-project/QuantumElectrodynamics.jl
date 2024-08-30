using QED

# just test one basic symbol of each project to make sure the project has been reexported into QED.jl
@testset "QEDbase" begin
    @test isdefined(QED, :AbstractParticle)
end
@testset "QEDcore" begin
    @test isdefined(QED, :ParticleStateful)
end
@testset "QEDprocesses" begin
    @test isdefined(QED, :Compton)
end
@testset "QEDfields" begin
    @test isdefined(QED, :AbstractBackgroundField)
end
@testset "QEDevents" begin
    @test isdefined(QED, :SingleParticleDistribution)
end
