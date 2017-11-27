# InternedStrings

String interning in julia.
For not having duplicate strings in memory.

[![Build Status](https://travis-ci.org/oxinabox/InternedStrings.jl.svg?branch=master)](https://travis-ci.org/oxinabox/InternedStrings.jl)

## Usage

`InternedString(s)` returns an interned string.
it won't allocate new memory if an interned string with that content already exists.
And when that interned string goes out of scope, it **will** be garbage collected, so don't worry about it.

For convenience it also comes in string macro form:
`i"My String Uses Less Memory than Yours"`, makes an interned string with that content.

Use them just like you would Strings and enjoy your memory savings.


####  `split` and regex the functions don't return substrings anymore :-( :-(
Yes,  `split`ing an InternedString does not make a vector of  `SubString{InternedString}`.
It just make an `InternedString`.
Similar for all the regex function.

Ideally we would also change every `SubStrings{InternedString}` everywhere, to be just `InternedString`.
But it is a bit too breaking.

SubStrings and InternedStrings solve roughly the same problem.
But with different techniques and trade-offs.
If you are using InternedStrings you probably don't want a substring anywhere.
Since you might mistakenly end-up holding on to a really big string.
The very problem this is designed to avoid.

Please raise issues if you find functions that are returning SubStrings,
that shouldn't be.


## Motivation (/Ranting)
In natural language processing,
when looking at a document,
the first thing to do is to break it up into tokens.
Tokenization can often be done simply:
the most simple-case is just `split`,
more complex use some regex, or even something fairly sophisticated.

There is an issue though:
How much are these tokens costing you in memory use?

Originally you had say a 100MB (10⁸ bytes) text file (multiply this out as required).
Which as a String took-up (10⁸ bytes + 1 pointer (4 bytes) + 1 length marker (4 bytes) + null terminating character (total 10⁸ + 9 bytes).
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


One option is to use [WeakRefStrings.jl](https://github.com/quinnj/WeakRefStrings.jl).
In those, keeping you WeakRef substrings in memory won't keep the original string in memory.
Only now you are responsible for managing that memory yourself.
And for strengthening those references as required.

So there has to be a better way.
We want to:

 1. Have lots of Strings, without lots of allocations (like SubString/WeakRefString, unlike String)
 2. Not have to worry about mistakenly keeping original huge source string in memory (like WeakRefString/String, unlike SubString)
 3. Not have to worry about managing the memory of the strings ourself (like SubString/String, unlike WeakRefString)
 4. Just outright use less memory. (Unlike any String string type)

Can we do that? Yes we can.

#### InternedString

Every InternedString is a strong reference to a real String.
But unlike normal Strings, if two InternedStrings are content equal, they are reference equal.
That is to say if they look like each other, then they are each other.

When a new InternedStrings is created,
before allocating new memory, we check to see if there already is an InternedString with that content, and if so we just grab a (Strong) reference to that existing String.
This solves point **1.** by reducing allocations, (though not as much as SubStrings, which only have to allocated there pointers and length markers)


You don't have to worry about mistakenly keeping the huge source string in memory, (Like `SubString`)
as they do not have a reference to that huge string, unless they **are** that huge source string.
So that solves point **2.**

On point **3.** you don't have to worry about managing the memory yourself,
because each InternedString is a strong reference to it's content.
Once the last InternedString with that content goes out of scope (and is garbage collected),
removing the copy in the interning pool will be handled automatically (it is a WeakRef, so won't keep it alive).


Finally point **4:**.
As I said before.
The original 10⁸ byte document, with 10⁷ words probably only has about 50,000 (5×10⁴) unique words after cleaning.
(Looking at real world data, the first 10⁷ tokens of wikipedia,
is has 3.5×10⁵ words, but that is before rare words, numbers etc are removed)
At an average of 10 bytes long you only need to be keeping 5×10⁵ bytes of content,
plus for each 8 bytes of pointers/length markers (8×10⁴), plus 1 byte each for null terminating them all. (Grand total: 5.9×10⁵ bytes vs original 10⁸+9 bytes).

Since each `InternedString` is only one point (to the actual String)
you only have 4×10⁷ bytes of pointers (don't need the 4 bytes of length markers).
vs SubString's 8×10⁷ bytes of pointers/length markers,
or individual String's 9×10⁷ bytes of pointers/length markers/null terminating.

These numbers are all pretty rough, I've probably screwed up in a few places.
Point is though, this saves you like an order of magnitude in memory.
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
Also not referentially sane -- magic is required make sure it was workign with serialization etc.

### What is the downside?
There is basically no downside to InternedString vs String.
String is always 1 pointer allocation + content allocation.
InternedString is always 1 pointer allocation + maybe 1 extra pointer and content (if new).
So worse case you end up paying to allocate 1 extra pointer.

There are most downsides vs SubString.
Substring is per token always 1 pointer + 1 length marker allocation,
never more (but you never get to release the content from its parent).
InternedString is as above (chance at 1 pointer only, chance at more if new), but you get the release the content from it's parent.
