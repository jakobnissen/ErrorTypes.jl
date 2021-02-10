# Why use ErrorTypes?
In short, ErrorTypes improves the _safety_ of your error-handling code by reducing the opportunities for _human error_.

Some people think the source of programming bug are programs who misbehave by not computing what they are supposed to. This is false. Bugs arise from _human_ failure. We humans fail to understand the programs we write. We forget the edge cases We create leaky abstractions. We don't document thoroughly.

If we want better programs, it is pointless to wait around for better humans to arrive. We can't excuse the existence of bugs with the existence human fallibility, because we will never get rid of that. Instead, we must design systems to contain and mitigate human error. Programming languages are such systems.

One source of such error is _fallible functions_. Some functions are natually fallible. Consider, for example, the `maximum` function from Julia's Base. This function will fail on empty collections. With an edge case like this, some human is bound to forget it at some point, and produce fragile software as a result. The behaviour of `maximum` is a bug waiting to happen.

However, because we *know* there is a potential bug hiding here, we have the ability to act. We can use our programming language to _force_ us to remember the edge case. We can, for example, encode the edge case into the type system such that any code that forgets the edge case simply won't compile.

## An illustrative example

Suppose you're building an important package that includes some text processing. At some point, you need a function that gets the length of the first word (in bytes) of some text. So, you write up the following:

```julia
function first_word_bytes(s::Union{String, SubString{String}})
    findfirst(isspace, lstrip(s)) - 1
end
```
Easy, fast, flexible, relatively generic. You also write a couple of tests to handle the edge cases:

```julia
@test first_word_bytes("Lorem ipsum") == 5
@test first_word_bytes(" dolor sit amet") == 5 # leading whitespace
@test first_word_bytes("Rødgrød med fløde") == 9 # Unicode
```

All tests pass, and you push to production. But alas! Your code has a horrible bug that causes your production server to crash! See, you forgot an edge case:

```julia
julia> first_word_bytes("boo!")
ERROR: MethodError: no method matching -(::Nothing, ::Int64)
```

The infuriating part is that the Julia compiler is in on the plot against you: It *knew* that `findfirst` returned a `Union{Int, Nothing}`, not an `Int` as you assumed it did. It just decided to not share that information, leading you into a hidden trap.

We can do better. With this package, you can specify the return type of any function that can possibly fail. Here, we will encode it as an `Option{Int}`:

```julia
using ErrorTypes

function safer_findfirst(f, x)::Option{eltype(keys(x))}
    for (k, v) in pairs(x)
        f(v) && return Thing(k) # thing: value
    end
    none # none: absence of value
end
```

Now, if you forget that `safer_findfirst` can error, and mistakenly assume that it always return an `Int`, your `first_word_bytes` will error in _all_ cases, because almost no operation are permitted on `Option` objects.

## Why would you NOT use ErrorTypes?
Using ErrorTypes, or packages like it, provides a small but constant _friction_ in your code. It will increase the burden of maintenance.

You will be constantly wrapping and unwrapping return values, and you now have to annotate function's return values. Refactoring code becomes a larger job, because these large, clunky type signatures all have to be changed. You will make mistakes with your return signatures and type conversions, which will slow down deveopment. Furthermore, you (intentionally) place retrictions on the input and output types of your functions, which, depending on the function's design, can limit its uses.

So, use of this package comes down to how much developing time you are willing to pay for building more reliable software. Sometimes, it's not worth it.
