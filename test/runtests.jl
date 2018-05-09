using InternedStrings

const V6_COMPAT = VERSION < v"0.7.0-DEV"
@static if V6_COMPAT
    using Base.Test
    unsafe_wrap(::Type{Vector{UInt8}}, str) = Vector{UInt8}(str)
    const objectid = object_id
    object_id_eq(a,b) = a === b
else
    using Test, Random
    object_id_eq(a,b) = objectid(a) == objectid(b)
    const gc = GC.gc
end

@testset "All kinds of types" begin include("all_kinds_of_types.jl") end
@testset "String macro"       begin include("string_macro.jl") end
@testset "Core Functionality" begin include("corefunctionality.jl") end
