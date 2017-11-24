

# controls `*`
Base.string(x::InternedString, ys...) = InternedString(string(x.value, ys...))
Base.string(x::AbstractString, y::InternedString, zs...) = InternedString(string(x, y.value, zs...))
Base.string(x::InternedString, y::InternedString, zs...) = InternedString(string(x.value, y.value, zs...))


function Base.split(str::InternedString, splitter; limit::Integer=0, keep::Bool=true)
    InternedString.(split(str.value, splitter; limit=limit, keep=keep))
end

Base.repeat(s::InternedString, r::Integer) = InternedString(repeat(s.value, r))



##########
# RegEx
struct InternedRegexMatch
    match::InternedString
    captures::Vector{Union{Void,InternedString}}
    offset::Int
    offsets::Vector{Int}
    regex::Regex
end

function intern(m::RegexMatch)
    InternedRegexMatch(
        InternedString(m.match),
        [c isa SubString ? InternedString(c) : c for c in m.captures],
        m.offset,
        m.offsets,
        m.regex
    )
end


function Base.show(io::IO, m::InternedRegexMatch)
    print(io, "InternedRegexMatch(")
    show(io, m.match)
    idx_to_capture_name = PCRE.capture_names(m.regex.regex)
    if !isempty(m.captures)
        print(io, ", ")
        for i = 1:length(m.captures)
            # If the capture group is named, show the name.
            # Otherwise show its index.
            capture_name = get(idx_to_capture_name, i, i)
            print(io, capture_name, "=")
            show(io, m.captures[i])
            if i < length(m.captures)
                print(io, ", ")
            end
        end
    end
    print(io, ")")
end

# Capture group extraction
Base.getindex(m::InternedRegexMatch, idx::Integer) = m.captures[idx]
function Base.getindex(m::InternedRegexMatch, name::Symbol)
    idx = PCRE.substring_number_from_name(m.regex.regex, name)
    idx <= 0 && error("no capture group named $name found in regex")
    m[idx]
end
Base.getindex(m::InternedRegexMatch, name::AbstractString) = m[Symbol(name)]

##
function Base.match(re::Regex, str::InternedString, idx::Integer, add_opts::UInt32=UInt32(0))
    intern(match(re, str.value, idx, add_opts))
end

function Base.matchall(re::Regex, str::InternedString, overlap::Bool=false)
    InternedString.(matchall(re, str.value, overlap))
end

function Base.eachmatch(re::Regex, str::InternedString, ovr::Bool=false)
    (intern(m) for m in eachmatch(re, str.value, ovr))
end
