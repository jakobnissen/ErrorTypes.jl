# Usage

### The Result type
__Result{O, E}__ is a struct containing exactly one of two so-called _variants_, `Ok` and `Err`. `Result` is a sum type from the package SumTypes - think of it like a parametric `Enum` with two instances of types `O` and `E`.

Like other sum types, you should usually not construct a `Result` directly - indeed, `Result` have no direct constructors. Instead, the constructors for the types `Ok` and `Err` creates a `Result`, wrapping them - e.g. `Ok{Int, String}(1)` creates a `Result{Int, String}` containing `Ok{Int, String}(1)`. Similarly, you should not construct an `Ok` or `Err` directly - these types are only useful as the content of an `Result`.

The purpose of `Result{O, E}` is to represent either a _success value_ of type `O`, or an _error value_ of type `E`. For example, a function returning either a string or a 32-bit integer error code could return a `Result{String, Int32}`.

The un-paramterized constructors `Ok(x)` and `Err(x)` creates special `ResultConstructor` instances. This type is useful only to be converted to `Result` - you will see in a bit how this is convenient.

The type `Option{T}` is an alias for `Result{T, Nothing}`. This type has more convenience methods than other `Result` types, and should be used when the error state does not need to carry any information. There is no functional difference between using `Option{T}` and `Result{T, Nothing}` - it's the same type, `Option` is just more convenient.

`none(T)` is a shortcut for `Err{T, Nothing}(nothing)`, e.g. it creates an `Option{T}` with an error value. `none` by itself is a shorthand for `Err(nothing)` - a `ResultConstructor`. Similarly, `some(x::T)` is short for `Ok{T, Nothing}(x)`, i.e. an easy constructor for the result value of `Option{T}`.

### Basic usage
Always typeassert any function that returns an error type. The whole point of ErrorTypes is to encode error states in return types, and be specific about these error states. While ErrorTypes will _technically_ work fine without function annotations, I highly recommend annotating return types:

Do this:
```
invert(x::Integer)::Option{Float64} = iszero(x) ? none : some(1/x)
```

And not this:
```
invert(x::Integer) = iszero(x) ? none(Float64) : some(1/x)
```

Note in the first example that `none`, which is an instance of `ResultConstructor`, is automatically converted to the correct type by the type assert. By annotating return functions, you can this use the simpler constructors of error types:
* You can use `none`, which is automatically converted to `Option` containing an `Err`.
* You can use `Err(x)` and `Ok(x)` to create `ResultConstructor`s, which are converted by the typeassert to the correct `Result`.

Here is an example where `Ok` and `Err` is used to make `ResultConstructor`s, which are then converted to `Result` by the typeassert:

```
function get_length(x)::Result{Int, Base.IteratorSize}
    isz = Base.IteratorSize(x)
    if isa(isz, Base.HasShape) || isa(isz, Base.HasLength)
        return Ok(Int(length(x)))
    else
        return Err(isz)
    end
end
```

### Conversion
Apart from the two special cases above: The conversion of `none` to `Option`, and `Err(x)` and `Ok(x)` (of type `ResultConstructor`) to `Result`, error types can only convert to each other in certain circumstances. This is intentional, because type conversion is a major source of mistakes.

* An object of type `Option` and `Result` can be converted to its own type, i.e. `convert(T, ::T)` works.
* A `Result{O, E}` can be converted to a `Result{O2, E2}` if `O <: O2` and `E <: E2`.

It is intentionally NOT possible to e.g. convert a `Result{Int, String}` containing an `Ok` to a `Result{Int, Int}`, even if the `Ok` value contains an `Int` which is allowed in both of the `Result` types. The reason for this is that if it was allowed, whether or not conversions threw errors would depend on the _value_ of an error type, not the type. This type-unstable behaviour would defeat idea behind this package, namely to present edge cases as types, not values.

### @?
If you make an entire codebase of functions returning `Result`s, it can get bothersome to constantly check if function calls contain error values and propagate those error values. To make this process easier, use the macro `@?`, which automatically propagates any error values. If this is applied to some expression `x` evaluating to a `Result` containing an error value, the macro will evaluate to something equivalent to `return Err(unwrap_err(x))`. If it contains a result value, the macro is evaluated to the equivalent of `unwrap(x)`.

For example, suppose you want to implement a safe version of the harmonic mean function, which in turn uses a safe version of `div`:

```julia
safe_div(a::Integer, b::Real)::Option{Float64} = iszero(b) ? none : some(a/b)

function harmonic_mean(v::AbstractArray{<:Integer})::Option{Float64}
    sm = 0.0
    for i in v
        invi = safe_div(1, i)
        is_none(invi) && return none
        sm += unwrap(invi)
    end
    res = safe_div(length(v), sm)
    is_none(res) && return none
    return some(unwrap(res))
end
```

In this function, we constantly have to check whether `safe_div` returned the error value, and return that from the outer function in that case. That can be more concisely written as:

```julia
function harmonic_mean(v::AbstractArray{<:Integer})::Option{Float64}
    sm = 0.0
    for i in v
        sm += @? safe_div(1, i)
    end
    some(@? safe_div(length(v), sm))
end
```

### When to use an error type vs throw an error
The error handling mechanism provided by ErrorTypes is a distinct method from throwing and catching errors. None is superior to the other in all circumstances.

The handling provided by ErrorTypes is faster, safer, and more explicit. For *most* functions, you can use ErrorTypes. However, you can't *only* rely on it. Imagine a function `A` returning `Option{T1}`. `A` is called from function `B`, which can itself fail and returns an `Option{T2}`. However, now there are two distinct error states: Failure in `A` and failure in `B`. So what should `B` return? `Result{T2, Enum{E1, E2}}`, for some `Enum` type? But then, what about functions calling `B`? Where does it end?

In general, it's un-idiomatic to "accumulate" error states like this. You should handle an error state when it appears, and usually not return it far back the call chain.

More importantly, you should distinguish between _recoverable_ and _unrecoverable_ error states. The unrecoverable are unexpected, and reveals that the program went wrong somehow. If the program went somewhere it shouldn't be, it's best to abort the program and show the stack trace, so you can debug it - here, an ordinary exception is better. If the errors are known to be possible beforehand, using ErrorTypes is better. For example, a program may use exceptions when encountering errors when parsing "internal" machine-generated files, which are _supposed_ to be of a certain format, and use error types when parsing user input, which must always be expected to be possibly fallible.

Because error types are so easily converted to exceptions (using `unwrap` and `expect`), internal library functions should preferably use error types.

# Reference

```@autodocs
Modules = [ErrorTypes]
```

