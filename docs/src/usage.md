# Usage

### The Result type
Fundamentally, we have `Result{T, E}`. This type _contains_ either a successful value of type `T` or an error of type `E`.
For example, a function returning either a string or a 32-bit integer error code could return a `Result{String, Int32}`.

You can construct it like this:
```
julia> Result{String, Int}(Ok("Nothing went wrong"))
Result{String, Int64}(Ok("Nothing went wrong"))
```

Thus, a `Result{T, E}` represents _either_ a successful creation of a `T` or an error of type `E`.

#### Option
`Option{T}` is an alias for `Result{T, Nothing}`, and is easier to work with fully specifying the parameters of `Result`s. `Option` is useful when the error state do not need to store any information besides the fact than an error occurred. `Option`s can be conventiently created with two helper functions `some` and `none`:

```
julia> some(1) === Result{typeof(1), Nothing}(Ok(1))
true

julia> none(Int) === Result{Int, Nothing}(Err(nothing))
true
```

If you want an abstractly parameterized `Option`, you can construct it directly like this:

```
julia> Option{Integer}(some(1))
Option{Integer}(some(1))
```

#### ResultConstructor
Internally, `Result{T, E}` contains a field typed `Union{Ok{T}, Err{E}}.`
The types `Ok` and `Err` are not supposed to be instantiated directly (and indeed, cannot be easily instantiated).

Calling `Ok(x)` or `Err(x)` instead creates an instance of the non-exported type `ResultConstructor`:

```
julia> Err(1)
ErrorTypes.ResultConstructor{Int64, Err}(1)

julia> Ok(1)
ErrorTypes.ResultConstructor{Int64, Ok}(1)
```

The only purpose of `ResultConstructor` is to more easily create `Result`s with the correct parameters, and to allow conversions of carefully selected types, read on to learn how.
The user does not need to think much about `ResultConstructor`, but if `ErrorTypes` is abused, this type can show up in the stacktraces.

`none` by itself is a constant for `ErrorTypes.ResultConstructor{Nothing, Err}(nothing)` - we will come back to why this is particularly convenient.

### Basic usage
Always typeassert any function that returns an error type. The whole point of ErrorTypes is to encode error states in return types, and be specific about these error states. While ErrorTypes will _technically_ work fine without function annotations, it makes everything easier, and I highly recommend annotating return types:

Do this:
```
invert(x::Integer)::Option{Float64} = iszero(x) ? none : some(1/x)
```

And not this:
```
invert(x::Integer) = iszero(x) ? none(Float64) : some(1/x)
```

When annotating a function with a return type `T`, the return value gets converted at the end with an explicit `convert(T, return_value)`.

In the function in this example, the function can return `none`, which was a generic instance of `ResultConstructor`.
When that happens, `none` is automatically converted to the correct value, in this case `none(Float64)`.
Similarly, one can also use a typeassert to ease in the construction of `Result` return type:

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

In the above example example, `Ok(Int(length(x))` returns a `ResultConstructor{Int, Ok}`, which can be converted to the target `Result{Int, Base.IteratorSize}`.
Similarly, the `Err(isz)` creates a `ResultConstructor{Base.IteratorSize, Err}`, which can likewise be converted.

In most cases therefore, you never have to constuct an `Option` or `Result` directly. Instead, use a typeassert and return `some(x)` or `none` to return an `Option`, and return `Ok(x)` or `Err(x)` to return a `Result`.

### Conversion rules
Error types can only convert to each other in certain circumstances. This is intentional, because type conversion is a major source of mistakes.

* A `Result{T, E}` can be converted to `Result{T2, E2}` iff `T <: T2` and `E <: E2`, i.e. you can always convert to a "larger" Result type or to its own type.
* A `ResultConstructor{T, Ok}` can be converted to `Result{T2, E}` if `T <: T2`.
* A `ResultConstructor{E, Err}` can be converted to `Result{T, E2}` if `E <: E2`.

The first rule merely state that a `Result` can be converted to another `Result` if both the success parameter (`Ok{T}`) and the error parameter (`Err{E}`) error types are a supertype.
It is intentionally NOT possible to e.g. convert a `Result{Int, String}` containing an `Ok` to a `Result{Int, Int}`, even if the `Ok` value contains an `Int` which is allowed in both of the `Result` types.
The reason for this is that if it was allowed, whether or not conversions threw errors would depend on the _value_ of an error type, not the type.
This type-unstable behaviour would defeat idea behind this package, namely to present edge cases as types, not values.

The next two rules state that `ResultConstructors` have relaxed this requirement, and so a `ResultConstructors` constructed from an `Ok` or `Err` can be converted if only the `Ok{T}` or the `Err{E}` parameter, respectively, is a supertype, not necessarily both parameters.
This is what enables use of `Ok(x)`, `Err(x)` and `none` as return values when the function is annotated with return type.

There is one last type, `ResultConstructor{T, Union{}}`, which is even more flexible in how it converts. This is created by the `@?` macro, discussed next.

### @?
If you make an entire codebase of functions returning `Result`s, it can get bothersome to constantly check if function calls contain error values and propagate those error values to their callers. To make this process easier, use the macro `@?`, which automatically propagates any error values. If this is applied to some expression `x` evaluating to a `Result` containing a success value (i.e. `Ok{T}`), the macro will evaluate to the inner wrapped value:

```
julia> @? Result{String, Int}(Ok("foo"))
"foo"
```

However, if `x` evaluates to an error value `Err{E}`, the macro creates a `ResultConstructor{E, Union{}}`, let's call it `y`, and evaluates to `return y`.
In this manner, the macro means "unwrap the value if possible, and else immediately return it to the outer function".
`ResultConstructor{E, Union{}}` are even more flexible in what they can be converted to:
They can convert to any `Option` type, or any `Result{T, E2}` where `E <: E2`.
This allows you to propagate errors from functions returning `Result` to those returning `Option`.

Let's see it in action. Suppose you want to implement a safe version of the harmonic mean function, which in turn uses a safe version of `div`:

```julia
safe_div(a::Integer, b::Real)::Option{Float64} = iszero(b) ? none : some(a/b)

function harmonic_mean(v::AbstractArray{<:Integer})::Option{Float64}
    sm = 0.0
    for i in v
        invi = safe_div(1, i)
        is_error(invi) && return none
        sm += unwrap(invi)
    end
    res = safe_div(length(v), sm)
    is_error(res) && return none
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

In case any of the calls to `safe_div` yields a `none(Float64)`, the `@?` macro evaluates to code equivalent to `return ResultConstructor{Nothing, Union{}}(nothing)`. This value is then converted by the typeassert in the outer function to `none(Float64)`

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

