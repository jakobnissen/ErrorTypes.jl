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

# Convert an error to another error if the former is a subtype of the other
function Base.convert(::Type{Result{O1, E1}}, x::Result{O2, E2}
) where {O1, E1, O2 <: O1, E2 <: E1}
    Err{O1, E1}(x.data._1)
end

# Convert Result value that contains an Err, even if the Ok parameter
# doesn't match, e.g. Err{Int, Float32} -> Err{String, AbstractFloat}
function Base.convert(::Type{Result{O1, E1}}, x::Result{O2, E2}
) where {O1, O2, E1, E2 <: E1}
    data = x.data
    if data isa Err
        return Err{O1, E1}(data._1)
    else
        error("cannot convert Ok value")
    end
end

# Same as above, but for Ok.
function Base.convert(::Type{Result{O1, E1}}, x::Result{O2, E2}
) where {O1, E1, E2, O2 <: O1}
    data = x.data
    if data isa Ok
        return Ok{O1, E1}(data._1)
    else
        error("cannot convert Err value")
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

function Base.convert(::Type{Option{T1}}, x::Option{T2}) where {T1, T2 <: T1}
    data = x.data
    if data isa Thing
        Thing{T1}(data._1)
    else
        None{T1}()
    end
end

function Base.convert(::Type{Option{T1}}, x::Option{T2}) where {T1, T2}
    data = x.data
    if data isa None
        return None{T1}()
    else
        error("cannot convert Thing value")
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

If `x` contains a None, return nothing. Else, throw an error with message `s`.
"""
expect_none(x::Option, s::AbstractString) = is_none(x) ? nothing : error(s)

@noinline unwrap_err() = error("unwrap on unexpected type")

"""
    unwrap(x::Union{Result, Option})

If `x` is of the associated error type, throw an error. Else, return the contained
result type.
"""
function unwrap end

function unwrap(x::Result)
    data = x.data
    data isa Ok ? data._1 : unwrap_err()
end

function unwrap(x::Option)
    data = x.data
    data isa Thing ? data._1 : unwrap_err()
end


"""
    unwrap_none(x::Option, s::AbstractString)

If `x` contains a None, return nothing. Else, throw an error.
"""
unwrap_none(x::Option) = is_none(x) ? nothing : unwrap_err()

"""
    @?(expr)

Propagate a `Result` or `Option` error value to the outer function.
Evaluate `expr`, which should return a `Result` or `Option`. If it contains
an error value, return the error value from the outer function. Else, the macro
evaluates to the result value of `expr`.

# Example
julia> (f(x::Option{T})::Option{T}) where T = Thing(@?(x) + one(T))

julia> f(Thing(1.0)), f(None{Int}())
(Option{Float64}: Thing(2.0), Option{Int64}: None())
"""
macro var"?"(expr)
    sym = gensym()
    quote
        $(sym)::Union{Result, Option} = $(esc(expr))
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
                return $sym
            end
        end
    end
end

export Result, Option,
    Thing, none, Ok, Err,
    is_error, is_none,
    expect, expect_none,
    unwrap, unwrap_none,
    @?

end # module
