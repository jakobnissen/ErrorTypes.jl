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
    if inner isa Err
        Result{T1, E1}(Err{E1}(unsafe, inner.x))
    else
        Result{T1, E1}(Ok{T1}(unsafe, inner.x))
    end
end

function Base.convert(::Type{Result{T1, E1}}, x::Result{T2, E2}) where {T1, T2 <: T1, E1, E2 <: E1}
    Result{T1, E1}(x)
end

# Bizarrely, we need this method to avoid recursion when creating a Result
Base.convert(::Type{Result{T, E}}, x::Result{T, E}) where {T, E} = x

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

is_error(x::Result) = x.x isa Err

Option(x::Result{T, E}) where {T, E} = is_error(x) ? none(T) : Option{T}(x.x)
function Result(x::Option{T}, v::E) where {T, E}
    data = x.x
    inner = if x.x isa Err
        Err{E}(unsafe, v)
    else
        x.x
    end
    return Result{T, E}(inner)
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
            print(io, "some{", T, "}(", repr(x.x.x), ')')
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
(Option{Float64}: Ok(2.0), Option{Int64}: Err(nothing))
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
    quote
        local res = $(esc(expr))
        isa(res, Result) || throw(TypeError(Symbol("@unwrap_or"), Result, res))
        local data = res.x
        data isa Ok ? data.x : $(esc(exec))
    end
end

@noinline throw_unwrap_err() = error("unwrap on unexpected type")

"""
    unwrap(x::Result)

If `x` is of the associated error type, throw an error. Else, return the contained
result type.
"""
function unwrap(x::Result)
    data = x.x
    data isa Ok ? data.x : throw_unwrap_err()
end

"""
    unwrap_err(x::Result)

If `x` contains an `Err`, return the content of the `Err`. Else, throw an error.
"""
function unwrap_err(x::Result)
    data = x.x
    data isa Err ? data.x : throw_unwrap_err()
end

"""
    expect(x::Result, s::AbstractString)

If `x` is of the associated error type, error with message `s`. Else, return
the contained result type.
"""
function expect(x::Result, s::AbstractString)
    data = x.x
    data isa Ok ? data.x : error(s)
end

"""
    expect_err(x::Result, s::AbstractString)

If `x` contains an `Err`, return the content of the `Err`. Else, throw an error
with message `s`.
"""
function expect_err(x::Result, s::AbstractString)
    data = x.x
    data isa Err ? data.x : error(s)
end

"""
    and_then(f, ::Type{T}, x::Result{O, E})

If `is` a result value, apply `f` to `unwrap(x)`, else return the error value. Always returns a `Result{T, E}`.

__WARNING__
If `f(unwrap(x))` is not a `T`, this functions throws an error.
"""
function and_then(f, ::Type{T}, x::Result{O, E})::Result{T, E} where {T, O, E}
    data = x.x
    if data isa Ok
        Result{T, E}(Ok{T}(unsafe, f(data.x)::T))
    else
        Result{T, E}(Err{E}(unsafe, data.x))
    end
end

"""
    unwrap_or(x::Result, v)

If `x` is an error value, return `v`. Else, unwrap `x` and return its content.
"""
unwrap_or(x::Result, v) = @unwrap_or x v

"""
    flatten(x::Option{Option{T}})

Convert an `Option{Option{T}}` to an `Option{T}`.

# Examples

```jldoctest
julia> flatten(some(some("x")))
Option{String}: Ok("x")

julia> flatten(some(none(Int)))
Option{Int64}: Err(nothing)
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
    unwrap, unwrap_err, expect, expect_err,
    and_then, unwrap_or, flatten, base,
    @?, @unwrap_or

end
