using Base.Test

testnames = [
    "all_kinds_of_types",
    "string_macro",
    "corefunctionality"
]
@testset "$testname" for testname in testnames
    include("$testname.jl")
end
