using InternedStrings


@time include("corefunctionality.jl")
@time include("corefunctionality.jl")

#==
# v0.4.0
>  17.880453 seconds (15.97 M allocations: 895.803 MiB, 25.37% gc time)
>  12.293750 seconds (12.30 M allocations: 707.467 MiB, 36.30% gc time)

# v0.4.0+ seperate convert
> 16.724464 seconds (15.51 M allocations: 871.196 MiB, 27.44% gc time)
> 13.172371 seconds (12.63 M allocations: 724.610 MiB, 35.13% gc time)

# v0.5.0- 
> 6.503763 seconds (2.17 M allocations: 603.847 MiB, 50.20% gc time)
> 4.745838 seconds (663.51 k allocations: 529.511 MiB, 68.21% gc time)
==#
