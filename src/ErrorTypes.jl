# Note: This module is full of code like:
# if x.data isa Thing
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

"""
    Result{O, E}

A sum type of either `Ok{O}` or `Err{E}`. Used as return value of functions that
can error with an informative error object of type `E`.
"""
Result

@sum_type Option{T} begin
    Thing{T}(::T)    
    None{T}()
end    

"""
    Option{T}

A sum type of either `Thing{T}` or `None`. Used instead of `Result` as return
value of functions whose error state need not carry any information.
"""
Option

"""
    @?(expr)

Propagate a `Result` or `Option` error value to the outer function.
Evaluate `expr`, which should return a `Result` or `Option`. If it contains
a result value `x`, evaluate to the unwrapped value `x`.
Else, evaluates to `return none` for `Option` and `return Err(x)` for Result.

# Example
julia> (f(x::Option{T})::Option{T}) where T = Thing(@?(x) + one(T))

julia> f(Thing(1.0)), f(None{Int}())
(Option{Float64}: Thing(2.0), Option{Int64}: None())
"""
macro var"?"(expr)
    sym = gensym()
    quote
        $(sym) = $(esc(expr))
        if !isa($sym, Union{Result, Option})
            throw(TypeError(Symbol("@?"), "", Union{Result, Option}, $sym))
        end
        if $sym isa Option
            if ($sym).data isa Thing
                ($sym).data._1
            else
                return none
            end
        else
            if ($sym).data isa Ok
                ($sym).data._1
            else
                return Err($(sym).data._1)
            end
        end
    end
end

"""
    @unwrap_or(expr, exec)

Evaluate `expr` to a `Result` or `Option`. If `expr` is a error value, evaluate
`exec` and return that. Else, return the wrapped value in `expr`.

# Examples

```
julia> safe_inv(x)::Option{Float64} = iszero(x) ? none : Thing(1/x);

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
        if !isa($sym, Union{Result, Option})
            throw(TypeError(Symbol("@unwrap_or"), "", Union{Result, Option}, $sym))
        end
        data = $(sym).data
        if isa(data, Union{None, Err})
            $(esc(exec))
        else
            data._1
        end
    end
end

Option(x::Result{O}) where O = Thing(@unwrap_or x (return None{O}()))

function Result(x::Option{T}, e::E) where {T, E}
    data = x.data
    if data isa Thing
        Ok{T, E}(data._1)
    else
        Err{T, E}(e)
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

"""
    None{T}

The variant of `Option` signifying absence of a value of type `T`. The singleton
`none` is the instance of `None{Nothing}` (NOT an `Option`), and can be freely
converted to any `Option` value containing a `None`.
"""
None

const none = None{Nothing}().data
Base.convert(::Type{<:Option{T}}, ::None{Nothing}) where T = None{T}()

Base.convert(::Type{Option{T}}, x::Option{T}) where T = x

function Base.convert(::Type{Option{T1}}, x::Option{T2}) where {T1, T2 <: T1}
    data = x.data
    if data isa Thing
        Thing{T1}(data._1)
    else
        None{T1}()
    end
end

"""
    Thing(x::T)

Construct a `Thing{T}(x)`, variant of `Option` signifying the presence of a
value `x`.
"""
Thing(x::T) where T = Thing{T}(x)

is_error(x::Result{O, E}) where {O, E} = x.data isa Err{O, E}
is_none(x::Option{T}) where T = x.data isa None{T}

"""
    expect(x::Union{Result, Option}, s::AbstractString

If `x` is of the associated error type, error with message `s`. Else, return
the contained result type.
"""
function expect end

function expect(x::Option, s::AbstractString)
    data = x.data
    data isa Thing ? data._1 : error(s)
end

function expect(x::Result, s::AbstractString)
    data = x.data
    data isa Ok ? data._1 : error(s)
end

"""
    expect_none(x::Option, s::AbstractString)

If `x` contains a `None`, return `nothing`. Else, throw an error with message `s`.
"""
expect_none(x::Option, s::AbstractString) = is_none(x) ? nothing : error(s)

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
    unwrap(x::Union{Result, Option})

If `x` is of the associated error type, throw an error. Else, return the contained
result type.
"""
function unwrap end

function unwrap(x::Result)
    data = x.data
    data isa Ok ? data._1 : throw_unwrap_err()
end

function unwrap(x::Option)
    data = x.data
    data isa Thing ? data._1 : throw_unwrap_err()
end

"""
    unwrap_none(x::Option)

If `x` contains a `None`, return `nothing`. Else, throw an error.
"""
unwrap_none(x::Option) = is_none(x) ? nothing : throw_unwrap_err()

"""
    unwrap_err(x::Result)

If `x` contains an `Err`, return the content of the `Err`. Else, throw an error.
"""
function unwrap_err(x::Result)
    data = x.data
    data isa Err ? data._1 : throw_unwrap_err()
end


"""
    and_then(f, x::Union{Option, Result})

If `x` is an error value, return `x`. Else, apply `f` to the contained value and
return it wrapped as the same type as `x`.
"""
function and_then(f, x::Option)
    data = x.data
    data isa Thing ? Thing(f(data._1)) : x
end

function and_then(f, x::Result{O, E}) where {O, E}
    data = x.data
    if data isa Ok
        v = f(data._1)
        Ok{typeof(v), E}(v)
    else
        x
    end
end

"""
    unwrap_or(x::Union{Option, Result}, v)

If `x` is an error value, return `v`. Else, unwrap `x` and return its content.
"""
function unwrap_or(x::Option, v)
    data = x.data
    data isa Thing ? data._1 : v
end

function unwrap_or(x::Result, v)
    data = x.data
    data isa Ok ? data._1 : v
end

"""
    flatten(x::Option{Option{T}})

Convert an `Option{Option{T}}` to an `Option{T}`.

# Examples

```
julia> flatten(Thing(Thing("x")))
Option{String}: Thing("x")

julia> flatten(Thing(ErrorTypes.None{Int}()))
Option{Int64}: ErrorTypes.None()
```
"""
flatten(x::Option{Option{T}}) where T = @unwrap_or x None{T}()

export Result, Option,
    Thing, none, Ok, Err,
    is_error, is_none,
    expect, expect_none, expect_err,
    unwrap, unwrap_none, unwrap_err,
    and_then, unwrap_or, flatten,
    @?, @unwrap_or

end # module
