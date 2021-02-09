## Release 0.3
__Breaking changes__

None

__New features__

* New function `flatten`. Turns an `Option{Option{T}}` into an `Option{T}`.

## Release 0.2
__Breaking changes__

None

__New features__

* New function `unwrap_or(x::Union{Option, Result}, v)`. Returns `v` if `x` is an error value, else unwrap `x`.
* New macro `@unwrap_or x expr`. Similar to the function `unwrap_or`, but does not evaluate `expr` if `x` is not an error type. Allows you to do e.g. `@unwrap or x break` to break out of a loop if you encounter an error value.
* New function `and_then(f, x::Union{Option, Result})`. Returns `x` if it's an error value, else returns `f(unwrap(x))`, wrapped as the same type as `x`.

## Release 0.1
Initial release
