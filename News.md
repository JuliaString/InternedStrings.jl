v0.5.0
------
- InternedString type is gone. It deprecates to string but does not cause immediate interning.
- Now it is fully transparent, `intern(::S)::S`.
- Works with all types of input. e.g. Strs.jl Strings
- No longer do operations (regex or otherwise) on interned strings return interned strings, as there is nolonger a type to catch, but it is kinda OK, as it doesn't actually change the number of allocations doing all the interning at the end, just the timing.
- Additional 2.5x speedup on top of v0.4.0


v0.4.0
------
 - Serious performance optimization of the pool lookup. 2-5x speed-up


v0.3.0
-------
 - More operations esp regex on InternedStrings return InternedStrings.

v0.2.0
-----
 - Basic operations like spit, on InternedStrings return InternedStrings.
 - String Macro created


v0.1.0
------
InternedString  type created
It works fully like a String
