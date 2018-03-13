# This file includes code originally from Julia.
# License is MIT: https://julialang.org/license

export find_next, find_first, find_prev, find_last, found, find_result

"""
    find_next(pattern::Union{Regex,AbstractString}, string::AbstractString, start::Integer)

Find the next occurrence of `pattern` in `string` starting at position `start`.
`pattern` can be either a string, or a regular expression, in which case `string`
must be of type `String`, `ASCIIStr`, `UTF8Str` (or a `SubString` of one of those types)

The return value is a range of indexes where the matching sequence is found, such that
`s[find_next(x, s, i)] == x`:

`find_next("substring", string, i)` = `start:end` such that
`string[start:end] == "substring"`, or `0:-1` if unmatched.

# Examples
```jldoctest
julia> find_next("z", "Hello to the world", 1)
0:-1

julia> find_next("o", "Hello to the world", 6)
8:8

julia> find_next("Julia", "JuliaLang", 2)
1:5
```
"""
function find_next end

"""
    find_first(pattern::Union{Regex,AbstractString}, string::AbstractString)

Find the first occurrence of `pattern` in `string`. Equivalent to
[`find_next(pattern, string, 1)`](@ref).

# Examples
```jldoctest
julia> find_first("z", "Hello to the world")
0:-1

julia> find_first("Julia", "JuliaLang")
1:5
```
"""
function find_first end

"""
    find_prev(pattern::AbstractString, string::AbstractString, start::Integer)

Find the previous occurrence of `pattern` in `string` starting at position `start`.

The return value is a range of indexes where the matching sequence is found, such that
`s[find_prev(x, s, i)] == x`:

`find_prev("substring", string, i)` = `start:end` such that
`string[start:end] == "substring"`, or `0:-1` if unmatched.

# Examples
```jldoctest
julia> find_prev("z", "Hello to the world", 18)
0:-1

julia> find_prev("o", "Hello to the world", 18)
15:15

julia> find_prev("Julia", "JuliaLang", 6)
1:5
```
"""
function find_prev  end

"""
    find_last(pattern::AbstractString, string::AbstractString)

Find the last occurrence of `pattern` in `string`. Equivalent to
[`find_last(pattern, string, lastindex(s))`](@ref).

# Examples
```jldoctest
julia> find_last("o", "Hello to the world")
15:15

julia> find_last("Julia", "JuliaLang")
1:5
```
"""
function find_last  end

abstract type Dir end
struct Fwd <: Dir end
struct Rev <: Dir end

const _not_found = 0:-1

found(::Type{<:AbstractString}, v) = v != 0
find_result(::Type{<:AbstractString}, v) = v

@static if VERSION < v"0.7.0-DEV"

find_next(pat::Regex, str::AbstractString, pos::Integer) = Base.findnext(str, pat, pos)

export EqualTo, equalto, OccursIn, occursin

struct EqualTo{T} <: Function
    x::T

    EqualTo(x::T) where {T} = new{T}(x)
end

(f::EqualTo)(y) = isequal(f.x, y)

"""
    equalto(x)

Create a function that compares its argument to `x` using [`isequal`](@ref); i.e. returns
`y->isequal(x,y)`.

The returned function is of type `Base.EqualTo`. This allows dispatching to
specialized methods by using e.g. `f::Base.EqualTo` in a method signature.
"""
const equalto = EqualTo

struct OccursIn{T} <: Function
    x::T

    OccursIn(x::T) where {T} = new{T}(x)
end

(f::OccursIn)(y) = y in f.x

"""
    occursin(x)

Create a function that checks whether its argument is [`in`](@ref) `x`; i.e. returns
`y -> y in x`.

The returned function is of type `Base.OccursIn`. This allows dispatching to
specialized methods by using e.g. `f::Base.OccursIn` in a method signature.
"""
const occursin = OccursIn

else

import Base: EqualTo, equalto, OccursIn, occursin

find_next(pat::Regex, str::AbstractString, pos::Integer) =
    coalesce(findnext(pat, str, pos), _not_found)

#=
    nothing_sentinel(i) = i == 0 ? nothing : i
    Base.findnext(a, b, i) = nothing_sentinel(find_next(a, b, i))
    Base.findfirst(a, b)   = nothing_sentinel(find_first(a, b))
    Base.findprev(a, b, i) = nothing_sentinel(find_prev(a, b, i))
    Base.findlast(a, b)    = nothing_sentinel(find_last(a, b))
=#
end

@inline function _srch_pred(::Fwd, testf, str, pos)
    for (j, d) in pairs(SubString(str, pos))
        testf(d) && return pos + j - 1
    end
    0
end

@inline function _srch_pred(::Rev, testf, str, pos)
    while pos > 0
        @inbounds ch = str[pos]
        testf(ch) && break
        pos = prevind(str, pos)
    end
    pos
end

function _srch_check(dir, testf, str, pos)
    if pos < 1 || pos > ncodeunits(str)
        @boundscheck boundserr(str, pos)
        return 0
    end
    @inbounds isvalid(str, pos) || index_error(str, pos)
    _srch_pred(dir, testf, str, pos)
end

find_next(pred::EqualTo{<:AbsChar}, str::AbstractString, pos::Integer) =
    _srch_chr(Fwd(), str, pred.x, pos)
find_prev(pred::EqualTo{<:AbsChar}, str::AbstractString, pos::Integer) =
    _srch_chr(Rev(), str, pred.x, pos)

find_next(ch::AbsChar, str::AbstractString, pos::Integer) = _srch_chr(Fwd(), str, ch, pos)
find_prev(ch::AbsChar, str::AbstractString, pos::Integer) = _srch_chr(Rev(), str, ch, pos)

find_first(a, b) = find_next(a, b, 1)
find_last(a,  b) = find_prev(a, b, lastindex(b))

# AbstractString implementations of the generic find_next/find_prev interfaces
find_next(fun::Function, str::AbstractString, pos::Integer) = _srch_check(Fwd(), fun, str, pos)
find_prev(fun::Function, str::AbstractString, pos::Integer) = _srch_check(Rev(), fun, str, pos)

@inline function _srch_codeunit(::Fwd, beg::Ptr{T}, cu::T, pos, len) where {T<:CodeUnitTypes}
    if sizeof(Cwchar_t) == sizeof(T) || T == UInt8
        pnt = _fwd_memchr(bytoff(beg, pos - 1), cu, len - pos + 1)
        pnt == C_NULL ? 0 : chrdiff(pnt, beg) + 1
    else
        beg -= sizeof(T)
        pnt = bytoff(beg, pos)
        fin = bytoff(beg, len)
        while pnt <= fin
            get_codeunit(pnt) == cu && return chrdiff(pnt, beg)
            pnt += sizeof(T)
        end
        0
    end
end

@inline function _srch_codeunit(::Rev, beg::Ptr{UInt8}, cu::UInt8, pos)
    pnt = _rev_memchr(beg, cu, pos)
    pnt == C_NULL ? 0 : chrdiff(pnt, beg) + 1
end

@inline function _srch_codeunit(::Rev, beg::Ptr{T}, cu::T, pos) where {T<:Union{UInt16,UInt32}}
    pnt = bytoff(beg, pos)
    while (pnt -= sizeof(T)) >= beg && get_codeunit(pnt) != cu ; end
    chrdiff(pnt, beg) + 1
end

# _srch_cp is only called with values that are valid for that string type,
# and checking as already been done on the position (pos)
# These definitions only work for CodeUnitSingle types
_srch_cp(::Fwd, str::T, cp::AbsChar, pos, len) where {T<:Str} =
    _srch_codeunit(Fwd(), _pnt(str), cp%codeunit(T), pos, len)
_srch_cp(::Rev, str::T, cp::AbsChar, pos, len) where {T<:Str} =
    _srch_codeunit(Rev(), _pnt(str), cp%codeunit(T), pos)

function _srch_cp(::Fwd, str, cp, pos, len)
    @inbounds while pos <= len
        str[pos] == cp && return pos
        pos = nextind(str, pos)
    end
    0
end

function _srch_cp(::Rev, str, cp, pos, len)
    @inbounds while pos > 0
        str[pos] == cp && return pos
        pos = prevind(str, pos)
    end
    0
end

function _srch_chr(dir, str, ch, pos::Integer)
    if pos < 1
        @boundscheck (pos == 0 && isempty(str)) || boundserr(str, pos)
        return 0
    end
    len = ncodeunits(str)
    if pos > len
        @boundscheck (len == 0 && pos == 1) || boundserr(str, pos)
        return 0
    end
    @inbounds isvalid(str, pos) || index_error(str, pos)
    # Check here if ch is valid for the type of string
    isvalid(eltype(str), ch) ? _srch_cp(dir, str, ch, pos, len) : 0
end

# Substring searching

find_next(needle::AbstractString, str::AbstractString, pos::Integer) =
    _srch_str(Fwd(), str, needle, pos)
find_prev(needle::AbstractString, str::AbstractString, pos::Integer) =
    _srch_str(Rev(), str, needle, pos)

# Todo: make use of CompareStyle trait to improve performance

"""Compare two strings, starting at nxtstr and nxtsub"""
@inline function _cmp_str(str, strpos, sub, subpos)
    while !done(str, strpos)
        c, strnxt = next(str, strpos)
        d, subpos = next(sub, subpos)
        c == d || break
        done(sub, subpos) && return strpos
        strpos = strnxt
    end
    0
end

function _srch_strings(::Fwd, ::CompareStyle, str, needle, ch, nxtsub, pos, slen, tlen)
    while (pos = _srch_cp(Fwd(), str, ch, pos, slen)) != 0
        nxt = nextind(str, pos)
        res = _cmp_str(str, nxt, needle, nxtsub)
        res == 0 || return pos:res
        pos = nxt
        done(str, nxt) && break
    end
    _not_found
end

function _srch_strings(::Rev, ::CompareStyle, str, needle, ch, nxtsub, pos, slen, tlen)
    # We don't know if tlen and slen are even compatible
    # This should be changed to be efficient if both are CodeUnitSingle
    # We are always checking 2 or more characters here
    prv = prevind(str, pos)
    prv == 0 && return _not_found
    while (pos = _srch_cp(Rev(), str, ch, prv, slen)) != 0
        res = _cmp_str(str, nextind(str, pos), needle, nxtsub)
        res == 0 || return pos:res
        (prv = prevind(str, pos)) == 0 && break
    end
    _not_found
end

_search_bloom_mask(ch) = UInt64(1) << (ch & 63)
_check_bloom_mask(mask, pnt, off) = (mask & _search_bloom_mask(get_codeunit(pnt, off))) == 0

# This should work for compatible CSEs, like ASCII & Latin, ASCII & UTF8, etc.
# See equals trait
function _srch_strings(::Fwd, ::Union{ByteCompare,WidenCompare}, str, needle,
                       ch, nxtsub, pos, slen, tlen)
    spnt = _pnt(str)
    npnt = _pnt(needle)

    tlast = get_codeunit(npnt, tlen)
    bloom_mask = _search_bloom_mask(tlast)
    skip = tlen - 1
    for j in 1:tlen-1
        cu = get_codeunit(npnt, j)
        bloom_mask |= _search_bloom_mask(cu)
        cu == tlast && (skip = tlen - j - 1)
    end

    pos -= 1
    while pos <= slen
        if get_codeunit(spnt, pos + tlen) == tlast
            pos += 1
            # check candidate
            j = 0
            while j < tlen - 1 && get_codeunit(spnt, pos + j) == get_codeunit(npnt, j + 1)
                j += 1
            end

            # match found
            j == tlen - 1 && return pos:pos+j

            # no match, try to rule out the next character
            if pos <= slen && _check_bloom_mask(bloom_mask, spnt, pos + tlen)
                pos += tlen
            else
                pos += skip
            end
        elseif (pos += 1) <= slen && _check_bloom_mask(bloom_mask, spnt, pos + tlen)
            pos += tlen
        end
    end

    _not_found
end

function _srch_str(dir::Dir, str::AbstractString, needle::AbstractString, pos::Integer)
    # Check for fast case of a single codeunit (should check for single character also)
    slen = ncodeunits(str)
    if slen == 0
        # Special case for empty string
        @boundscheck pos == 1 || pos == 0 || boundserr(str, pos)
        return ifelse(isempty(needle), 1:0, _not_found)
    end
    if !(1 <= pos <= slen)
        @boundscheck boundserr(str, pos)
        return _not_found
    end
    @inbounds isvalid(str, pos) || index_error(str, pos)
    tlen = ncodeunits(needle)
    tlen == 0 && return pos:pos-1
    (cmp = CanContain(str, needle)) === NoCompare() && return _not_found
    @inbounds ch, nxt = next(needle, 1)
    isvalid(eltype(str), ch) || return _not_found
    # Check if single character
    if nxt > tlen
        pos = _srch_cp(dir, str, ch, pos, slen)
        return pos == 0 ? _not_found : (pos:pos)
    end
    _srch_strings(dir, cmp, str, needle, ch, nxt, pos, slen, tlen)
end

@static if VERSION < v"0.7.0-DEV"
    contains(hay::AbstractString, chr::AbsChar)   = _srch_chr(Fwd(), hay, chr, 1) != 0
else
    # Avoid type piracy
    contains(hay::Str, chr::Char)                 = _srch_chr(Fwd(), hay, chr, 1) != 0
    contains(hay::AbstractString, chr::CodePoint) = _srch_chr(Fwd(), hay, chr, 1) != 0
end
contains(hay::Str, str::Str)            = _srch_str(Fwd(), hay, str, 1) != 0
contains(hay::Str, str::AbstractString) = _srch_str(Fwd(), hay, str, 1) != 0
contains(hay::AbstractString, str::Str) = _srch_str(Fwd(), hay, str, 1) != 0

in(chr::CodePoint, str::AbstractString) = contains(str, chr)
in(chr::AbsChar,   str::Str)            = contains(str, chr)
in(pat::Str, str::Str)                  = contains(str, pat)
in(pat::Str, str::AbstractString)       = contains(str, pat)
in(pat::AbstractString, str::Str)       = contains(str, pat)

using Base.PCRE

using Base: DEFAULT_COMPILER_OPTS, DEFAULT_MATCH_OPTS
import Base: Regex, match

const ByteRegexCSE = Union{ASCIICSE,Latin_CSEs,Binary_CSEs}

cvt_compile(::Type{<:ByteRegexCSE}, co) = co & ~PCRE.UTF
cvt_match(::Type{<:ByteRegexCSE}, co)   = co & ~PCRE.NO_UTF_CHECK
cvt_compile(::Type{UTF8CSE}, co)  = co | PCRE.NO_UTF_CHECK | PCRE.UTF
cvt_match(::Type{UTF8CSE}, co)    = co | PCRE.NO_UTF_CHECK

Regex(pattern::Str{C}, co, mo) where {C<:Byte_CSEs} =
    Regex(String(pattern), cvt_compile(C, co), mo)
Regex(pattern::Str{C}) where {C<:Byte_CSEs} =
    Regex(String(pattern),
          cvt_compile(C, DEFAULT_COMPILER_OPTS), cvt_match(C, DEFAULT_MATCH_OPTS))

function _update_compiler_opts(flags)
    options = DEFAULT_COMPILER_OPTS
    for f in flags
        options |= f=='i' ? PCRE.CASELESS  :
                   f=='m' ? PCRE.MULTILINE :
                   f=='s' ? PCRE.DOTALL    :
                   f=='x' ? PCRE.EXTENDED  :
                   throw(ArgumentError("unknown regex flag: $f"))
    end
    options
end

Regex(pattern::Str{C}, flags::AbstractString) where {C<:Byte_CSEs} =
    Regex(pattern, cvt_compile(C, _update_compile_opts(flags)), cvt_match(C, DEFAULT_MATCH_OPTS))

struct RegexMatchStr{T<:AbstractString}
    match::T
    captures::Vector{Union{Nothing,T}}
    offset::Int
    offsets::Vector{Int}
    regex::Regex
end

function show(io::IO, m::RegexMatchStr)
    print(io, "RegexMatchStr(")
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
getindex(m::RegexMatchStr, idx::Integer) = m.captures[idx]
function getindex(m::RegexMatchStr, name::Symbol)
    idx = PCRE.substring_number_from_name(m.regex.regex, name)
    idx <= 0 && error("no capture group named $name found in regex")
    m[idx]
end

getindex(m::RegexMatchStr, name::AbstractString) = m[Symbol(name)]

"""
Check if the compile flags match the current search

If not, free up old compilation, and recompile
For better performance, the Regex object should hold spots for 5 compiled regexes,
for 8-bit, UTF-8, 16-bit, UTF-16, and 32-bit code units
"""
function check_compile(::Type{C}, regex::Regex) where {C<:CSE}
    # ASCII is compatible with all (current) types, don't recompile
    re = regex.regex
    C == ASCIICSE && re != C_NULL && return
    oldopt = regex.compile_options
    cvtcomp = cvt_compile(C, oldopt)
    if cvtcomp != oldopt
        regex.compile_options = cvtcomp
        re == C_NULL || (PCRE.free_re(re); regex.regex = re = C_NULL)
        regex.match_data == C_NULL ||
            (PCRE.free_match_data(regex.match_data); regex.match_data = C_NULL)
    end
    if re == C_NULL
        regex.regex = re = PCRE.compile(regex.pattern, cvtcomp)
        PCRE.jit_compile(re)
        regex.match_data = PCRE.create_match_data(re)
        regex.ovec = PCRE.get_ovec(regex.match_data)
    end
    nothing
end

function _match(::Type{C}, re, str, idx, add_opts) where {C<:CSE}
    check_compile(C, re)
    PCRE.exec(re.regex, str, idx-1, cvt_match(C, re.match_options | add_opts), re.match_data) ||
        return nothing
    ovec = re.ovec
    n = div(length(ovec),2) - 1
    ss = C == _LatinCSE ? Str{LatinCSE}(str) : str
    mat = SubString(ss, ovec[1]+1, prevind(ss, ovec[2]+1))
    cap = Union{Nothing,SubString{typeof(ss)}}[ovec[2i+1] == PCRE.UNSET ? nothing :
                                        SubString(ss, ovec[2i+1]+1,
                                                  prevind(ss, ovec[2i+2]+1)) for i=1:n]
    off = Int[ ovec[2i+1]+1 for i=1:n ]
    RegexMatchStr(mat, cap, Int(ovec[1]+1), off, re)
end

match(re::Regex, str::Str, idx::Integer, add_opts::UInt32=UInt32(0)) =
    _match(cse(str), re, str, Int(idx), add_opts)

function find_next(re::Regex, str::Union{Str{C},SubString{<:Str{C}}},
                   idx::Integer) where {C<:Byte_CSEs}
    if idx > ncodeunits(str)
        @boundscheck boundserr(str, idx)
        return nothing
    end
    check_compile(C, re)
    (PCRE.exec(re.regex, str, idx-1, cvt_match(C, re.match_options), re.match_data)
     ? ((Int(re.ovec[1])+1):prevind(str,Int(re.ovec[2])+1)) : nothing)
end
