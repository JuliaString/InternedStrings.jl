
const pool = WeakKeyDict{String, WeakRef}()

# work around   https://github.com/JuliaLang/julia/issues/24721
function patched_get!(wkd::WeakKeyDict{K}, key, default) where{K}
    kk = convert(K, key)
    kwr = WeakRef(kk)
    lock(wkd) do
        if haskey(wkd.ht, kwr)
            return wkd.ht[kwr]
        else
            # Not found, so add it,
            # and mark it as a reference we track to delete!
            finalizer(kk, wkd.finalizer)
            return wkd.ht[kwr]=default
        end
    end
end

struct InternedString <: AbstractString
    value::String

    function InternedString(s)
        #can't use get! as  https://github.com/JuliaLang/julia/issues/24721
        value = convert(String, s)
        ret = new(patched_get!(pool, value, WeakRef(value)).value)
        @assert ret.value == value
        ret
    end
end

macro i_str(s)
    :(InternedString($(unescape_string(s)))) # handle escapes like real string literals
end



Base.endof(s::InternedString) = endof(s.value)
Base.next(s::InternedString, i::Int) = next(s.value, i)

Base.sizeof(s::InternedString) = sizeof(s.value)

Base.String(s::InternedString) = s.value


Base.:(==)(s1::InternedString, s2::InternedString) = s1.value === s2.value # InternedStrings have refernitally equal values
Base.:(==)(s1::String, s2::InternedString) = s1 == s2.value # use faster than the AbstractString equality check
Base.:(==)(s1::InternedString, s2::String) = s2 == s1

Base.hash(s::InternedString, h::UInt) = hash(s.value, h)
