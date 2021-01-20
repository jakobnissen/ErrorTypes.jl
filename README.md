# ErrorTypes

ErrorTypes is a simple implementation of Rust-like error handling in Julia. Its goal is to increase safety of Julia code internally in packages by providing easy-to-use, zero-cost handling for recoverable errors.

## Motivation
You're building an important pacakge that includes some text processing. At some point, you need a function that gets the length of the first word (in bytes) of some text. So, you write up the following:

```julia
function first_word_bytes(s::Union{String, SubString{String}})
    findfirst(isspace, lstrip(s)) - 1
end
```
Nice - easy, fast, flexible, relatively generic. You also write a couple of tests to handle the edge cases:

```julia
@test first_word_bytes("Lorem ipsum") == 5
@test first_word_bytes(" dolor sit amet") == 4 # leading whitespace
@test first_word_bytes("Rødgrød med fløde") == 9 # unicode
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
        f(v) && return Some(k)
    end
    nothing
end
```

Now, if you forget that `safer_findfirst` can error, and mistakenly assume that it always return an `Int`, *none* of your tests will pass, and you will catch the bug immediately instead of in production.

Notably, in fully type-stable code, using `ErrorTypes` in this manner carries precisely zero run-time performance penalty.

## Usage
The main type is a `Result{R, E}`. This wraps a value of *either* an expected "result" type `R` *or* an "error" type `E`, but not both. For example, constructing an `Result{Integer, Int}` throws a (compile time inferred) error, since `1` would be both an `R` and an `E`.

This package allows objects of type `R` or `E` to be `convert`'ed to `Result{R, E}`. The following functions can be used on a `Result`:

* `extract(x::Result)` returns the `Union{R,E}` content of the `Result`.
* `is_error(x::Result)` returns `true` if `x` wraps a value of type `E`, `false` otherwise.
* `expect(x::Result, message::AbstractString)` throws an error with message `message` if `x` contains an error type, else extracts `x`.
* `unwrap(x::Result)` is like `expect`, but uses a default error message.

The package also contains the type `Option{T}`. This is an alias for `Result{Some{T}, Nothing}`, but has specialized methods to make it simpler to work with. This should be used for functions that can either return a `T`, or not, like the `safer_findfirst` function in the example above. `Option`, being a subtype of `Result`, has all its methods. However, it's "result" type is considered to be `T`, *not* `Some{T}`, i.e. `extract`'ing an `Option{T}` returns a `Union{T, Nothing}`, *not* a `Union{Some{T}, Nothing}`. Similarly, `expect`'ing and `unwrap`'ing etc. an `Option{T}` returns a `T`.

`Option{T}` also have extra methods and associated functions:

* `some(x)` retuns a `Option{Some{typeof(x)}}(Some(x))`, i.e. it's an `Option` with the value `x` present.
* `none(T)` returns a `Option{Some{T}}(nothing)`, i.e. an `Option` with the absence of a `T`.
* `expect_nothing(x::Option, message::AbstractString)` throws an error with message `message` if `x` contains a value, otherwise returns `nothing`.
* `unwrap_nothing(x::Option)` is similar to `expect_nothing`, but throws a default error message.

The easiest way to use this package is to annotate the function as returning `Result` or `Option`:
```julia
safe_div(num::Integer, den::Integer)::Option{Float64} = iszero(den) ? nothing : Some(num / den)
```

Note that this package does not protect YOUR code from using unsafe functions, it protects everyone else relying on your code. For example:

```julia
unsafe_func(x::Int) = x == 1 ? nothing : (x == 4 ? missing : x + 1)
function still_unsafe(x::Int)::Option{Int}
    y = unsafe_func(x^2)
    y === nothing ? nothing : Some(y)
end
```

Here, you've forgotten the egde case `unsafe_func(4)`, so `still_unsafe` will error in that case. To correctly "contain" the unsafety of `unsafe_func`, you need to cover all three return types: `Int`, `Nothing` and `Missing`:

```julia
safe_func(x::Int)::Result{Int, Union{Missing, Nothing}} = unsafe_func(x^2)
```
