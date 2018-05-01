const pool = WeakKeyDict{String, Void}()

# This forces the type to be inferred (I don't know that the @noinline is reqired or even good)
@noinline getvalue(::Type{K}, wk) where K = wk.value::K


@inline function intern!(wkd::WeakKeyDict{K}, key)::K where K
    intern!(wkd, convert(K, key))
end

# NOTE: This code is carefully optimised. Do not tweak it (for readability or otherwise) without benchmarking
@inline function intern!(wkd::WeakKeyDict{K}, kk::K)::K where K


    lock(wkd.lock)
        # hand positioning the locks and unlocks (rather than do block or try finally, seems to be faster)
    index = Base.ht_keyindex2(wkd.ht, kk) # returns index if present, or -index if not
    # note hash of weakref is equal to the hash of value, so avoid constructing it if not required
    if index > 0
        # found it
        @inbounds found_key = wkd.ht.keys[index]
        unlock(wkd.lock)
        return getvalue(K, found_key) # return the strong ref
    else
        # Not found, so add it,
        # and mark it as a reference we track to delete!
        finalizer(kk, wkd.finalizer) # finalizer is set on the strong ref
        @inbounds Base._setindex!(wkd.ht, nothing, WeakRef(kk), -index)
        unlock(wkd.lock)
        return kk # Return the strong ref
    end
end

function InternedString(s::T)::T where T
    intern!(pool, s)
end

"""
Substrings are interned as their parent string type
"""
function InternedString(str::SubString{T})::T where T
    InternedString(T(str))
end

macro i_str(s)
    true_string_expr = esc(parse(string('"', unescape_string(s), '"')))
    Expr(:call, InternedString,true_string_expr)
end

Base.convert(::Type{InternedString}, s::AbstractString) = InternedString(s)
