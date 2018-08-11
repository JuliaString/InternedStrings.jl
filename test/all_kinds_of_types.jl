@testset "String" begin
    ex1 = intern("ex")
    @test ex1 == "ex"
    @test !addr_eq(ex1, "ex")
    ex2 = intern("ex")
    @test addr_eq(ex1, ex2)
    ex3 = intern(String, "ex")
    @test addr_eq(ex1, ex3)

    @testset "type inference" begin
        @test ex1 isa String
        @test ex2 isa String
        @inferred intern("ex")
        @inferred intern(String, "ex")
    end
end

@testset "SubString" begin
    aa1, bb1, cc1 = intern.(split("aa bb cc"))
    aa2, bb2, cc2 = intern.(split("aa bb cc"))
    aa3, bb3, cc3 = intern.(String, split("aa bb cc"))

    @test bb1 == "bb"
    @test !addr_eq(bb1, "bb")
    @test addr_eq(bb1, bb2)
    @test addr_eq(bb1, bb3)

    @testset "type inference" begin
        @test intern(split("aa bb cc")[1]) isa String
        @inferred intern(split("aa bb cc")[1])
        @test intern(String, split("aa bb cc")[1]) isa String
        @inferred intern(String, split("aa bb cc")[1])
    end
end

@testset "WeakRefString" begin
    using WeakRefStrings
    s1 = "ex"
    s2 = "ex"
    ex1 = @inferred intern(String, WeakRefString(unsafe_wrap(Vector{UInt8}, s1)))
    @test ex1=="ex"
    @test !addr_eq(ex1, s1)
    @test ex1 isa String
    ex2 = @inferred intern(String, WeakRefString(unsafe_wrap(Vector{UInt8}, s2)))
    @test addr_eq(ex1, ex2)
end

@testset "BigFloat" begin
    let
        pi1 = intern(BigFloat(π))
        @test pi1 == BigFloat(π)
        @test !addr_eq(pi1, BigFloat(π))

        pi2 = intern(BigFloat(π))
        @test addr_eq(pi1, pi2)

        @testset "type inference" begin
            @test pi1 isa BigFloat
            @inferred intern(BigFloat(π))
        end
    end
end
