# InternedStrings

[String interning](https://en.wikipedia.org/wiki/String_interning) in Julia.
To avoid duplicating strings in memory.

Linux & MacOS | Windows | Package Evaluator | CodeCov | License
------------- | ------- | ----------------- | ------- | -------
[![Linux & MacOS][travis-img]][travis-url] | [![Windows][app-img]][app-img] | [![][pkg-s-img]][pkg-url] [![][pkg-m-img]][pkg-url] | [![codecov.io][codecov-img]][codecov-url] | [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

[travis-img]: https://travis-ci.org/JuliaString/InternedStrings.jl.svg?branch=master
[travis-url]: https://travis-ci.org/JuliaString/InternedStrings.jl

[app-url]:    https://ci.appveyor.com/project/ScottPJones/internedstrings-jl/branch/master
[app-img]:    https://ci.appveyor.com/api/projects/status/8dlhr5sprhokwyqb/branch/master?svg=true

[pkg-url]:    http://pkg.julialang.org/detail/InternedStrings
[pkg-s-img]:  http://pkg.julialang.org/badges/InternedStrings_0.6.svg
[pkg-m-img]:  http://pkg.julialang.org/badges/InternedStrings_0.7.svg

[codecov-url]: http://codecov.io/github/JuliaString/InternedStrings.jl?branch=master
[codecov-img]: http://codecov.io/github/JuliaString/InternedStrings.jl/coverage.svg?branch=master

## Usage

`intern(s)` returns an interned string.
The short of it is that you can call `intern(s)` on any strings you expect to have multiple copies of in memory, and you will enjoy memory savings.
You will also enjoy much faster equality checks (via pointer comparison, or in julia 1.2+ via `==` shortcutting to this).

Here is a simple example clarifying what interning does:

```julia
julia> a = "Gold"
"Gold"
julia> b = "Gold"
"Gold"
julia> pointer(a) == pointer(b)
false
julia> pointer(intern(a)) == pointer(intern(b))
true
```

In the first case, both `a` and `b` exist separately in memory (different pointers).
In the second case, both `intern(a)` and `intern(b)` are strings that refer to the same piece of data in memory (same pointers).
All interned strings that are content equal, are referentially equal.

For convenience, the macro `i"string"` amounts to `intern(string)`:

```julia
julia> i"julia" === intern("julia")
true
```

Note that it works with the `SubString` type as well:

```julia
julia> wk = "Wikipedia"
"Wikipedia"
julia> pointer(intern("pedia")) == pointer(intern(SubString(wk, 5, 9)))
true
```

More generally it works for most immutable types.

### Example use case: Natural Language Processing

String interning can be particularly useful in Natural Language Processing (NLP) where tokenization of texts creates vectors of the individual components (e.g.: words) of the text.
Since these components are likely to repeat themselves across texts, interning them can lead to less memory being used overall.
In the example below we consider splitting two paragraphs of the [Wikipedia article on string interning](https://en.wikipedia.org/wiki/String_interning):

```julia
julia> a = raw"""
In computer science, '''string interning''' is a method of storing only one copy of each distinct [[String (computer science)|string]] value, which must be [[Immutable object|immutable]].<ref>{{cite web|title=String.Intern Method (String)|url=https://msdn.microsoft.com/en-us/library/system.string.intern(v=vs.110).aspx|website=Microsoft Developer Network|accessdate=25 March 2017}}</ref> Interning strings makes some string processing tasks more time- or space-efficient at the cost of requiring more time when the string is created or interned. The distinct values are stored in a '''string intern pool'''.
""";
julia> b = raw"""
String interning is supported by some modern [[object-oriented]] [[programming language]]s, including [[Python (programming language)|Python]], [[PHP]] (since 5.4), [[Lua (programming language)|Lua]],<ref>[http://lua-users.org/wiki/ImmutableObjects Immutable objects in Lua]</ref> [[Ruby (programming language)|Ruby]] (with its symbols), [[Java (programming language)|Java]],
[[Julia_(programming_language)|Julia]]
and [[List of CLI languages|.NET languages]].<ref>[http://msdn.microsoft.com/en-us/library/system.string.aspx#Immutability Immutable objects in .NET]</ref> [[Lisp (programming language)|Lisp]], [[Scheme (programming language)|Scheme]], and [[Smalltalk]] are among the languages with a [[Symbol (programming)|symbol]] type that are basically interned strings. The library of the [[Standard ML of New Jersey]] contains an <tt>atom</tt> type that does the same thing. [[Objective-C]]'s selectors, which are mainly used as method names, are interned strings.
""";
julia> splita, splitb = split(a), split(b);
julia> isplita, isplitb = intern.(splita), intern.(splitb);
julia> length(union(pointer.(splita), pointer.(splitb)))
163
julia> length(union(pointer.(isplita), pointer.(isplitb)))
123
julia> length(splita) + length(splitb)
163
```

No interning leads to 163 pointers with one pointer per individual component of `a` and `b`.
Interning leads to 123 pointers with pointers being reused for recurring individual components (e.g. `String` appears multiple times in both `a` and `b`).
The NLP use-case is discussed in more details further below.

### Garbage collection

The interned strings are fully transparent -- they are normal references to the original string.
So when all references to that string (i.e. all "copies" of it from interning) go out of scope, it will be garbage collected.
And when that interned string goes out of scope, it **will** be garbage collected, so you don't have to worry about it.

### What types can be interned?

You can intern any type (not just a string) though it is recommended for use with **immutable types** as unexpected behavior can happen when mutating objects that have been interned.

All types go into their own interning pool.
Except `SubString`s, which are interned into their parent string type,
as we do not want to be holding on to reference to the parent string while a interned reference exists.
You can overload the behavior of `intern(::MyType)` in the usual way.

You might like to intern the strings from [Strs.jl](https://github.com/JuliaString/Strs.jl)

## Motivation and NLP

In NLP, when looking at a text document, a common first task is to break it up into tokens.
Tokenization can often be done simply using `split` or using regex or even bespoke tools such as [WordTokenizers.jl](https://github.com/JuliaText/WordTokenizers.jl).

There is an issue though:
how much are these tokens costing you in memory use?
The math in this section is a bit hand-wavy and an over-simplification, but it should give you the gist of it.

Consider you have a 100MB (10⁸ bytes) text file.
As a `String` object, it takes approximately 10⁸ bytes (discounting pointer, length marker etc.).
To simplify, let us say that the average token length is 10 bytes meaning that the text contains of the order of 10⁷ tokens.
If each of these tokens is a `String`, then that takes up a total of 10⁸ bytes of content.
But each of these `String` object is accompanied by their pointers and length markers etc, i.e. another 10⁷-10⁸ bytes or, to simplify, ≈2×10⁸ bytes.

Using `SubString` for the tokens helps: it still takes ≈2×10⁸ bytes but it avoids doing the memory allocations for the content of each token since each object just contains pointers to the original string.
However, there is a catch: every `SubString` holds a strong reference to the original string.
So long as even 1 `SubString` survives that 100MB has to stay in memory.

It is however very common to discard a lot of those tokens, for example: the stop-words or the 20 most common words (often >10% of the content).
So, in practice, you may only really want to keep track of a number of tokens *far smaller* than the number of words in the text; yet, with `SubString` tokens, you must keep the whole text in memory.
This is also the case when considering word embeddings.

## Conclusion

### What we want

1. Have lots of `String`-like objects, without lots of allocations (like `SubString`, unlike `String`)
2. Not have to worry about mistakenly keeping the original, huge, source string in memory (like `String`, unlike `SubString`)
3. Not have to worry about managing the memory of the strings ourselves
4. Use less memory.

### Under the hood

The value returned by `intern` is a strong reference to a real `String`.
But unlike for normal `String` objects,  if `s1==s1` then `pointer(intern(s1)) == pointer(intern(s2))`; i.e. strings that are content equal, are also reference equal (once interned).

When a string is interned, we check to see if there already is an interned string with that content, and if so return it.
Interning a string has no ongoing new allocations -- not even the pointer and length marker that `SubString` has.
This solves **1.**.

You don't have to worry about mistakenly keeping the huge source string in memory, (Like `SubString`) as they do not have a reference to that huge string, unless they **are** that huge source string.
This solves point **2.**

On point **3.** you don't have to worry about managing the memory yourself,
because each is just a normal reference to it's content.
Once the last string with that content goes out of scope (and is garbage collected), removing the copy in the interning pool will be handled automatically (it is a `WeakRef`, so won't keep it alive).

Final point **4:**.
The original 10⁸ byte document, with 10⁷ words probably only has about 50,000 (5×10⁴) unique words after cleaning.
(Looking at real world data, the first 10⁷ tokens of Wikipedia,
is has 3.5×10⁵ words, but that is before rare words, numbers etc are removed)
At an average of 10 bytes long you only need to be keeping 5×10⁵ bytes of content, plus for each 8 bytes of pointers/length markers (8×10⁴), plus 1 byte each for null terminating them all.
(Grand total: 5.9×10⁵ bytes vs original 10⁸+9 bytes).
The only difference memory-wise between tokenizing into Strings or  SubStrings is that the memory for the content in substrings is all contiguous, where as for Strings it need to be reallocated.

## FAQ and comments


### Why isn't everyone doing this?

This is not an original idea and almost a direct implementation of the method described on [Wikipedia](https://en.wikipedia.org/wiki/String_interning#Reclaiming_unused_interned_strings).
Plenty of languages use or allow string interning.

### Can we cut down the per-token cost for those pointers?

Yes, but you need to decrease the size of the pointers.
On a 32-bit Julia build those costs would all be halved.
Cutting this down without changing the system's pointer type, requires using manual pointer which, in turn, requires writing more manual memory management (at least reference counting) that would be considered reasonable.
But even with 16 bit pointers (65,536) are probably just enough for most NLP tasks.

One other thing to do is to use [MLLabelUtils.jl](https://github.com/JuliaML/MLLabelUtils.jl) (on-top of `InternedStrings.jl`) and encode your strings as `Int`s.

### What about Symbols? Aren't they interned strings?

Symbols are not semantically strings at all.
Semantically they are names.
They are not a subtype of `AbstractString`, they don't support string operations.
You could build a interned string around them though.
However, to the best of my knowledge, they are never garbage collected.

### What about serialization ?

The interning is transparent: after interning it is still just a string.
So it serializes completely fine -- as the string that it is.
However, when you deserialize a string it creates a new (not yet interned) string with the serialized content.
This means interning strings in other processes (e.g. via `pmap`) does not work.
(It is however completely safe to intern strings in any thread. This code is fully thread-safe.)


### What about the factor packages ?

[CategoricalArray](https://github.com/JuliaData/CategoricalArrays.jl)s etc. are pretty similar in many ways.
But they are focused on pooling for a single array.

The unmaintained (and unregistered) [PooledElements.jl](https://github.com/tshort/PooledElements.jl), did global pools but without automatic garbage collection.
Also not referentially sane -- magic is required to make sure it was working with serialization etc.

### What is the downside?

There is basically no downside to interning a string.
The only overhead is to compute the hash of the string, to check if it has already been interned or not.

There are more downsides vs `SubString`.
Substrings avoid allocating memory for segments of content,
which means you can put off and potentially outright avoid expensive allocations.
