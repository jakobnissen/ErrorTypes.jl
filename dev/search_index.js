var documenterSearchIndex = {"docs":
[{"location":"usage/#Usage","page":"Usage","title":"Usage","text":"","category":"section"},{"location":"usage/#The-Result-type","page":"Usage","title":"The Result type","text":"","category":"section"},{"location":"usage/","page":"Usage","title":"Usage","text":"Result{O, E} is a struct containing exactly one of two so-called variants, Ok and Err. Result is a sum type from the package SumTypes - think of it like a parametric Enum with two instances of types O and E.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"Like other sum types, you should usually not construct a Result directly - indeed, Result have no direct constructors. Instead, the constructors for the types Ok and Err creates a Result, wrapping them - e.g. Ok{Int, String}(1) creates a Result{Int, String} containing Ok{Int, String}(1). Similarly, you should not construct an Ok or Err directly - these types are only useful as the content of an Result.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"The purpose of Result{O, E} is to represent either a success value of type O, or an error value of type E. For example, a function returning either a string or a 32-bit integer error code could return a Result{String, Int32}.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"The un-paramterized constructors Ok(x) and Err(x) creates special ResultConstructor instances. This type is useful only to be converted to Result - you will see in a bit how this is convenient.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"The type Option{T} is an alias for Result{T, Nothing}. This type has more convenience methods than other Result types, and should be used when the error state does not need to carry any information. There is no functional difference between using Option{T} and Result{T, Nothing} - it's the same type, Option is just more convenient.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"none(T) is a shortcut for Err{T, Nothing}(nothing), e.g. it creates an Option{T} with an error value. none by itself is a shorthand for Err(nothing) - a ResultConstructor. Similarly, some(x::T) is short for Ok{T, Nothing}(x), i.e. an easy constructor for the result value of Option{T}.","category":"page"},{"location":"usage/#Basic-usage","page":"Usage","title":"Basic usage","text":"","category":"section"},{"location":"usage/","page":"Usage","title":"Usage","text":"Always typeassert any function that returns an error type. The whole point of ErrorTypes is to encode error states in return types, and be specific about these error states. While ErrorTypes will technically work fine without function annotations, I highly recommend annotating return types:","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"Do this:","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"invert(x::Integer)::Option{Float64} = iszero(x) ? none : some(1/x)","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"And not this:","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"invert(x::Integer) = iszero(x) ? none(Float64) : some(1/x)","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"Note in the first example that none, which is an instance of ResultConstructor, is automatically converted to the correct type by the type assert. By annotating return functions, you can this use the simpler constructors of error types:","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"You can use none, which is automatically converted to Option containing an Err.\nYou can use Err(x) and Ok(x) to create ResultConstructors, which are converted by the typeassert to the correct Result.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"Here is an example where Ok and Err is used to make ResultConstructors, which are then converted to Result by the typeassert:","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"function get_length(x)::Result{Int, Base.IteratorSize}\n    isz = Base.IteratorSize(x)\n    if isa(isz, Base.HasShape) || isa(isz, Base.HasLength)\n        return Ok(Int(length(x)))\n    else\n        return Err(isz)\n    end\nend","category":"page"},{"location":"usage/#Conversion","page":"Usage","title":"Conversion","text":"","category":"section"},{"location":"usage/","page":"Usage","title":"Usage","text":"Apart from the two special cases above: The conversion of none to Option, and Err(x) and Ok(x) (of type ResultConstructor) to Result, error types can only convert to each other in certain circumstances. This is intentional, because type conversion is a major source of mistakes.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"An object of type Option and Result can be converted to its own type, i.e. convert(T, ::T) works.\nA Result{O, E} can be converted to a Result{O2, E2} if O <: O2 and E <: E2.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"It is intentionally NOT possible to e.g. convert a Result{Int, String} containing an Ok to a Result{Int, Int}, even if the Ok value contains an Int which is allowed in both of the Result types. The reason for this is that if it was allowed, whether or not conversions threw errors would depend on the value of an error type, not the type. This type-unstable behaviour would defeat idea behind this package, namely to present edge cases as types, not values.","category":"page"},{"location":"usage/#@?","page":"Usage","title":"@?","text":"","category":"section"},{"location":"usage/","page":"Usage","title":"Usage","text":"If you make an entire codebase of functions returning Results, it can get bothersome to constantly check if function calls contain error values and propagate those error values. To make this process easier, use the macro @?, which automatically propagates any error values. If this is applied to some expression x evaluating to a Result containing an error value, the macro will evaluate to something equivalent to return Err(unwrap_err(x)). If it contains a result value, the macro is evaluated to the equivalent of unwrap(x).","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"For example, suppose you want to implement a safe version of the harmonic mean function, which in turn uses a safe version of div:","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"safe_div(a::Integer, b::Real)::Option{Float64} = iszero(b) ? none : some(a/b)\n\nfunction harmonic_mean(v::AbstractArray{<:Integer})::Option{Float64}\n    sm = 0.0\n    for i in v\n        invi = safe_div(1, i)\n        is_none(invi) && return none\n        sm += unwrap(invi)\n    end\n    res = safe_div(length(v), sm)\n    is_none(res) && return none\n    return some(unwrap(res))\nend","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"In this function, we constantly have to check whether safe_div returned the error value, and return that from the outer function in that case. That can be more concisely written as:","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"function harmonic_mean(v::AbstractArray{<:Integer})::Option{Float64}\n    sm = 0.0\n    for i in v\n        sm += @? safe_div(1, i)\n    end\n    some(@? safe_div(length(v), sm))\nend","category":"page"},{"location":"usage/#When-to-use-an-error-type-vs-throw-an-error","page":"Usage","title":"When to use an error type vs throw an error","text":"","category":"section"},{"location":"usage/","page":"Usage","title":"Usage","text":"The error handling mechanism provided by ErrorTypes is a distinct method from throwing and catching errors. None is superior to the other in all circumstances.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"The handling provided by ErrorTypes is faster, safer, and more explicit. For most functions, you can use ErrorTypes. However, you can't only rely on it. Imagine a function A returning Option{T1}. A is called from function B, which can itself fail and returns an Option{T2}. However, now there are two distinct error states: Failure in A and failure in B. So what should B return? Result{T2, Enum{E1, E2}}, for some Enum type? But then, what about functions calling B? Where does it end?","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"In general, it's un-idiomatic to \"accumulate\" error states like this. You should handle an error state when it appears, and usually not return it far back the call chain.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"More importantly, you should distinguish between recoverable and unrecoverable error states. The unrecoverable are unexpected, and reveals that the program went wrong somehow. If the program went somewhere it shouldn't be, it's best to abort the program and show the stack trace, so you can debug it - here, an ordinary exception is better. If the errors are known to be possible beforehand, using ErrorTypes is better. For example, a program may use exceptions when encountering errors when parsing \"internal\" machine-generated files, which are supposed to be of a certain format, and use error types when parsing user input, which must always be expected to be possibly fallible.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"Because error types are so easily converted to exceptions (using unwrap and expect), internal library functions should preferably use error types.","category":"page"},{"location":"usage/#Reference","page":"Usage","title":"Reference","text":"","category":"section"},{"location":"usage/","page":"Usage","title":"Usage","text":"Modules = [ErrorTypes]","category":"page"},{"location":"usage/#ErrorTypes.Err-Tuple{Any}","page":"Usage","title":"ErrorTypes.Err","text":"Err\n\nThe error state of a Result{O, E}, carrying an object of type E. For convenience, Err(x) creates a dummy value that can be converted to the appropriate Result type.\n\n\n\n\n\n","category":"method"},{"location":"usage/#ErrorTypes.Ok-Tuple{Any}","page":"Usage","title":"ErrorTypes.Ok","text":"Ok\n\nThe success state of a Result{O, E}, carrying an object of type O. For convenience, Ok(x) creates a dummy value that can be converted to the appropriate Result type.\n\n\n\n\n\n","category":"method"},{"location":"usage/#ErrorTypes.Option","page":"Usage","title":"ErrorTypes.Option","text":"Option{T}\n\nAlias for Result{T, Nothing}\n\n\n\n\n\n","category":"type"},{"location":"usage/#ErrorTypes.Result","page":"Usage","title":"ErrorTypes.Result","text":"Result{O, E}\n\nA sum type of either Ok{O} or Err{E}. Used as return value of functions that can error with an informative error object of type E.\n\n\n\n\n\n","category":"type"},{"location":"usage/#ErrorTypes.and_then-Union{Tuple{E}, Tuple{O}, Tuple{T}, Tuple{Any, Type{T}, Result{O, E}}} where {T, O, E}","page":"Usage","title":"ErrorTypes.and_then","text":"and_then(f, ::Type{T}, x::Result{O, E})\n\nIf is a result value, apply f to unwrap(x), else return the error value. Always returns an Result{T, E}.\n\nWARNING If f(unwrap(x)) is not a T, this functions throws an error.\n\n\n\n\n\n","category":"method"},{"location":"usage/#ErrorTypes.base-Union{Tuple{Option{T}}, Tuple{T}} where T","page":"Usage","title":"ErrorTypes.base","text":"base(x::Option{T})\n\nConvert an Option{T} to a Union{Some{T}, Nothing}.\n\n\n\n\n\n","category":"method"},{"location":"usage/#ErrorTypes.expect-Tuple{Result, AbstractString}","page":"Usage","title":"ErrorTypes.expect","text":"expect(x::Result, s::AbstractString)\n\nIf x is of the associated error type, error with message s. Else, return the contained result type.\n\n\n\n\n\n","category":"method"},{"location":"usage/#ErrorTypes.expect_err-Tuple{Result, AbstractString}","page":"Usage","title":"ErrorTypes.expect_err","text":"expect_err(x::Result, s::AbstractString)\n\nIf x contains an Err, return the content of the Err. Else, throw an error with message s.\n\n\n\n\n\n","category":"method"},{"location":"usage/#ErrorTypes.flatten-Union{Tuple{Result{Option{T}, Nothing}}, Tuple{T}} where T","page":"Usage","title":"ErrorTypes.flatten","text":"flatten(x::Option{Option{T}})\n\nConvert an Option{Option{T}} to an Option{T}.\n\nExamples\n\njulia> flatten(some(some(\"x\")))\nOption{String}: Ok(\"x\")\n\njulia> flatten(some(none(Int)))\nOption{Int64}: Err(nothing)\n\n\n\n\n\n","category":"method"},{"location":"usage/#ErrorTypes.unwrap-Tuple{Result}","page":"Usage","title":"ErrorTypes.unwrap","text":"unwrap(x::Result)\n\nIf x is of the associated error type, throw an error. Else, return the contained result type.\n\n\n\n\n\n","category":"method"},{"location":"usage/#ErrorTypes.unwrap_err-Tuple{Result}","page":"Usage","title":"ErrorTypes.unwrap_err","text":"unwrap_err(x::Result)\n\nIf x contains an Err, return the content of the Err. Else, throw an error.\n\n\n\n\n\n","category":"method"},{"location":"usage/#ErrorTypes.unwrap_or-Tuple{Result, Any}","page":"Usage","title":"ErrorTypes.unwrap_or","text":"unwrap_or(x::Result, v)\n\nIf x is an error value, return v. Else, unwrap x and return its content.\n\n\n\n\n\n","category":"method"},{"location":"usage/#ErrorTypes.@?-Tuple{Any}","page":"Usage","title":"ErrorTypes.@?","text":"@?(expr)\n\nPropagate a Result with Err value to the outer function. Evaluate expr, which should return a Result. If it contains an Ok value x, evaluate to the unwrapped value x. Else, evaluates to return Err(x)t.\n\nExample\n\njulia> (f(x::Option{T})::Option{T}) where T = Ok(@?(x) + one(T));\n\njulia> f(some(1.0)), f(none(Int))\n(Option{Float64}: Ok(2.0), Option{Int64}: Err(nothing))\n\n\n\n\n\n","category":"macro"},{"location":"usage/#ErrorTypes.@unwrap_or-Tuple{Any, Any}","page":"Usage","title":"ErrorTypes.@unwrap_or","text":"@unwrap_or(expr, exec)\n\nEvaluate expr to a Result. If expr is a error value, evaluate exec and return that. Else, return the wrapped value in expr.\n\nExamples\n\njulia> safe_inv(x)::Option{Float64} = iszero(x) ? none : Ok(1/x);\n\njulia> function skip_inv_sum(it)\n    sum = 0.0\n    for i in it\n        sum += @unwrap_or safe_inv(i) continue\n    end\n    sum\nend;\n\njulia> skip_inv_sum([2,1,0,1,2])\n3.0\n\n\n\n\n\n","category":"macro"},{"location":"#ErrorTypes.jl","page":"Home","title":"ErrorTypes.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"ErrorTypes provides an easy way to efficiently encode error states in return types. Its types are modelled after Rust's Option and Result.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Example","category":"page"},{"location":"","page":"Home","title":"Home","text":"using ErrorTypes\n\nfunction safe_maximum(x::AbstractArray)::Option{eltype(x)}\n    isempty(x) ? none : some(maximum(x))\nend\n\nfunction using_safe_maximum(x)\n    maybe = safe_maximum(x)\n    println(unwrap_or(and_then(y -> \"Maximum is: $y\", String, maybe), \"ERROR: EMPTY ARRAY\"))\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"See also: Usage","category":"page"},{"location":"","page":"Home","title":"Home","text":"Advantages","category":"page"},{"location":"","page":"Home","title":"Home","text":"Zero-cost: In fully type-stable code, error handling using ErrorTypes is as fast as a manual check for the edge case, and significantly faster than exception handling.\nIncreased safety: ErrorTypes is designed to make you not guess. By making edge cases explicit, your code will be more reliable for yourself and for others.","category":"page"},{"location":"","page":"Home","title":"Home","text":"See also: Why use ErrorTypes?","category":"page"},{"location":"","page":"Home","title":"Home","text":"Comparisons to other packages","category":"page"},{"location":"","page":"Home","title":"Home","text":"The idea behind this package is well known and used in other languages, e.g. Rust and the functional languages (Clojure, Haskell etc). It is also implemented in the Julia packages Expect and ResultTypes, and to some extend MLStyle. Compared to these packages, ErrorTypes offer:","category":"page"},{"location":"","page":"Home","title":"Home","text":"Efficiency: All ErrorTypes methods and types should be maximally efficient. For example, an Option{T} is as lightweight as a Union{T, Nothing}, and manipulation of the Option is as efficient as a === check against nothing.\nIncreased comfort. The main disadvantage of using these packages are the increased friction in development. ErrorTypes provides more quality-of-life functionality for working with error types than Expect and ResultTypes, for example the simple Option type.\nFlexibility. Whereas Expect and ResultTypes require your error state to be encoded in an Exception object, ErrorTypes allow you to store it how you want. Want to store error codes as a Bool? Sure, why not.\nStrictness: ErrorTypes tries hard to not guess what you're doing. Error types with concrete values cannot be converted to another error type, and non-error types are never implicitly converted to error types. Generally, ErrorTypes tries to minimize room for error.","category":"page"},{"location":"motivation/#Why-use-ErrorTypes?","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"","category":"section"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"In short, ErrorTypes improves the safety of your error-handling code by reducing the opportunities for human error.","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"Some people think the source of programming bug are programs who misbehave by not computing what they are supposed to. This is false. Bugs arise from human failure. We humans fail to understand the programs we write. We forget the edge cases We create leaky abstractions. We don't document thoroughly.","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"If we want better programs, it is pointless to wait around for better humans to arrive. We can't excuse the existence of bugs with the existence human fallibility, because we will never get rid of that. Instead, we must design systems to contain and mitigate human error. Programming languages are such systems.","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"One source of such error is fallible functions. Some functions are natually fallible. Consider, for example, the maximum function from Julia's Base. This function will fail on empty collections. With an edge case like this, some human is bound to forget it at some point, and produce fragile software as a result. The behaviour of maximum is a bug waiting to happen.","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"However, because we know there is a potential bug hiding here, we have the ability to act. We can use our programming language to force us to remember the edge case. We can, for example, encode the edge case into the type system such that any code that forgets the edge case simply won't compile.","category":"page"},{"location":"motivation/#An-illustrative-example","page":"Why use ErrorTypes?","title":"An illustrative example","text":"","category":"section"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"Suppose you're building an important package that includes some text processing. At some point, you need a function that gets the length of the first word (in bytes) of some text. So, you write up the following:","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"function first_word_bytes(s::Union{String, SubString{String}})\n    findfirst(isspace, lstrip(s)) - 1\nend","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"Easy, fast, flexible, relatively generic. You also write a couple of tests to handle the edge cases:","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"@test first_word_bytes(\"Lorem ipsum\") == 5\n@test first_word_bytes(\" dolor sit amet\") == 5 # leading whitespace\n@test first_word_bytes(\"Rødgrød med fløde\") == 9 # Unicode","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"All tests pass, and you push to production. But alas! Your code has a horrible bug that causes your production server to crash! See, you forgot an edge case:","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"julia> first_word_bytes(\"boo!\")\nERROR: MethodError: no method matching -(::Nothing, ::Int64)","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"The infuriating part is that the Julia compiler is in on the plot against you: It knew that findfirst returned a Union{Int, Nothing}, not an Int as you assumed it did. It just decided to not share that information, leading you into a hidden trap.","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"We can do better. With this package, you can specify the return type of any function that can possibly fail. Here, we will encode it as an Option{Int}:","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"using ErrorTypes\n\nfunction safer_findfirst(f, x)::Option{eltype(keys(x))}\n    for (k, v) in pairs(x)\n        f(v) && return some(k) # some: value\n    end\n    none # none: absence of value\nend","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"Now, if you forget that safer_findfirst can error, and mistakenly assume that it always return an Int, your first_word_bytes will error in all cases, because almost no operation are permitted on Option objects.","category":"page"},{"location":"motivation/#Why-would-you-NOT-use-ErrorTypes?","page":"Why use ErrorTypes?","title":"Why would you NOT use ErrorTypes?","text":"","category":"section"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"Using ErrorTypes, or packages like it, provides a small but constant friction in your code. It will increase the burden of maintenance.","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"You will be constantly wrapping and unwrapping return values, and you now have to annotate function's return values. Refactoring code becomes a larger job, because these large, clunky type signatures all have to be changed. You will make mistakes with your return signatures and type conversions, which will slow down deveopment. Furthermore, you (intentionally) place retrictions on the input and output types of your functions, which, depending on the function's design, can limit its uses.","category":"page"},{"location":"motivation/","page":"Why use ErrorTypes?","title":"Why use ErrorTypes?","text":"So, use of this package comes down to how much developing time you are willing to pay for building more reliable software. Sometimes, it's not worth it.","category":"page"}]
}
