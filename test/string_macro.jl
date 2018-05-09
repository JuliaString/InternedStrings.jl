@testset "string macro" begin
    @test i"abc" == "abc"
    @test i"abc" == i"abc"

    @test i"a\na\na\na" == join(fill("a", 4), "\n")
    @test object_id_eq(i"a\na\na\na", intern(join(fill("a", 4), "\n")))

    @test i"a $(2*54) c" == "a 108 c"
    @test object_id_eq(i"a $(2*54) c", i"a 108 c")

    x = "cruel"
    @test i"hello $x world" == "hello cruel world"
    @test object_id_eq(i"hello $x world", i"hello cruel world")
end
