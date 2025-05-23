module ErrorTypes

struct Unsafe end
const unsafe = Unsafe()

"""
    Ok{T}

The success state of a `Result{T, E}`, carrying an object of type `T`.
For convenience, `Ok(x)` creates a dummy value that can be converted to the
appropriate `Result type`.

Instances of `Ok` and its mirror image `Err` cannot be directly constructed.

See also: [`Err`](@ref)

```jldoctest
julia> function reciprocal(x::Int)::Result{Float64, String}
           iszero(x) && return Err("Division by zero")
           Ok(1 / x)
       end;

julia> reciprocal(4)
Result{Float64, String}(Ok(0.25))

julia> reciprocal(0)
Result{Float64, String}(Err("Division by zero"))
```
"""
struct Ok{T}
    x::T
    Ok{T}(::Unsafe, x::T) where {T} = new{T}(x)
end

"""
    Err

The error state of a `Result{O, E}`, carrying an object of type `E`.
For convenience, `Err(x)` creates a dummy value that can be converted to the
appropriate `Result type`.

For a more detailed description, see: [`Ok`](@ref)
"""
struct Err{E}
    x::E
    Err{E}(::Unsafe, x::E) where {E} = new{E}(x)
end

"""
    Err(x::T)::ResultConstructor{T, Err}
    Ok(x::T)::ResultConstrutor{T, Ok}
    none::ResultConstructor{Nothing, Err}
    (@? x::Result{T,E}(Err{E}))::ResultConstructor{T, Union{}}

Instances of `ResultConstructor` are temporary values, which are constructed
only to be immediately `convert`ed to `Result`.
Proper use of `ErrorTypes.jl` should not result in `ResultConstructors` leaking
out of functions.

The constructors `Ok` and `Err` return `ResultConstructor`, and the constant
`none` is the `ResultConstructor` for `Option`.

Typical use of `ResultConstructor` is to construct it immediately before
returning it. If the function's return type is annotated to `Result`, the value
will be `converted`.

# Examples:
```jldoctest
julia> sat_sub(x::UInt8)::Result{UInt8, String} = iszero(x) ? Err("Overflow") : Ok(x - 0x01);

julia> sat_sub(0x00)
Result{UInt8, String}(Err("Overflow"))

julia> sat_sub(0x01)
Result{UInt8, String}(Ok(0x00))

julia> sat_sub(x::UInt8)::Option{UInt8} = iszero(x) ? none : Ok(x - 0x01);

julia> sat_sub(0x00)
none(UInt8)

julia> sat_sub(0x01)
some(0x00)
```
"""
struct ResultConstructor{T, K <: Union{Ok, Err}}
    x::T
end

Ok{T}(x::T2) where {T, T2 <: T} = ResultConstructor{T, Ok}(convert(T, x))
Err{T}(x::T2) where {T, T2 <: T} = ResultConstructor{T, Err}(convert(T, x))
Ok(x::T) where {T} = Ok{T}(x)
Err(x::T) where {T} = Err{T}(x)

"""
    Result{O, E}

A sum type of either `Ok{O}` or `Err{E}`. Used as return value of functions that
can error with an informative error object of type `E`.

Results are normally constructed implicitly, through `convert`ing
`ResultConstructor` using `Ok` or `Err`, such as in:

```jldoctest
julia> x::Result{Int, String} = Err("Oh my!");

julia> x
Result{Int64, String}(Err("Oh my!"))
```

See also: [`Option`](@ref), [`Ok`](@ref), [`Err`](@ref)

# Examples
```jldoctest
julia> Result{UInt8, UInt32}(Ok(0x03)) # manual constructor
Result{UInt8, UInt32}(Ok(0x03))

julia> make_err()::Result{Vector{Int}, String} = Err("error!");

julia> make_err()
Result{Vector{Int64}, String}(Err("error!"))

julia> is_error(make_err())
true
```
"""
struct Result{O, E}
    x::Union{Ok{O}, Err{E}}

    # Suppress the unparameterized constuctor
    Result{O, E}(x::Union{Ok{O}, Err{E}}) where {O, E} = new{O, E}(x)
end

function Result{T1, E1}(x::Result{T2, E2}) where {T1, T2 <: T1, E1, E2 <: E1}
    inner = x.x
    return Result{T1, E1}(inner isa Err ? Err(inner.x) : Ok(inner.x))
end

function Base.convert(::Type{Result{T1, E1}}, x::Result{T2, E2}) where {T1, T2 <: T1, E1, E2 <: E1}
    return Result{T1, E1}(x)
end

# Bizarrely, we need this method to avoid recursion when creating a Result
Base.convert(::Type{T}, x::T) where {T <: Result} = x

# Strict supertype accepted
Result{O, E}(x::ResultConstructor{O2, Ok}) where {O, E, O2 <: O} = Result{O, E}(Ok{O}(unsafe, x.x))

# We have <:Err here to also cover ResultConstructor{E2, Union{}} propagated with @?
Result{O, E}(x::ResultConstructor{E2, <:Err}) where {O, E, E2 <: E} = Result{O, E}(Err{E}(unsafe, x.x))

# ResultConstructor propagated with @? can convert to any Option
Result{O, Nothing}(::ResultConstructor{E, Union{}}) where {O, E} = Result{O, Nothing}(Err{Nothing}(unsafe, nothing))
Base.convert(::Type{T}, x::ResultConstructor) where {T <: Result} = T(x)

function Base.show(io::IO, x::Result)
    return print(io, typeof(x), '(', Base.typename(typeof(x.x)).name, '(', repr(x.x.x), "))")
end

"""
    Option{T}

Alias for `Result{T, Nothing}`.
Useful when the error type of a `Result` need not store any information.
Construct value instances with `some(x)` and error instances with `none(::Type)`.

See also: [`Result`](@ref)

# Examples
```jldoctest
julia> some(4) isa Option{Int}
true

julia> is_error(some(4))
false

julia> none(String) isa Option{String} && is_error(none(String))
true
```
"""
const Option{T} = Result{T, Nothing}

"""
	is_error(x::Result)

Check if `x` contains an error value.

See also: [`Result`](@ref), [`Option`](@ref)

# Examples
```jldoctest
julia> is_error(none(Int)), is_error(some(5))
(true, false)
```
"""
is_error(x::Result) = x.x isa Err

Option(x::Result{T, E}) where {T, E} = is_error(x) ? none(T) : Option{T}(x.x)
function Result(x::Option{T}, v::E) where {T, E}
    data = x.x
    return Result{T, E}(data isa Err ? Err(v) : x.x)
end

some(x::T) where {T} = Option{T}(Ok{T}(unsafe, x))

"""
    none

Singleton instance of `ResultConstructor{Nothing, Err}(nothing)`.
This value is useful because it can be `convert`ed to any `Option{T}`,
giving the error value.

See also: [`Option`](@ref)

# Examples
```jldoctest
julia> f(x)::Option{Float64} = iszero(x) ? none : 1 / x;

julia> f(0)
none(Float64)

julia> struct MaybeInt32 x::Option{Int32} end;

julia> MaybeInt32(none)
MaybeInt32(none(Int32))
```
"""
const none = ResultConstructor{Nothing, Err}(nothing)

"""
    none(::Type)::Option{T}

Construct the error value of `Option{T}`.

See also: [`Option`](@ref)

# Examples
```jldoctest
julia> none(String) === Option{String}(Err(nothing))
true

julia> none(Char) isa Option{Char}
true

julia> is_error(none(Char))
true

julia> convert(Option{Vector}, none) === none(Vector)
true
```
"""
none(x::Type{T}) where {T} = Option{T}(Err{Nothing}(unsafe, nothing))

function Base.show(io::IO, x::Option{T}) where {T}
    inner = x.x
    return if inner isa Err
        print(io, "none(", T, ')')
    else
        # If the inner value is exactly T, elide printing it for brevity.
        value = inner.x
        if typeof(value) === T
            print(io, "some(", repr(x.x.x), ')')
        else
            print(io, "Option{", T, "}(some(", repr(x.x.x), "))")
        end
    end
end

"""
    @?(expr)

Propagate a `Result` with `Err` value to the outer function.

Evaluate `expr`, which should return a `Result`. If it contains an `Ok` value `x`,
evaluate to the unwrapped value `x`. Else, evaluates to `return Err(x)`.

# Examples
```jldoctest
julia> (f(x::Option{T})::Option{T}) where T = Ok(@?(x) + one(T));

julia> f(some(1.0)), f(none(Int))
(some(2.0), none(Int64))
```
"""
macro var"?"(expr)
    return quote
        local res = $(esc(expr))
        isa(res, Result) || throw(TypeError(Symbol("@?"), Result, res))
        local data = res.x
        data isa Ok ? data.x : return ResultConstructor{typeof(data.x), Union{}}(data.x)
    end
end

"""
    ok(x::Result{T})::Option{T}

Construct an `Option` from a `Result`, such that the `Ok` variant becomes a `some`,
and the `Err` variant becomes a `none(T)`, discarding the error value if present.

# Examples
```jldoctest
julia> ok(Result{Int32, String}(Err("Some error message")))
none(Int32)

julia> ok(Result{String, Dict}(Ok("Success!")))
some("Success!")

julia> ok(some(5))
some(5)
```
"""
function ok(x::Result{T, E}) where {T, E}
    y = x.x
    return y isa Ok ? some(y.x) : none(T)
end

"""
    is_ok_and(f, x::Result)::Bool

Check if `x` is a result value, and `f(unwrap(x))`.
`f(unwrap(x))` must return a `Bool`.

# Examples
```jldoctest
julia> is_ok_and(isodd, none(Int))
false

julia> is_ok_and(isodd, some(2))
false

julia> is_ok_and(isodd, Result{Int, String}(Ok(9)))
true

julia> is_ok_and(ncodeunits, some("Success!"))
ERROR: TypeError: non-boolean (Int64) used in boolean context
```
"""
function is_ok_and(f, x::Result)::Bool
    y = x.x
    return if y isa Err
        return false
    else
        f(y.x)::Bool
    end
end

macro unwrap_t_or(expr, T, exec)
    return quote
        local res = $(esc(expr))
        isa(res, Result) || throw(TypeError(Symbol("@unwrap_or"), Result, res))
        local data = res.x
        data isa $(esc(T)) ? data.x : $(esc(exec))
    end
end

# Note: jldoctests crashes on this ATM, even if it works correctly.
"""
    @unwrap_or(expr, exec)

Evaluate `expr` to a `Result`. If `expr` is a error value, evaluate
`exec` and return that. Else, return the wrapped value in `expr`.

See also: [`@unwrap_error_or`](@ref)

# Examples
```julia
julia> safe_inv(x)::Option{Float64} = iszero(x) ? none : Ok(1/x);

julia> function skip_inv_sum(it)
    sum = 0.0
    for i in it
        sum += @unwrap_or safe_inv(i) continue
    end
    sum
end;

julia> skip_inv_sum([2,1,0,1,2])
3.0
```
"""
macro unwrap_or(expr, exec)
    return :(@unwrap_t_or $(esc(expr)) Ok $(esc(exec)))
end

"""
    @unwrap_error_or(expr, exec)

Evaluate `expr` to a `Result`. If `expr` is a result value, evaluate
`exec` and return that. Else, return the wrapped error value in `expr`.

See also: [`@unwrap_or`](@ref)
```
"""
macro unwrap_error_or(expr, exec)
    return :(@unwrap_t_or $(esc(expr)) Err $(esc(exec)))
end

@noinline throw_unwrap_err() = error("unwrap on unexpected type")

"""
    unwrap(x::Result)

If `x` is of the associated error type, throw an error. Else, return the contained
result type.

See also: [`unwrap_error`](@ref), [`@unwrap_or`](@ref)

# Examples
```jldoctest
julia> unwrap(some(Any[]))
Any[]

julia> unwrap(none(Int))
ERROR: unwrap on unexpected type
[...]

julia> unwrap(Result{String, Int32}(Ok("Lin Wei")))
"Lin Wei"
```
"""
unwrap(x::Result) = @unwrap_or x throw_unwrap_err()

"""
    unwrap_error(x::Result)

If `x` contains an `Err`, return the content of the `Err`. Else, throw an error.

See also: [`unwrap`](@ref), [`expect_error`](@ref)

# Examples
```jldoctest
julia> unwrap_error(some(3))
ERROR: unwrap on unexpected type
[...]

julia> unwrap_error(none(String)) === nothing
true

julia> unwrap_error(Result{Int, String}(Err("some error")))
"some error"
```
"""
unwrap_error(x::Result) = @unwrap_error_or x throw_unwrap_err()

"""
    expect(x::Result, s::AbstractString)

If `x` is of the associated error type, error with message `s`. Else, return
the contained result type.

See also: [`expect_error`](@ref), [`unwrap`](@ref)

# Examples
```jldoctest
julia> expect(some('x'), "cannot be none") === 'x'
true

julia> expect(Result{Int, String}(Ok(19)), "Expected an integer")
19
```
"""
expect(x::Result, s::AbstractString) = @unwrap_or x error(s)

"""
    expect_error(x::Result, s::AbstractString)

If `x` contains an `Err`, return the content of the `Err`. Else, throw an error
with message `s`.

See also: [`unwrap_error`](@ref), [`expect`](@ref)

# Examples
```jldoctest
julia> expect_error(none(Int), "expected none") === nothing
true

julia> expect_error(Result{Vector, String}(Err("Mistake!")), "must be error")
"Mistake!"

julia> expect_error(some(3), "must be none")
ERROR: must be none
[...]
```
"""
expect_error(x::Result, s::AbstractString) = @unwrap_error_or x error(s)

"""
    and_then(f, ::Type{T}, x::Result{O, E})::Result{T, E}

If `is` a result value, return `Result{T, E}(Ok(f(unwrap(x))))`,
else return the error value. Always returns a `Result{T, E}`.

__WARNING__
If `f(unwrap(x))` is not a `T`, this functions throws an error.

# Examples
```jldoctest
julia> and_then(join, String, some(["ab", "cd"]))
some("abcd")

julia> and_then(i -> Int32(ncodeunits(join(i))), Int32, none(Vector{String}))
none(Int32)
```
"""
function and_then(f, ::Type{T}, x::Result{O, E})::Result{T, E} where {T, O, E}
    data = x.x
    return Result{T, E}(data isa Ok ? Ok(f(data.x)) : Err(data.x))
end

"""
    map_or(f, x::Result, v)

If `x` is a result value, return `f(unwrap(x))`. Else, return `v`.

See also: [`unwrap_or`](@ref), [`and_then`](@ref)

# Examples
```jldoctest
julia> map_or(isodd, some(9), nothing)
true

julia> map_or(isodd, none(Int), nothing) === nothing
true

julia> map_or(ncodeunits, none(String), 0)
0
```
"""
map_or(f, x::Result{O, E}, v) where {O, E} = f(@unwrap_or x return v)

"""
    unwrap_or(x::Result, v)

If `x` is an error value, return `v`. Else, unwrap `x` and return its content.

See also: [`unwrap`](@ref), [`@unwrap_or`](@ref)

# Examples:
```jldoctest
julia> unwrap_or(some(5), 9)
5

julia> unwrap_or(none(Float32), "something else")
"something else"

julia> unwrap_or(Result{Int8, Vector}(Err([])), 0x01)
0x01
```
"""
unwrap_or(x::Result, v) = @unwrap_or x v

"""
    unwrap_or_else(f, x::Result)

If `x` is an error value, return `f(unwrap_error(x))`. Else, unwrap `x` and return its content.

See also: [`unwrap_error_or_else`](@ref), [`unwrap_or`](@ref)

# Examples
```jldoctest
julia> unwrap_or_else(isnothing, some(3))
3

julia> unwrap_or_else(println, none(Int))
nothing

julia> unwrap_or_else(ncodeunits, Result{Int, String}(Err("my_error")))
8
```
"""
function unwrap_or_else(f, x::Result)
    y = x.x
    return y isa Ok ? y.x : f(y.x)
end

"""
    unwrap_error_or(x::Result, v)

Like `unwrap_or`, but unwraps an error.

See also: [`unwrap_or`](@ref)

# Examples
```jldoctest
julia> unwrap_error_or(Result{Int, String}(Err("abc")), 19)
"abc"

julia> unwrap_error_or(none(String), "error") === nothing
true

julia> unwrap_error_or(some([1, 2, 3]), Int32[])
Int32[]
```
"""
unwrap_error_or(x::Result, v) = @unwrap_error_or x v

"""
    unwrap_error_or(f, x::Result

Returns the wrapped error value if `x` is an error, else return `f(unwrap(x))`.
    
See also: [`@unwrap_error_or`](@ref), [`unwrap_or_else`](@ref)

# Examples
```jldoctest
julia> unwrap_error_or_else(ncodeunits, some("abc"))
3

julia> unwrap_error_or_else(ncodeunits, none(String)) === nothing
true

julia> unwrap_error_or_else(n -> n + 1, Result{Int, String}(Err("abc")))
"abc"
```
"""
function unwrap_error_or_else(f, x::Result)
    y = x.x
    return y isa Err ? y.x : f(y.x)
end

"""
    flatten(x::Option{Option{T}})

Convert an `Option{Option{T}}` to an `Option{T}`.

# Examples
```jldoctest
julia> flatten(some(some("x")))
some("x")

julia> flatten(some(none(Float32)))
none(Float32)
```
"""
flatten(x::Option{Option{T}}) where {T} = unwrap_or(x, none(T))

"""
    base(x::Option{T})

Convert an `Option{T}` to a `Union{Some{T}, Nothing}`.

See also: [`Option`](@ref)

# Examples
```jldoctest
julia> sub_nonneg(x::Int)::Option{Int} = x < 1 ? none : some(x - 1);

julia> base(sub_nonneg(-3)) === nothing
true

julia> base(sub_nonneg(2))
Some(1)
```
"""
base(x::Option{T}) where {T} = Some(@unwrap_or x (return nothing))

"""
    iter(x::Option)::OptionIterator

Produce an iterator over `x`, which yields the result value of `x` if `x` is some,
or an empty iterator if it is none.

# Examples
```jldoctest
julia> first(iter(some(19)))
19

julia> collect(iter(some("some string")))
1-element Vector{String}:
 "some string"

julia> isempty(iter(none(Dict)))
true

julia> collect(iter(none(Char)))
Char[]
```
"""
iter(x::Option) = OptionIterator(x)

struct OptionIterator{T}
    x::Option{T}
end

Base.eltype(::Type{OptionIterator{T}}) where {T} = T
Base.length(x::OptionIterator) = Int(!is_error(x.x))

function Base.iterate(x::OptionIterator)
    content = @unwrap_or x.x return nothing
    return (content, nothing)
end

Base.iterate(::OptionIterator, ::Nothing) = nothing

export Ok,
    Err,
    Result,
    Option,
    is_error,
    is_ok_and,
    some,
    none,
    ok,
    unwrap,
    unwrap_error,
    expect,
    expect_error,
    and_then,
    unwrap_or,
    unwrap_or_else,
    map_or,
    unwrap_error_or,
    unwrap_error_or_else,
    flatten,
    iter,
    base,
    @?,
    @unwrap_or,
    @unwrap_error_or

end
