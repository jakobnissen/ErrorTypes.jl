module ErrorTypes

"""
    Result{R, E}

An object that can be either a result of type `R` or an error of type `E`,
but not both.
"""
struct Result{R, E}
    x::Union{R, E}

    function Result{R, E}(x) where {R, E}
        if typeintersect(R, E) !== Union{}
            error("result and error type must be disjoint")
        end
        new{R, E}(convert(Union{R, E}, x))
    end
end

"""
    Option{T}

Alias for `Result{Some{T}, Nothing}`. An object which can either be a T, or not.
Used to safeguard against unexpected return types from a function
"""
const Option{T} = Result{Some{T}, Nothing}

"""
    none(::Type{T})

Construct an `Option{Some{T}}(nothing)`, the absence of a value of type `T`.
"""
none(::Type{T}) where T = Option{T}(nothing)

"""
    none(x::T)

Construct a `Option{Some{T}}(Some(T))`, the presence of a value `x`.
"""
some(x::T) where T = Option{T}(Some(x))

Base.convert(::Type{<:Result{R,E}}, x::Union{R, E}) where {R, E} = Result{R,E}(x)

function Base.show(io::IO, x::Option)
    if x.x === nothing
        print(io, "none(", result_type(x), ')')
    else
        print(io, "some(", something(x.x), ')')
    end
end

result_type(x::Result{R}) where R = R
result_type(x::Result{Some{T}, Nothing}) where T = T
error_type(x::Result{R, E}) where {R, E} = E
is_error(x::Result) = x.x isa error_type(x)

"""
    expect(x::Result, s::AbstractString

If `x` is of the associated error type, error with message `s`. Else, return
the contained
result type.
"""
expect(x::Result, s::AbstractString) = is_error(x) ? error(s) : extract(x)

"""
    expect_nothing(x::Option, s::AbstractString)

If `x` contains a nothing, return that. Else, throw an error with message `s`.
"""
expect_nothing(x::Option, s::AbstractString) = is_error(x) ? nothing : error(s)

"""
    unwrap(x::Result)

If `x` is of the associated error type, throw an error. Else, return the contained
result type.
"""
unwrap(x::Result) = expect(x, "unwrap of error type")

"""
    expect_nothing(x::Option, s::AbstractString)

If `x` contains a nothing, return that. Else, throw an error.
"""
unwrap_nothing(x::Option) = expect_nothing(x, "expected nothing, found something")

"""
    extract(x::Result{R, E})

Extract the value of `x`, returning a `Union{R, E}`. If `x` isa `Option{T}`,
return the internal `Union{T, Nothing}`.
"""
extract(x::Result) = x.x
extract(x::Option) = is_error(x) ? nothing : something(x.x)

export Result, Option,
    some, none,
    is_error,
    expect, expect_nothing,
    unwrap, unwrap_nothing,
    extract

end # module