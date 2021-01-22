# ErrorTypes

ErrorTypes is a simple implementation of Rust-like error handling in Julia. Its goal is to increase safety of Julia code internally in packages by providing easy-to-use, zero-cost handling for recoverable errors.

## Motivation
You're building an important package that includes some text processing. At some point, you need a function that gets the length of the first word (in bytes) of some text. So, you write up the following:

```julia
function first_word_bytes(s::Union{String, SubString{String}})
    findfirst(isspace, lstrip(s)) - 1
end
```
Nice - easy, fast, flexible, relatively generic. You also write a couple of tests to handle the edge cases:

```julia
@test first_word_bytes("Lorem ipsum") == 5
@test first_word_bytes(" dolor sit amet") == 5 # leading whitespace
@test first_word_bytes("Rødgrød med fløde") == 9 # Unicode
```
All tests pass, and you push to production. But oh no! Your code has a horrible bug that causes your production server to crash! See, you forgot an edge case:

```julia
julia> first_word_bytes("boo!")
ERROR: MethodError: no method matching -(::Nothing, ::Int64)
```

The infuriating part is that the Julia compiler is in on the plot against you: It *knew* that `findfirst` returned a `Union{Int, Nothing}`, not an `Int` as you assumed it did. It just decided to not share that information, leading you into a hidden trap.

With this package, that worry is no more. You can specify the return type of any function that can possibly fail, so that it becomes a `Result` (or an `Option`):

```julia
using ErrorTypes

function safer_findfirst(f, x)::Option{eltype(keys(x))}
    for (k, v) in pairs(x)
        f(v) && return Thing(k) # thing: value
    end
    none # none: absence of value
end
```

Now, if you forget that `safer_findfirst` can error, and mistakenly assume that it always return an `Int`, *none* of your tests will pass, and you will catch the bug immediately instead of in production.

Notably, in fully type-stable code, using `ErrorTypes` in this manner carries precisely zero run-time performance penalty.

## Usage

When making a function safer, you should __always__ explicitly type assert its return value as either `Result{O, E}` or `Option{T}`, with all parameters specified.
Functions that can error, but whose error state does not need to carry information may be marked with `Option{T}`. A successful result `x` of type `T` should be returned as `Thing(x)`, and an unsuccessful attempt should be returned as `none`. `none` is the singleton instance of `None{T}`, and is used as a stand-in for all values of `None{T}` for all T.

```julia
function safe_trunc(::Type{UInt8}, x::UInt)::Option{UInt8}
    x > 255 && return none
    return Thing(x % UInt8)
end
```

Functions that can error, and whose error must carry some information should instead use `Result{O, E}`. The `Ok` state is of type `O`, and the `Err` state of type `E`. A successful return value should return `Ok(x)`, an unsuccessful should return `Err(x)`. By itself, `Ok(x)` and `Err(x)` will return a dummy value that is converted to the correct type due to the typeassert.

```julia
function safe_trunc(::Type{UInt8}, x::Int)::Result{UInt8, InexactError}
    if (x > 255) | (x < 0)
        return Err(InexactError(:safe_trunc, UInt8, x))
    end
    return Ok(x % UInt8)
end
```

### Methods with Option and Result
The "error value" of an `Option{T}` and a `Result{O, E}` is a `None{T}` and `Err{O, E}(::E)`, respectively. The "result value" is a `Thing{T}(::T)` and a `Ok{O, E}(::O)`.

__Both__
* `unwrap(x::Union{Option, Result}`: throws an error if `x` contains an error value. Else, return the result value.
* `expect(x::Union{Option, Result}, s::AbstractString)`: same as `unwrap`, but errors with the custom string `s`.


__Option__
* `is_none(x::Option)`: Returns whether `x` contains a `None`.
* `unwrap_none(x::Option)`: Errors if the `Option` contains a result value, else returns `nothing`
* `expect_none(x::Option, s::AbstractString)` same as `unwrap_none`, but errors with the custom string `s`.

__Result__
* `is_error(x::Result)`: Returns whether `x` contains an error value.

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

### Notes

Note that this package does not protect YOUR code from using unsafe functions, it protects everyone else relying on your code. For example:

```julia
unsafe_func(x::Int) = x == 1 ? nothing : (x == 4 ? missing : x + 1)

function still_unsafe(x::Int)::Option{Int}
    y = unsafe_func(x^2)
    y === nothing ? none : Thing(y)
end
```

Here, you've forgotten the egde case `unsafe_func(4)`, so `still_unsafe` will error in that case. To correctly "contain" the unsafety of `unsafe_func`, you need to cover all three return types: `Int`, `Nothing` and `Missing`:

```julia
function safe_func(x::Int)::Result{Int, Union{Missing, Nothing}}
    y = unsafe_func(x^2)
    y === nothing && return Err(nothing)
    y === missing && return Err(missing)
    Ok(y)
end
```
