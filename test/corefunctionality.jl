using InternedStrings
using Base.Test

empty!(InternedStrings.pool)

"This function makes use of `xs` in a way no optimizer can possibly remove"
function use(xs...)
    mktemp() do fn, fh
        print(fh, xs)
    end
end

@testset "Basic String Functionality" begin let
    empty!(InternedStrings.pool)

    s = InternedString("Hello My Friends1")

    @test length(s) == length("Hello My Friends1")

    @test startswith(s, "Hello")

    @test s == s
    @test s == "Hello My Friends1"

    @test InternedString(s) === s
end end


@testset "Interning" begin let
    empty!(InternedStrings.pool)
    a = "Hello My Friends2"
    b = join(["Hello", "My", "Friends2"], " ")
    @test !(a===b) # sanity check that strings are not already Interning

    ai = InternedString(a)
    bi = InternedString(b)
    @test ai === bi

    @test InternedString("a $(2*54) c") == "a 108 c"
end end






@testset "Garbage Collection 1" begin let
    empty!(InternedStrings.pool)
    @test length(InternedStrings.pool)==0
    ai =  InternedString("Hello My Friends3")
    ai = [44] #remove the reference
    gc();
    @test 0<=length(InternedStrings.pool)<=1 #May or may not have been collected yet
end end

@testset "Garbage Collection 2" begin let
    empty!(InternedStrings.pool)
    @test length(InternedStrings.pool)==0
    ai = InternedString("Hello My Friends4")
    bi = InternedString(join(["Hello", "My", "Friends4"], " "))
    @test ai === bi
    @test length(InternedStrings.pool)==1
    use(ai,bi)
    ai = [44]
    gc()
    @test length(InternedStrings.pool)==1 #don't collect when only one reference is gone
    use(bi)
    bi=[32]
    gc()
    @test 0<=length(InternedStrings.pool)<=1
end end



srand(1)
@testset "Garbage Collection stress test" begin let
    empty!(InternedStrings.pool)
    oldpoolsize = length(InternedStrings.pool)
    function checkpool(op)
        gc()
        @test op(length(InternedStrings.pool), oldpoolsize)
        oldpoolsize = length(InternedStrings.pool)
    end

    originals = [randstring(rand(1:1024)) for _ in 1:10^5]
    n_orginals = length(originals)

    interns = InternedString.(originals);
    checkpool(>)

    for ii in 1:10^5
        push!(interns, InternedString(rand(originals)))
    end
    checkpool(==)
    originals = nothing
    checkpool(==)



    for ii in 1:30
        shuffle!(interns)
        for jj in 1:1000
            pop!(interns)
        end
        checkpool(<=)
    end

    # This one matters:
    @test length(InternedStrings.pool) < n_orginals
end end
