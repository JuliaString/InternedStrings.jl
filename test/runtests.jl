using StringInterning
using Base.Test

empty!(StringInterning.pool)
@testset "Basic String Functionality" begin
    s = InternedString("Hello My Friends1")

    @test length(s) == length("Hello My Friends1")

    @test startswith(s, "Hello")

    @test s == s
    @test s == "Hello My Friends1"
end



############################################################################
### Implementation defined tests
### These tests actually are defined based on details of the implementation
### But because of how this is, it is basically the only WeakKeyDict

empty!(StringInterning.pool)
@testset "Interning" begin let
    a = "Hello My Friends2"
    b = join(["Hello", "My", "Friends2"], " ")
    @test !(a===b) # sanity check that strings are not already Interning

    ai = InternedString(a)
    bi = InternedString(b)
    @test ai.value === bi.value == a
end end

@testset "Garbage Collections" begin let
    @testset "Garbage Collection 1" begin let
        empty!(StringInterning.pool)
        @test length(StringInterning.pool)==0
        ai =  InternedString("Hello My Friends3")
        ai = [44] #remove the reference
        gc();
        @test length(StringInterning.pool)==0
    end end

    @testset "Garbage Collection 2" begin let
        empty!(StringInterning.pool)
        @test length(StringInterning.pool)==0
        ai = InternedString("Hello My Friends4")
        bi = InternedString(join(["Hello", "My", "Friends4"], " "))
        @test ai.value === bi.value
        @test length(StringInterning.pool)==1
        ai = [44]
        gc()
        @test length(StringInterning.pool)==1 #don't collect when only one reference is gone

        bi=[32]
        gc()
        @test length(StringInterning.pool)==0
    end end
end end

##########################################
# Sanity Tests of the concepts

@testset "how do string finalizers work" begin let
    fin_calls = []

    a = "hi"
    b = a
    finalizer(a, _ -> push!(fin_calls, "a"))
    finalizer(b, _ -> push!(fin_calls, "b"))

    @test fin_calls == []
    a = 7
    gc()
    @test fin_calls == [] # Fails: Evaluated: Any["a", "b"] == Any[]
    #shouldn't trigger finaliser as still has 1 ref, or so I thought

    b=8
    gc()
    @test Set(fin_calls) == Set(["a", "b"]) #both finalizers should trigger
end end


using Base.Test
mutable struct Foo
    val
end
@testset "how do Finalisers work" begin let
    fin_calls = []

    a = Foo(1)
    b = a
    finalizer(a, _ -> push!(fin_calls, "a"))
    finalizer(b, _ -> push!(fin_calls, "b"))

    @test fin_calls == []
    a = 7
    gc()
    @test fin_calls == [] # Fails: Evaluated: Any["a", "b"] == Any[]
    #shouldn't trigger finaliser as still has 1 ref, or so I thought

    b=8
    gc()
    @test Set(fin_calls) == Set(["a", "b"]) #both finalizers should trigger
end end
