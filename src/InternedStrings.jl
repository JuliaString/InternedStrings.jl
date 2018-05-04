module InternedStrings
using Base

export @i_str, intern

include("corefunctionality.jl")


Base.@deprecate_binding(InternedString, String, true)
#InternedString(s)=intern(String(s))

end
