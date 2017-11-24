
const pool = WeakKeyDict{String, Void}()

function intern!(wkd::WeakKeyDict{K}, key)::K where K
    kk = convert(K, key)
    kwr = WeakRef(kk)
    lock(wkd) do
        found_key = getkey(wkd.ht, kwr, Base.secret_table_token)
        found = !(found_key === Base.secret_table_token)

        if found
            return found_key.value
        else
            # Not found, so add it,
            # and mark it as a reference we track to delete!
            finalizer(kk, wkd.finalizer)
            wkd.ht[kwr]=nothing
            return kk
        end
    end
end

struct InternedString <: AbstractString
    value::String

    InternedString(s) = new(intern!(pool, s))
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
