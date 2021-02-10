# ErrorTypes.jl

ErrorTypes provide an _easy_ way to efficiently encode error states in return types. Its types are modelled after Rust's `Option` and `Result`.

__Example__

```
using ErrorTypes

function safe_maximum(x::AbstractArray)::Option{eltype(x)}
    isempty(x) && return none # return an Option with a None inside
    return Thing(maximum(x)) # return an Option with a Thing inside
end

function using_safe_maximum(x)
    maybe_val = safe_maximum(x)
    println("Maximum is $(unwrap_or(x, "[ERROR - EMPTY ARRAY]"))")
end
```

See also: Usage [TODO]

__Advantages__

* Zero-cost: In fully type-stable code, error handling using ErrorTypes is as fast as a manual check for the edge case, and significantly faster than exception handling.
* Increased safety: ErrorTypes is designed to not guess. By making edge cases explicit, your code will be more reliable for yourself and for others.

See also: Motivation [TODO]

__Comparisons to other packages__

The idea behind this package is well known and used in other languages, e.g. Rust and the functional languages (Clojure, Haskell etc). It is also implemented in the Julia packages `Expect` and `ResultTypes`, and to some extend `MLStyle`. Compared to these packages, ErrorTypes offer:

* Efficiency: All ErrorTypes methods and types should be maximally efficient. For example, an `Option{T}` is as lightweight as a `Union{T, Nothing}`, and manipulation of the `Option` is as efficient as a `===` check against `nothing`.
* Increased comfort. The main disadvantage of using these packages are the increased development cost. ErrorTypes provides more quality-of-life functionality for working with error types than `Expect` and `ResultTypes`, including the simple `Option` type.
* Flexibility. Whereas `Expect` and `ResultTypes` require your error state to be encoded in an `Exception` object, ErrorTypes allow you to store it how you want. Want to store it as a `Bool`? Sure, why not.
* Strictness: ErrorTypes tries hard to not _guess_ what you're doing. Error types with concrete values cannot be converted to another error type, and non-error types are never implicitly converted to error types. Generally, ErrorTypes tries to not allow room for error.
