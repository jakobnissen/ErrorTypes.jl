# ErrorTypes

![CI](https://github.com/jakobnissen/ErrorTypes.jl/workflows/CI/badge.svg)
[![Codecov](https://codecov.io/gh/jakobnissen/ErrorTypes.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/jakobnissen/ErrorTypes.jl)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://jakobnissen.github.io/ErrorTypes.jl/dev)

_Rust-like safe error handling in Julia_

ErrorTypes is a simple implementation of Rust-like error handling in Julia. Its goal is to increase safety of Julia code internally in packages by providing easy-to-use, zero-cost handling for recoverable errors.

Read more in the documentation.

## Example usage
This simple example shows a function that has one obvious error state, namely that there is no second field. This can be modelled with the `Option` type:
```julia
function second_csv_field(s::Union{String, SubString{String}})::Option{SubString{String}}
    p = nothing
    for i in 1:ncodeunits(s)
        if codeunit(s, i) == UInt8(',')
            isnothing(p) || return some(SubString(s, p, prevind(s, i))) 
            p = i + 1
        end
    end
    (isnothing(p) | (p == ncodeunits(s) + 1)) ? none : some(SubString(s, p, ncodeunits(s)))
end
```

This example shows usage of the type `Result`. When there are multiple error modes, we may encode the error state however we want, here in an `Enum`:
```julia
# corresponds to the error codes of libdeflate
@enum DecompressError::UInt8 BadData TooShort TooLong

function decompress(outbytes, inbytes)::Result{Int32, DecompressError}
    (n_bytes, errorcode) = ccall( ... ) # Call omitted here, returns an (Int32, Int32)
    if !iszero(errorcode)
        return Err(DecompressError(errorcode - 1))
    else
        return Ok(n_bytes)
    end
end
```

You can of course mix and match regular exceptions and error types. That is useful when you have both *unrecoverable* and *recoverable* errors. In the following example, I'm getting the first field of first row of a comma separated file. We expect the file and its header to be present, and the second row to be tab-separated, and will error if it's not, but a valid CSV file may contain no rows other than the header:
```julia
function first_field(io::IO)::Option{String}
    lines = eachline(io)
    if !startswith(first(iterate(lines)), "#Name\t")
        error("In file, expected header to begin with: \"#Name\\t\"")
    end
    nextit = iterate(lines)
    isnothing(nextit) && return none
    line = first(nextit)
    isempty(line) && return none
    tab_pos::Int = findfirst(isequal('\t'), line)
    some(line[1:tab_pos-1])
end
```

Again, please read the documentation.
