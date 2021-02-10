## Release 0.3
__Breaking changes__

* It is now ONLY possible to convert an `Option{T1}` to an `Option{T2}`, if `T1 <: T2`.
* It is now ONLY possible to convert a `Result{O1, E1}` to a `Result{O2, E2}` if `O1 <: O2` and `E1 <: E2`.
* `@? x` when `x` is a `Result{O, E}` containing an `Err` with value `v` now evaluates to `return Err(v)` instead of `return x`.

__New features__

* An `Option{T}` can now be constructed from a `Result{T}`, yielding the error value if the result contains an error value.
* A `Result{O, E}` can now be constructed using `Result(::Option{O}, e::E)`. If the option contains an error value, this will result in `Err{O, E}(e)`
* New function `flatten`. Turns an `Option{Option{T}}` into an `Option{T}`.
* New function: `unwrap_err(::Result)`. Unwraps the wrapped error type of a `Result`, and throws an error if the `Result` conains an `Ok`
* New function: `expect_err(::Result, ::AbstractString)`. Similar to `unwrap_err`, but throws an error with a custom message.
* `None` is now exported.

## Release 0.2
__Breaking changes__

None

__New features__

* New function `unwrap_or(x::Union{Option, Result}, v)`. Returns `v` if `x` is an error value, else unwrap `x`.
* New macro `@unwrap_or x expr`. Similar to the function `unwrap_or`, but does not evaluate `expr` if `x` is not an error type. Allows you to do e.g. `@unwrap or x break` to break out of a loop if you encounter an error value.
* New function `and_then(f, x::Union{Option, Result})`. Returns `x` if it's an error value, else returns `f(unwrap(x))`, wrapped as the same type as `x`.

## Release 0.1
Initial release
