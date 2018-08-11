using InternedStrings


using Test, Random, Base.GC

addr_eq(a::String, b::String) = pointer(a) === pointer(b)
addr_eq(a, b) = objectid(a) === objectid(b)


@testset "All kinds of types" begin include("all_kinds_of_types.jl") end
@testset "String macro"       begin include("string_macro.jl") end
@testset "Core Functionality" begin include("corefunctionality.jl") end
