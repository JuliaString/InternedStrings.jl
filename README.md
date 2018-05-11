# InternedStrings

String interning in julia.
For not having duplicate strings in memory.

[![Build Status](https://travis-ci.org/JuliaString/InternedStrings.jl.svg?branch=master)](https://travis-ci.org/JuliaString/InternedStrings.jl)


[![codecov.io](http://codecov.io/github/JuliaString/InternedStrings.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaString/InternedStrings.jl?branch=master)

## Usage

`intern(s)` returns an interned string.
The short of it is that you can call `intern(s)` on any strings you expect to have multiple copies of in memory, and you will enjoy memory savings.
You'll also enjoy much faster equality checks.


If a string with that content was interned before, calling `intern(s)` will returns (a reference to) the earlier string; if this is the first time the string was interned it will return (a reference to) its input.
Using `s=intern(s)` or otherwise getting rid of old references to memory that you are interning allows the old references to be garbage collected so you only have memory used by unique strings.

The interned strings are fully transparent -- they are normal references to the original string.
So when all references to that string (i.e. all "copies" of it from interning ) go out of scope, it will be garbage collected.
And when that interned string goes out of scope, it **will** be garbage collected, so don't worry about it.

For convenience it also comes in string macro form:
`i"My String Uses Less Memory than Yours"`, makes a string with that content and interns it immediately.

### What types can I intern?
You can intern any type really.
It doesn't actually have to be a string at all.
Strange things will happen if you mutate something that has been interned though; so it is recommended for use with immutable types only.

All types go into their own interning pool.
Except `SubString`s, which are interned into their parent string type,
as we do not want to be holding on to reference to the parent string while a interned reference exists.
You can overload the behavior of `intern(::MyType)` in the usual way.

You might like to intern the strings from [Strs.jl](https://github.com/JuliaString/Strs.jl)

###  What exactly is going on?
If your not familiar with the concept of string interning perhaps the following example will help.

```

julia> using InternedStrings

julia> a = "Gold"
"Gold"

julia> typeof(a), pointer(a)
(String, Ptr{UInt8} @0x00007fe604e93b18)

julia> a = intern(a)
"Gold"

julia> typeof(a), pointer(a) # No change still same memory
(String, Ptr{UInt8} @0x00007fe604e93b18)

julia> b = "Gold"
"Gold"

julia> typeof(b),pointer(b) # New memory, see different ID
(String, Ptr{UInt8} @0x00007fe5fae44444)

julia> b = intern(b) # Replace it,
"Gold"

julia> typeof(b),pointer(b) # See it is same memory as for the original `a`
(String, Ptr{UInt8} @0x00007fe604e93b18)
#now the memory allocated to "b" at addr=0x00007fe5fae44444 can be garbage collected

julia> pointer(intern("Gold")) # Same again
Ptr{UInt8} @0x00007fe604e93b18

julia> pointer(intern(SubString("Golden",1,4))) # Substrings too
Ptr{UInt8} @0x00007fe604e93b1
```


## Motivation (/Ranting)
In natural language processing, when looking at a document,
the first thing to do is to break it up into tokens.
Tokenization can often be done simply: the most simple-case is just `split`,
more complex use some regex, or even something fairly sophisticated.
See [WordTokenizers.jl](https://github.com/JuliaText/WordTokenizers.jl)

There is an issue though:
How much are these tokens costing you in memory use?

Originally you had say a 100MB (10⁸ bytes) text file (multiply this out as required).
Which as a String took-up (10⁸ bytes + 1 pointer (4 or 8 bytes) + 1 length marker (4 or 8 bytes) + null terminating character (total 10⁸ + 9 (or 17) bytes).
To simplify the math lets say the average token  length was 10 bytes.
So you had 10⁷ tokens.

If those tokens are Strings, then that takes up a total of 10⁸ bytes of content,
plus 8×10⁷ bytes of pointers/length markers.

If they are SubStrings, then it still takes up 10⁸ bytes of content,
plus 8×10⁷ bytes of pointers/length markers.
But you have avoided doing the memory allocations for the content bytes,
since you just have pointers to the original.
However, here is the catch:
Every SubString holds a strong reference to your original string.
So long as even 1 SubString survives that 100MB stays in memory.

It is very common to discard a lot of those tokens.

 - A basic use might be to discard stop-words, removing the 20 most common words.
probably >10% the content (Ask Zipf).
     - So with substrings  you are keeping an extra 10⁷ bytes of main content you don't need
 - An extreme case is if you are looking at some Corpus Linguistics,
you might want to retrieve just the 10 most common verbs that occur in a sentence with 4 or more nouns.
      - You only need about 100bytes of content, but with SubStrings you are keeping all 100MB in memory.
 - Another is if you have trained word embeddings, then you need a dictionary where the keys are the set of tokens in the vocabulary.
      - 10,000,000 (10⁷)words probably only has about 50,000 unique words (after cleaning out rare words), so you only need to be keeping 5×10⁵ bytes of content, not 10⁸)
In all these cases you are keeping a lot more memory that you need.
If you are smart you will spot it and convert them to Strings, so the content can be deleted.
But i am not smart, and have made that mistake many times.


So there has to be a better way.
We want to:

 1. Have lots of Strings, without lots of allocations (like SubString, unlike String)
 2. Not have to worry about mistakenly keeping original huge source string in memory (like String, unlike SubString)
 3. Not have to worry about managing the memory of the strings ourself
 4. Just outright use less memory.

Can we do that? Yes we can.

#### `intern`

The value returned by `intern`is a strong reference to a real String.
But unlike for normal use of Strings,  if `s1==s1` then `intern(s1)===intern(s2)`  i.e. strings are that content equal, they are reference equal (once interned).
That is to say if they look like each other, then they are each other.

When a string is interned is created we check to see if there already is an interned string with that content, and if so return it.
interning a string has no on-going new allocations -- not even the pointer and length marker that `SubString` has.
This solves point **1.** by reducing allocations.

You don't have to worry about mistakenly keeping the huge source string in memory, (Like `SubString`)
as they do not have a reference to that huge string, unless they **are** that huge source string.
So that solves point **2.**

On point **3.** you don't have to worry about managing the memory yourself,
because each is just a normal reference to it's content.
Once the last string with with that content goes out of scope (and is garbage collected),
removing the copy in the interning pool will be handled automatically (it is a WeakRef, so won't keep it alive).


Final point **4:**.
As I said before.
The original 10⁸ byte document, with 10⁷ words probably only has about 50,000 (5×10⁴) unique words after cleaning.
(Looking at real world data, the first 10⁷ tokens of wikipedia,
is has 3.5×10⁵ words, but that is before rare words, numbers etc are removed)
At an average of 10 bytes long you only need to be keeping 5×10⁵ bytes of content,
plus for each 8 bytes of pointers/length markers (8×10⁴), plus 1 byte each for null terminating them all. (Grand total: 5.9×10⁵ bytes vs original 10⁸+9 bytes).
The only difference memory wise between tokenizing into Strings or  SubStrings is that the memory for the content in substrings is all contiguous, where as for Strings it need to be reallocated.


 - Original: 10⁸ byte  content, 8 bytes pointers/length markers (To be tokenized to  10⁷ words)
  - Tokenized: 10×10⁷=10⁸ byte  content, 8×10⁷ bytes pointers/length markers. Total 1.8×10⁸ bytes.
 - Tokenized and interned: 10×5×10⁴=5×10⁵ byte  content, 8×10⁷ bytes pointers/length markers. Total 0.805×10⁸ bytes.

These numbers are all pretty rough, I've probably screwed up in a few places.
Point is though, this can better than halve the memory use.
It only gets better when you increase the size of the original document.
As the size of the vocabulary increases only logarithmically with the size of the document.

### Why isn't everyone doing this?
Don't get me wrong, this is not an original idea at all.
This is almost a direct implementation of the method described on [wikipedia](https://en.wikipedia.org/wiki/String_interning#Reclaiming_unused_interned_strings).

Plenty of languages intern strings.
I think it is normal in most languages that have immutable string types.
Maybe one day julia will intern strings by default.

We also could be interning `BigFloat`s and some other types like that.

### Can we cut down the per token cost for those pointers?
Yes, but you need to decrease the size of the pointers.
On a 32bit julia build those costs would all be halved.
Cutting this down without changing the system's pointer type,
requires ending up with manual pointer.
Which requires writing more manual memory management (at least reference counting),
than I want to do.
But like even 16 bit pointers (65,536) are probably just enough for most NLP tasks.

One thing to do is to use (on-top of InternedStrings.jl), [MLLabelUtils.jl](https://github.com/JuliaML/MLLabelUtils.jl) and encode your strings as Ints.




#### What about symbols? Aren't they interned strings?
Symbols are not semantically strings at all.
Semantically they are names.
They are not a subtype of AbstractString, they don't support string operations.
You could totally build a interned string around them though.
However, to the best of my knowledge, they are never, ever garbage collected.

#### What about Factor packages
CategorialArrays etc  are pretty similar.
But they are focused on Pooling for a single array.

The unmaintained (and unregistered) PooledElements.jl, did global pools.
However, no automatic garbage collection.
Also not referentially sane -- magic is required make sure it was working with serialization etc.

### What is the downside?
There is basically no downside to interning a String.
It just takes a little time to hash the string to check if it is there or not.

There are most downsides vs SubString.
Substrings avoid allocating memory for segments of content,
which means you can put off and potentially outright avoid expensive allocations.
