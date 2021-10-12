module ErrorTypes

struct Unsafe end
const unsafe = Unsafe()

"""
    Ok{T}

The success state of a `Result{T, E}`, carrying an object of type `T`.
For convenience, `Ok(x)` creates a dummy value that can be converted to the
appropriate `Result type`.
"""
struct Ok{T}
    x::T
    Ok{T}(::Unsafe, x::T) where T = new{T}(x)
end

"""
    Err

The error state of a `Result{O, E}`, carrying an object of type `E`.
For convenience, `Err(x)` creates a dummy value that can be converted to the
appropriate `Result type`.
"""
struct Err{E}
    x::E
    Err{E}(::Unsafe, x::E) where E = new{E}(x)
end

struct ResultConstructor{T, K <: Union{Ok, Err}}
    x::T
end

Ok{T}(x::T2) where {T, T2 <: T} = ResultConstructor{T, Ok}(convert(T, x))
Err{T}(x::T2) where {T, T2 <: T} = ResultConstructor{T, Err}(convert(T, x))
Ok(x::T) where T = Ok{T}(x)
Err(x::T) where T = Err{T}(x)

"""
    Result{O, E}

A sum type of either `Ok{O}` or `Err{E}`. Used as return value of functions that
can error with an informative error object of type `E`.
"""
struct Result{O, E}
    x::Union{Ok{O}, Err{E}}
end

function Result{T1, E1}(x::Result{T2, E2}) where {T1, T2 <: T1, E1, E2 <: E1}
    inner = x.x
    return Result{T1, E1}(inner isa Err ? Err(inner.x) : Ok(inner.x))
end

function Base.convert(::Type{Result{T1, E1}}, x::Result{T2, E2}) where {T1, T2 <: T1, E1, E2 <: E1}
    Result{T1, E1}(x)
end

# Bizarrely, we need this method to avoid recursion when creating a Result
Base.convert(::Type{T}, x::T) where {T <: Result} = x

# Strict supertype accepted
Result{O, E}(x::ResultConstructor{O2, Ok}) where {O, E, O2 <: O} = Result{O, E}(Ok{O}(unsafe, x.x))

# We have <:Err here to also cover ResultConstructor{E2, Union{}} propagated with @?
Result{O, E}(x::ResultConstructor{E2, <:Err}) where {O, E, E2 <: E} = Result{O, E}(Err{E}(unsafe, x.x))

# ResultConstructor propagated with @? can convert to any Option
Result{O, Nothing}(x::ResultConstructor{E, Union{}}) where {O, E} = Result{O, Nothing}(Err{Nothing}(unsafe, nothing))
Base.convert(::Type{T}, x::ResultConstructor) where {T <: Result} = T(x)

function Base.show(io::IO, x::Result)
    print(io, typeof(x), '(', Base.typename(typeof(x.x)).name, '(', repr(x.x.x), "))")
end

"""
    Option{T}

Alias for `Result{T, Nothing}`
"""
const Option{T} = Result{T, Nothing}

"""
	is_error(x::Result)

Check if `x` contains an error value.

# Example

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

some(x::T) where T = Option{T}(Ok{T}(unsafe, x))

const none = ResultConstructor{Nothing, Err}(nothing)
none(x::Type{T}) where T = Option{T}(Err{Nothing}(unsafe, nothing))

function Base.show(io::IO, x::Option{T}) where T
    inner = x.x
    if inner isa Err
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

# Example

```jldoctest
julia> (f(x::Option{T})::Option{T}) where T = Ok(@?(x) + one(T));

julia> f(some(1.0)), f(none(Int))
(some(2.0), none(Int64))
```
"""
macro var"?"(expr)
    quote
        local res = $(esc(expr))
        isa(res, Result) || throw(TypeError(Symbol("@?"), Result, res))
        local data = res.x
        data isa Ok ? data.x : return ResultConstructor{typeof(data.x), Union{}}(data.x)
    end
end

macro unwrap_t_or(expr, T, exec)
    quote
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

# Examples

```
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

Same as `@unwrap_or`, but unwraps errors.
"""
macro unwrap_error_or(expr, exec)
    return :(@unwrap_t_or $(esc(expr)) Err $(esc(exec)))
end

@noinline throw_unwrap_err() = error("unwrap on unexpected type")

"""
    unwrap(x::Result)

If `x` is of the associated error type, throw an error. Else, return the contained
result type.
"""
unwrap(x::Result) = @unwrap_or x throw_unwrap_err()

"""
    unwrap_error(x::Result)

If `x` contains an `Err`, return the content of the `Err`. Else, throw an error.
"""
unwrap_error(x::Result) = @unwrap_error_or x throw_unwrap_err()

"""
    expect(x::Result, s::AbstractString)

If `x` is of the associated error type, error with message `s`. Else, return
the contained result type.
"""
expect(x::Result, s::AbstractString) = @unwrap_or x error(s)

"""
    expect_error(x::Result, s::AbstractString)

If `x` contains an `Err`, return the content of the `Err`. Else, throw an error
with message `s`.
"""
expect_error(x::Result, s::AbstractString) = @unwrap_error_or x error(s)

"""
    and_then(f, ::Type{T}, x::Result{O, E})

If `is` a result value, apply `f` to `unwrap(x)`, else return the error value. Always returns a `Result{T, E}`.

__WARNING__
If `f(unwrap(x))` is not a `T`, this functions throws an error.
"""
function and_then(f, ::Type{T}, x::Result{O, E})::Result{T, E} where {T, O, E}
    data = x.x
    Result{T, E}(data isa Ok ? Ok(f(data.x)) : Err(data.x))
end

"""
    map_or(f, x::Result, v)

If `x` is a result value, return `f(unwrap(x))`. Else, return `v`.
"""
map_or(f, x::Result{O, E}, v) where {O, E} = f(@unwrap_or x return v)

"""
    unwrap_or(x::Result, v)

If `x` is an error value, return `v`. Else, unwrap `x` and return its content.
"""
unwrap_or(x::Result, v) = @unwrap_or x v


"""
    unwrap_error_or(x::Result, v)

Like `unwrap_or`, but unwraps an error.
"""
unwrap_error_or(x::Result, v) = @unwrap_error_or x v

"""
    flatten(x::Option{Option{T}})

Convert an `Option{Option{T}}` to an `Option{T}`.

# Examples

```jldoctest
julia> flatten(some(some("x")))
some("x")

julia> flatten(some(none(Int)))
none(Int)
```
"""
flatten(x::Option{Option{T}}) where T = unwrap_or(x, none(T))

"""
    base(x::Option{T})

Convert an `Option{T}` to a `Union{Some{T}, Nothing}`.
"""
base(x::Option{T}) where T = Some(@unwrap_or x (return nothing))

export Ok, Err, Result, Option,
    is_error, some, none,
    unwrap, unwrap_error, expect, expect_error,
    and_then, unwrap_or, map_or, unwrap_error_or, flatten, base,
    @?, @unwrap_or, @unwrap_error_or

end
