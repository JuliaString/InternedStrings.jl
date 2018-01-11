
const pool = WeakKeyDict{String, Void}()


function intern!(wkd::WeakKeyDict{K}, key::K)::K where K
    kk = convert(K, key)
    kwr = WeakRef(kk)

    lock(wkd) do
        index = Base.ht_keyindex2(wkd.ht, kwr) # returns index if present, or -index if not
        if index > 0
            # found it
            @inbounds found_key = wkd.ht.keys[index]
            return found_key.value # a strong ref
        else
            # Not found, so add it,
            # and mark it as a reference we track to delete!
            finalizer(kk, wkd.finalizer) # finalizer is set on the strong ref
            @inbounds Base._setindex!(wkd.ht, nothing, kwr, -index)
            return kk # Return the strong ref
        end
    end
end

struct InternedString <: AbstractString
    value::String

    InternedString(s) = new(intern!(pool, s))
end

macro i_str(s)
    true_string_expr = esc(parse(string('"', unescape_string(s), '"')))
    Expr(:call, InternedString,true_string_expr)
end

Base.convert(::Type{InternedString}, s::AbstractString) = InternedString(s)
Base.convert(::Type{String}, s::InternedString) = String(s)
Base.String(s::InternedString) = s.value


Base.endof(s::InternedString) = endof(s.value)
Base.next(s::InternedString, i::Int) = next(s.value, i)

Base.:(==)(s1::InternedString, s2::InternedString) = s1.value === s2.value # InternedStrings have refernitally equal values
Base.:(==)(s1::String, s2::InternedString) = s1 == s2.value # use faster than the AbstractString equality check
Base.:(==)(s1::InternedString, s2::String) = s2 == s1

Base.hash(s::InternedString, h::UInt) = hash(s.value, h)
