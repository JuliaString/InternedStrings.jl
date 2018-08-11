using InternedStrings


using Test, Random, Base.GC
const gc = GC.gc

addr_eq(a,b) = pointer(a) === pointer(b)

@testset "All kinds of types" begin include("all_kinds_of_types.jl") end
@testset "String macro"       begin include("string_macro.jl") end
@testset "Core Functionality" begin include("corefunctionality.jl") end
