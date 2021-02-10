# Usage

### Types and how to construct them.
__Option{T}__ encodes either the presence of a `T` or the absence of one. You should use this type to encode either the successful creation of `T`, or a failure that does not need any information to explain itself. Like its sibling `Result`, `Option` is a sum type from the pacage SumTypes. 

An `Option` contains two _variants_, `None` and `Thing`. Like other sum types, you should usually not construct an `Option` directly. Instead, the constructors `None` and `Thing` creates an `Option` wrapping them.

* You should construct an `Option{T}` wrapping a `Thing` with `Thing(::T)`.
* You _can_ `None` objects directly e.g. `ErrorTypes.None{Int}()`, although `None` is not exported. Normally, however, the object `none` (singleton of `None{Nothing}`) is convertible to any `Option{T}`. See below in the section "basic usage".

__Result{O, E}__ has the two variants `Ok`, representing the successful creation of an `O`, or else an `E`, representing some object carrying information about the error. You should use `Result` instead of `Option` when the error needs to be explained.

* You _can_ construct `Result` objects by `Ok{O, E}(::O)` or `Err{O, E}(::Err)`. However, normally, you can instead use the simpler constructors `Ok(::O)` and `Err(::E)`. These constructors creates `ResultConstructor` objects, which can be converted to the correct `Result` types.

### Basic usage:
Always typeassert any function that returns an error type. The whole point of ErrorTypes is to encode error states in return types, and be specific about these error states. While ErrorTypes will _technically_ work fine without function annotation, I highly recommend annotating return types:

Yes:
```
invert(x::Integer)::Option{Float64} = iszero(x) ? none : Thing(1/x)
```

No:
```
invert(x::Integer) = iszero(x) ? none : Thing(1/x)
```

Also, by annotating return functions, you use the simpler constructors of error types:
* You can use `none`, which is automatically converted to `Option` containing a `None`.
* You can use `Err(x)` and `Ok(x)` to create `ResultConstructor`s, which are converted by the typeassert to the correct `Result`.

### Conversion
Apart from the two special cases above: The conversion of `none` (of type `None`) to `Option`, and `Err(x)` and `Ok(x)` (of type `ResultConstructor`) to `Result`, error types can only convert to each other in certain circumstances. This is intentional, because type conversions is a major source of mistakes.

* An object of type `Option` and `Result` can be converted to its own type.
* An `Option{T}` containing a `Thing` can be converted to an `Option{T2}`, if `T <: T2`. You intentionally cannot convert e.g. an `Option{Int}` to an `Option{UInt}`.
* An `Option` containing a `None` can be converted to any other `Option`. This is to allow easy "propagation" of error values (see the `@?` macro).
* A `Result{O, E}` containing an `Ok` can be converted to a `Result{O2, E2}` if `O <: O2`. Similarly, if it contains an `Err`, it can be converted if `E <: E2`. 

### @?
If you make an entire codebase of functions returning `Result`s and `Options`, it can get bothersome to constantly check if function calls contain error values and propagate those error values. To make this process easier, use the macro `@?`, which automatically propagates any error values. If this is applied to some expression `x` evaluating to a `Result` or `Option` containing an error value, this returns the error value. If it contains a result value, the macro is evaluated to the content of the result value.

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

# Reference

```@autodocs
Modules = [ErrorTypes]
```
