__precompile__(true)
"""
InternedStrings

Copyright 2017-2018 Lyndon White (and other contributors)
Licensed under MIT License, see LICENSE.md
"""
module InternedStrings

export @i_str, intern

Base.@deprecate_binding(InternedString, String, true)

using Base: ht_keyindex2!

########################
# The pool/interning lookup core code

# This forces the type to be inferred (I don't know that the @noinline is reqired or even good)
@noinline getvalue(::Type{K}, wk) where {K} = wk.value::K

# NOTE: This code is carefully optimised.
# Do not tweak it (for readability or otherwise) without benchmarking
@inline function intern!(wkd::WeakKeyDict{K}, key)::K where {K}
    lock(wkd.lock)
    # hand positioning the locks and unlocks
    # (rather than do block or try finally, seems to be faster)
    index = ht_keyindex2!(wkd.ht, key) # returns index if present, or -index if not
    # note hash of weakref is equal to the hash of value, so avoid constructing it if not required
    if index > 0
        # found it
        @inbounds found_key = wkd.ht.keys[index]
        unlock(wkd.lock)
        return getvalue(K, found_key) # return the strong ref
    else
        # Not found, so add it,
        # and mark it as a reference we track to delete!
        kk::K = convert(K, key)
        finalizer(wkd.finalizer, kk) # finalizer is set on the strong ref
        @inbounds Base._setindex!(wkd.ht, nothing, WeakRef(kk), -index)
        unlock(wkd.lock)
        return kk # Return the strong ref
    end
end
#####################################################
# Setup for types

const pool = Dict{DataType, WeakKeyDict}()

@inline function get_pool(::Type{T})::WeakKeyDict{T, Nothing} where {T}
    get!(pool, T) do
        WeakKeyDict{T, Nothing}()
    end
end


###################################

"""
    intern(s::T)

Return a reference to a interned instance of `s`,
adding it to the interning pool if it did not already exist.
"""
function intern(s::T)::T where {T}
    intern(T, s)
end

"""
    intern(::Type{T}, s)

Intern `s` as if it were type `T`, converting it if required.
Note that this will lead to unexpected behavour if the type of `s`, and `T`,
do not have equivalent equality and hash functions
(i.e. this is not safe if `hash(s) != hash(convert(T, s))`).
"""
function intern(::Type{T}, s)::T where {T}
    intern!(get_pool(T), s)
end

"""
Substrings are interned as their parent string type
"""
function intern(substr::SubString{T})::T where {T}
    intern(T, substr)
end


#############################


macro i_str(s)
    # This is done to get interpolation to work correctly
    true_string_expr = esc(Meta.parse(string('"', unescape_string(s), '"')))
    Expr(:call, intern, true_string_expr)
end

end # module InternedStrings
