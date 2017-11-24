using Base.Test
using StringInterning

macro testtype(ex)
    :(@test typeof($ex) == InternedString) |>esc
end

macro testtypevec(ex)
    :(@test typeof($ex) == Vector{InternedString}) |>esc
end


@testset "Concatenation" begin
    @testtype i"a"*i"b"
    @testtype "a"*i"b"
    @testtype i"a"*"c"*i"b"
    @testtype "a"*i"b"*"c"

    @testtype i"b"^7
end



@testset "split" begin
    @testtypevec split(i"a b c")
end


@testset "Regex" begin
    @testtypevec matchall(r"\d\d", i"11 22 aa 33")
    @testtypevec [m.match for m in eachmatch(r"\d\d", i"11 22 aa 33")]
end
