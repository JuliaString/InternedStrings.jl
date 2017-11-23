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
@testset "Interning" begin
    a = "Hello My Friends2"
    b = join(["Hello", "My", "Friends2"], " ")
    @test !(a===b) # sanity check that strings are not already Interning

    ai = InternedString(a)
    bi ==InternedString(b)
    @test ai.value === bi.value == a
end


@testset "Garbage Collections" begin
    @testset "Garbage Collection 1" begin
        empty!(StringInterning.pool)
        @test length(StringInterning.pool)==0
        ai =  InternedString("Hello My Friends3")
        ai = [44] #remove the reference
        gc();
        @test length(StringInterning.pool)==0
    end

    @testset "Garbage Collection 2" begin
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
    end


end
