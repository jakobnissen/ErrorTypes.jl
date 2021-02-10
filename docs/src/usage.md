# Usage

### Types and how to construct them
__Option{T}__ encodes either the presence of a `T` or the absence of one. You should use this type to encode either the successful creation of `T`, or a failure that does not need any information to explain itself. Like its sibling `Result`, `Option` is a sum type from the package SumTypes - think of it like a facy `Enum`.

An `Option` contains two _variants_, `None` and `Thing`. Like other sum types, you should usually not construct an `Option` directly. Instead, the constructors for the types `None` and `Thing` creates an `Option`, wrapping them - e.g. `None{Int}()` creates an `Option{Int}` containing a `None`. Similarly, you should not construct a `None` or `Thing` directly - these types are only useful as the content of an `Option`.

* You should construct an `Option{T}` wrapping a `Thing` with `Thing(::T)`.
* You _can_ construct an `Option{T}` warpping a `None` object with `None{Int}()`. Normally, however, you should use the object `none` (singleton of `None{Nothing}`) and convert it to an `Option{T}`. See how in the section "Basic usage" below.

__Result{O, E}__ has the two variants `Ok`, representing the successful creation of an `O`, or else an `Err`,, representing some object of type `E`, carrying information about the error state. You should use `Result` instead of `Option` when the error result needs to carry information.

* You _can_ construct `Result` objects by `Ok{O, E}(::O)` or `Err{O, E}(::E)`. However, normally, you should instead use the simpler constructors `Ok(::O)` and `Err(::E)`. These constructors creates `ResultConstructor` objects, which can be converted to the correct `Result` types. See an example below.

### Basic usage
Always typeassert any function that returns an error type. The whole point of ErrorTypes is to encode error states in return types, and be specific about these error states. While ErrorTypes will _technically_ work fine without function annotations, I highly recommend annotating return types:

Do this (note `none` is automatically converted):
```
invert(x::Integer)::Option{Float64} = iszero(x) ? none : Thing(1/x)
```

And not this:
```
invert(x::Integer) = iszero(x) ? None{Float64}() : Thing(1/x)
```

Also, by annotating return functions, you can use the simpler constructors of error types:
* You can use `none`, which is automatically converted to `Option` containing a `None`.
* You can use `Err(x)` and `Ok(x)` to create `ResultConstructor`s, which are converted by the typeassert to the correct `Result`.

### Conversion
Apart from the two special cases above: The conversion of `none` (of type `None`) to `Option`, and `Err(x)` and `Ok(x)` (of type `ResultConstructor`) to `Result`, error types can only convert to each other in certain circumstances. This is intentional, because type conversion is a major source of mistakes.

* An object of type `Option` and `Result` can be converted to its own type.
* An `Option{T}` can be converted to an `Option{T2}`, if `T <: T2`. You intentionally cannot convert e.g. an `Option{Int}` to an `Option{UInt}`.
* A `Result{O, E}` can be converted to a `Result{O2, E2}` if `O <: O2` and `E <: E2`.

It is intentionally NOT possible to e.g. convert a `Result{Int, String}` containing an `Ok` to a `Result{Int, Int}`, even if the `Ok` value contains an `Int` which is allowed in both of the `Result` types. The reason for this is that if it was allowed, whether or not conversions threw errors would depend on the _value_ of an error type, not the type. The idea behind this package is to present edge cases as types, not values.

### @?
If you make an entire codebase of functions returning `Result`s and `Option`s, it can get bothersome to constantly check if function calls contain error values and propagate those error values. To make this process easier, use the macro `@?`, which automatically propagates any error values. If this is applied to some expression `x` evaluating to a `Result` or `Option` containing an error value, the macro will evaluate to something equivalent to `return Err(unwrap_err(x))` or `return none`, respectively. If it contains a result value, the macro is evaluated to the equivalent of `unwrap(x)`.

For example, suppose you want to implement a safe version of the harmonic mean function, which in turn uses a safe version of `div`:

```julia
safe_div(a::Integer, b::Float64)::Option{Float64} = iszero(b) ? none : Thing(a/b)

function harmonic_mean(v::AbstractArray{<:Integer})::Option{Float64}
    sm = 0.0
    for i in v
        invi = safe_div(1, i)
        is_none(invi) && return none
        sm += unwrap(invi)
    end
    res = safe_div(length(v), sm)
    is_none(res) && return none
    return Thing(unwrap(res))
end
```

In this function, we constantly have to check whether `safe_div` returned the error value, and return that from the outer function in that case. That can be more concisely written as:

```julia
function harmonic_mean(v::AbstractArray{<:Integer})::Option{Float64}
    sm = 0.0
    for i in v
        sm += @? safe_div(1, i)
    end
    Thing(@? safe_div(length(v), sm))
end
```

### When to use an error type vs throw an error
The error handling mechanism provided by ErrorTypes is a distinct method from throwing and catching errors. None is superior to the other in all circumstances.

The handling provided by ErrorTypes is faster, safer, and more explicit. For *most* functions, you can use ErrorTypes. However, you can't *only* rely on it. Imagine a function `A` returning `Option{T1}`. `A` is called from function `B`, which can itself fail and returns an `Option{T2}`. However, now there are two distinct error states: Failure in `A` and failure in `B`. So what should `B` return? `Result{O, Enum{E1, E2}}`, for some `Enum` type? But then, what about functions calling `B`? Where does it end?

In general, it's un-idiomatic to "accumulate" error states like this. You should handle an error state when it appears, and usually not return it too far back the call chain.

More importantly, you should distinguish between _recoverable_ and _unrecoverable_ error states. The unrecoverable are unexpected, and reveals that the program went wrong somehow. If the program went somewhere it shouldn't be, it's best to abort the program and show the stack trace, so you can debug it - here, an ordinary exception is better. If the errors are known to be possible beforehand, using ErrorTypes is better. For example, a program may use exceptions when encountering errors when parsing "internal" machine-generated files, which are _supposed_ to be of a certain format, and use error types when parsing user input, which must always be expected to be possibly fallible.

Because error types are so easily converted to exceptions (using `unwrap` and `expect`), internal library functions should preferably use error types.

# Reference

```@autodocs
Modules = [ErrorTypes]
```

