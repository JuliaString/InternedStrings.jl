module StringInterning

using WeakRefStrings
import Base: endof, next, sizeof, String, ==, hash
export InternedString

# The key is weak, the value is strong
# when the key is garbage collected the value is deleted
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
            finalizer(kk, (x)->begin println(x); wkd.finalizer(x) end)
            return wkd.ht[kwr]=default
        end
    end
end

struct InternedString <: AbstractString
    value::String

    function InternedString(s)
        #can't use get! as  https://github.com/JuliaLang/julia/issues/24721
        value = convert(String, s)
        new(patched_get!(pool, value, WeakRef(value)).value)
    end
end



endof(s::InternedString) = endof(s.value)
next(s::InternedString, i::Int) = next(s.value, i)

sizeof(s::InternedString) = sizeof(s.value)

String(s::InternedString) = s.value
string(s::InternedString) = s.value

==(s1::InternedString, s2::InternedString) = s1.value === s2.value # InternedStrings have refernitally equal values
==(s1::String, s2::InternedString) = s1 == s2.value # use faster than the AbstractString equality check
==(s1::InternedString, s2::String) = s2 == s1

hash(s::InternedString, h::UInt) = hash(s.value, h)




end # module
