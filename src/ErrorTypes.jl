# Note: This module is full of code like:
# if x.data isa Ok
#     x.data._1
# else
#
# this is so the compiler won't typecheck inside the if blocks.
# that in turns leads to more effective code.

module ErrorTypes

using SumTypes

@sum_type Result{O, E} begin
    Ok{O, E}(::O)
    Err{O, E}(::E)
end

const Option{T} = Result{T, Nothing}

"""
    Result{O, E}

A sum type of either `Ok{O}` or `Err{E}`. Used as return value of functions that
can error with an informative error object of type `E`.
"""
Result

"""
    Option{T}

Alias for `Result{T, Nothing}`
"""
Option

function Option(x::Result{O, E}) where {O, E}
    data = x.data
    isa(data, Err) ? Err{O, Nothing}(nothing) : Ok{O, Nothing}(data._1)
end

function Result(x::Option{T}, e::E) where {T, E}
    data = x.data
    isa(data, Err) ? Err{T, E}(e) : Ok{T, E}(data._1)
end

"""
    @?(expr)

Propagate a `Result` with `Err` value to the outer function.
Evaluate `expr`, which should return a `Result`. If it contains an `Ok` value `x`,
evaluate to the unwrapped value `x`. Else, evaluates to `return Err(x)`t.

# Example

```jldoctest
julia> (f(x::Option{T})::Option{T}) where T = Ok(@?(x) + one(T));

julia> f(some(1.0)), f(none(Int))
(Option{Float64}: Ok(2.0), Option{Int64}: Err(nothing))
```
"""
macro var"?"(expr)
    sym = gensym()
    quote
        $(sym) = $(esc(expr))
        isa($sym, Result) || throw(TypeError(Symbol("@?"), "", Result, $sym))
        ($sym).data isa Ok ? ($sym).data._1 : return Err($(sym).data._1)
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
    sym = gensym()
    quote
        $(sym) = $(esc(expr))
        isa($sym, Result) || throw(TypeError(Symbol("@unwrap_or"), "", Result, $sym))
        isa($(sym).data, Err) ? $(esc(exec)) : $(sym).data._1
    end
end

struct ResultConstructor{R,T}
    x::T
end

"""
    Ok

The success state of a `Result{O, E}`, carrying an object of type `O`.
For convenience, `Ok(x)` creates a dummy value that can be converted to the
appropriate `Result type`.
"""
Ok(x) = ResultConstructor{Ok,typeof(x)}(x)

"""
    Err

The error state of a `Result{O, E}`, carrying an object of type `E`.
For convenience, `Err(x)` creates a dummy value that can be converted to the
appropriate `Result type`.
"""
Err(x) = ResultConstructor{Err,typeof(x)}(x)


function Base.convert(::Type{Result{O, E}}, x::ResultConstructor{Ok, O2}
) where {O, O2 <: O, E}
    Ok{O, E}(x.x)
end

function Base.convert(::Type{Result{O, E}}, x::ResultConstructor{Err, E2}
) where {O, E, E2 <: E}
    Err{O, E}(x.x)
end

Base.convert(::Type{Result{O, E}}, x::Result{O, E}) where {O, E} = x

# Convert an error to another error if the former is a subtype of the other
function Base.convert(::Type{Result{O1, E1}}, x::Result{O2, E2}
) where {O1, E1, O2 <: O1, E2 <: E1}
    data = x.data
    if data isa Err
        Err{O1, E1}(data._1)
    else
        Ok{O1, E1}(data._1)
    end
end

const none = Err(nothing)
none(::Type{T}) where T = Err{T, Nothing}(nothing)
some(x::T) where T = Ok{T, Nothing}(x)


is_error(x::Result{O, E}) where {O, E} = x.data isa Err{O, E}

"""
    expect(x::Result, s::AbstractString)

If `x` is of the associated error type, error with message `s`. Else, return
the contained result type.
"""
function expect end

function expect(x::Result, s::AbstractString)
    data = x.data
    data isa Ok ? data._1 : error(s)
end

"""
    expect_err(x::Result, s::AbstractString)

If `x` contains an `Err`, return the content of the `Err`. Else, throw an error
with message `s`.
"""
function expect_err(x::Result, s::AbstractString)
    data = x.data
    data isa Err ? data._1 : error(s)
end

@noinline throw_unwrap_err() = error("unwrap on unexpected type")

"""
    unwrap(x::Result)

If `x` is of the associated error type, throw an error. Else, return the contained
result type.
"""
function unwrap end

function unwrap(x::Result)
    data = x.data
    data isa Ok ? data._1 : throw_unwrap_err()
end

"""
    unwrap_err(x::Result)

If `x` contains an `Err`, return the content of the `Err`. Else, throw an error.
"""
function unwrap_err(x::Result)
    data = x.data
    data isa Err ? data._1 : throw_unwrap_err()
end


"""
    and_then(f, ::Type{T}, x::Result{O, E})

If `is` a result value, apply `f` to `unwrap(x)`, else return the error value. Always returns an `Option{T}` / `Result{T, E}`.

__WARNING__
If `f(unwrap(x))` is not a `T`, this functions throws an error.
"""
function and_then(f, ::Type{T}, x::Result{O, E}) where {T, O, E}
    data = x.data
    if data isa Ok
        Ok{T, E}(f(data._1))
    else
        Err{T, E}(data._1)
    end
end

"""
    unwrap_or(x::Result, v)

If `x` is an error value, return `v`. Else, unwrap `x` and return its content.
"""

function unwrap_or(x::Result, v)
    data = x.data
    data isa Ok ? data._1 : v
end

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
flatten(x::Option{Option{T}}) where T = @unwrap_or x Err{T, Nothing}(nothing)

export Result, Option,
    none, some, Ok, Err,
    is_error,
    expect, expect_err,
    unwrap, unwrap_err,
    and_then, unwrap_or, flatten,
    @?, @unwrap_or

end # module
