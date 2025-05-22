push!(LOAD_PATH, "../src/")

using Documenter, ErrorTypes

DocMeta.setdocmeta!(ErrorTypes, :DocTestSetup, :(using ErrorTypes); recursive = true)

makedocs(;
    modules = [ErrorTypes],
    format = Documenter.HTML(),

    pages = [
        "Home" => "index.md",
        "Usage" => "usage.md",
        "Why use ErrorTypes?" => "motivation.md",
    ],
    sitename = "ErrorTypes.jl",
    authors = "Jakob Nybo Nissen",
    checkdocs = :exports,
    doctest = true,
)

deploydocs(;
    repo = "github.com/jakobnissen/ErrorTypes.jl.git",
)
