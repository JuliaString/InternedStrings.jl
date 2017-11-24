using StringInterning
using Base.Test

"This function makes use of `xs` in a way no optimizer can possibly remove"
function use(xs...)
    mktemp() do fn, fh
        print(fh, xs)
    end
end

@testset "Basic String Functionality" begin let
    empty!(StringInterning.pool)

    s = InternedString("Hello My Friends1")

    @test length(s) == length("Hello My Friends1")

    @test startswith(s, "Hello")

    @test s == s
    @test s == "Hello My Friends1"

    @test InternedString(s) === s
end end


@testset "Interning" begin let
    empty!(StringInterning.pool)
    a = "Hello My Friends2"
    b = join(["Hello", "My", "Friends2"], " ")
    @test !(a===b) # sanity check that strings are not already Interning

    ai = InternedString(a)
    bi = InternedString(b)
    @test ai.value === bi.value == a
end end


@testset "string macro" begin let
    @test i"abc" == "abc"
    @test i"a\na\na\na" == join(fill("a", 4), "\n")

    @test_broken i"a $(2*54) c" == "a 108 c"
    # I'ld like interpolation to work at some point
    # Til then one has to write as below
    @test InternedString("a $(2*54) c") == "a 108 c"
end end


@testset "Garbage Collections" begin let
    @testset "Garbage Collection 1" begin let
        empty!(StringInterning.pool)
        @test length(StringInterning.pool)==0
        ai =  InternedString("Hello My Friends3")
        ai = [44] #remove the reference
        gc();
        @test 0<=length(StringInterning.pool)<=1 #May or may not have been collected yet
    end end

    @testset "Garbage Collection 2" begin let
        empty!(StringInterning.pool)
        @test length(StringInterning.pool)==0
        ai = InternedString("Hello My Friends4")
        bi = InternedString(join(["Hello", "My", "Friends4"], " "))
        @test ai.value === bi.value
        @test length(StringInterning.pool)==1
        use(ai,bi)
        ai = [44]
        gc()
        @test length(StringInterning.pool)==1 #don't collect when only one reference is gone
        use(bi)
        bi=[32]
        gc()
        @test 0<=length(StringInterning.pool)<=1
    end end
end end
