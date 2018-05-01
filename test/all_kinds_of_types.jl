using Base.Test
using InternedStrings

@testset "String" begin
    ex1 = intern!("ex")
    @test ex1=="ex"
    @test !(ex1==="ex")
    ex2 = intern!("ex")
    @test ex1===ex2



    @testset "type inference" begin
        @test ex1 isa String
        @inferred intern!("ex")
    end
end



@testset "SubString" begin
    aa1, bb1, cc1 = intern!.(split("aa bb cc"))
    aa2, bb2, cc2 = intern!.(split("aa bb cc"))

    @test bb1=="bb"
    @test !(bb1==="bb")
    @test bb1===bb2

    @testset "type inference" begin
        @test intern!(split("aa bb cc")[1]) isa String
        @inferred intern!(split("aa bb cc")[1])
    end
end

@testset "BigFloat" begin
    pi1 = intern!(BigFloat(π))
    @test pi1==BigFloat(π)
    @test !(pi1===BigFloat(π))

    pi2 = intern!(BigFloat(π))
    @test pi1===pi2

    @testset "type inference" begin
        @test pi1 isa BigFloat
        @inferred intern!(BigFloat(π))
    end
end
