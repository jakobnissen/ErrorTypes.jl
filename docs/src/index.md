# ErrorTypes.jl

ErrorTypes provides an _easy_ way to efficiently encode error states in return types. Its types are modelled after Rust's `Option` and `Result`.

__Example__

```
using ErrorTypes

function safe_maximum(x::AbstractArray)::Option{eltype(x)}
    isempty(x) ? none : some(maximum(x))
end

function using_safe_maximum(x)
    maybe = safe_maximum(x)
    println(unwrap_or(and_then(y -> "Maximum is: $y", String, maybe), "ERROR: EMPTY ARRAY"))
end
```

See also: [Usage](@ref)

__Advantages__

* Zero-cost: In fully type-stable code, error handling using ErrorTypes is as fast as a manual check for the edge case, and significantly faster than exception handling.
* Increased safety: ErrorTypes is designed to make you not guess. By making edge cases explicit, your code will be more reliable for yourself and for others.

See also: [Why use ErrorTypes?](@ref)

__Comparisons to other packages__

The idea behind this package is well known and used in other languages, e.g. Rust and the functional languages (Clojure, Haskell etc). It is also implemented in the Julia packages `Expect` and `ResultTypes`, and to some extent `MLStyle`. Compared to these packages, ErrorTypes offer:

* Efficiency: All ErrorTypes methods and types should be maximally efficient. For example, an `Option{T}` is as lightweight as a `Union{T, Nothing}`, and manipulation of the `Option` is as efficient as a `===` check against `nothing`.
* Increased comfort. The main disadvantage of using these packages is the increased friction in development. ErrorTypes provides more quality-of-life functionality for working with error types than `Expect` and `ResultTypes`, for example the simple `Option` type.
* Flexibility. Whereas `Expect` and `ResultTypes` require your error state to be encoded in an `Exception` object, ErrorTypes allow you to store it how you want. Want to store error codes as a `Bool`? Sure, why not.
* Strictness: ErrorTypes tries hard to not _guess_ what you're doing. Error types with concrete values cannot be converted to another concrete error type, and non-error types are never implicitly converted to error types. Generally, ErrorTypes tries to minimize room for error.

