using ErrorTypes
import ErrorTypes: None
using Test

@testset "Option" begin
    # instantiation
    @test None{Int}() isa Option{Int}
    @test !(None{Float32}() isa Option{AbstractFloat})
    @test !(None{Int}() isa None)

    # Conversion from none
    @test convert(Option{Int}, none) isa Option{Int}
    @test convert(Option{Some{Nothing}}, none) isa Option{Some{Nothing}}
    @test_throws MethodError convert(Int, none)
    @test_throws MethodError convert(Option{String}, "foo")

    # Convert from Option
    @test convert(Option{Integer}, Thing(1)) isa Option{Integer}
    @test convert(Option{AbstractString}, None{String}()) isa Option{AbstractString}
    @test convert(Option{Union{String, Dict}}, Thing("foo")) isa Option{Union{String, Dict}}
    @test convert(Option{String}, None{Int}()) isa Option{String}
    @test convert(Option{Float64}, None{Float64}()) isa Option{Float64}
    @test_throws ErrorException convert(Option{String}, Thing(1))

    # is_none
    @test is_none(None{Int}())
    @test is_none(convert(Option{String}, none))
    @test !is_none(Thing([0x01, 0x02]))
    @test !is_none(Thing(nothing))
    @test !is_none(Thing(none))

    # unwrap
    @test unwrap(Thing(3.3)) === 3.3
    @test unwrap(Thing(nothing)) === nothing
    @test unwrap(Thing(none)) === none
    @test_throws ErrorException unwrap(None{Int}())
    @test_throws ErrorException unwrap(convert(Option{AbstractArray}, none))

    # unwrap_or
    @test unwrap_or(Thing(3.3), 11) === 3.3
    @test unwrap_or(Thing(missing), nothing) === missing
    @test unwrap_or(Thing(nothing), 1) === nothing
    @test unwrap_or(None{Int}(), 5) === 5

    # expect
    @test expect(Thing("hello"), "err") === "hello"
    @test expect(Thing([0x01, 0x02]), "foo") == [0x01, 0x02]
    @test expect(Thing(nothing), "isnothing") === nothing
    @test_throws ErrorException expect(convert(Option{Integer}, none), "int")
    @test_throws ErrorException expect(convert(Option{Nothing}, none), "nothing")

    # unwrap_none
    @test unwrap_none(None{Integer}()) === nothing
    @test unwrap_none(convert(Option{Bool}, none)) === nothing
    @test_throws ErrorException unwrap_none(Thing(1))
    @test_throws ErrorException unwrap_none(Thing{String}("foo"))
    @test_throws ErrorException unwrap_none(Thing(nothing))

    # expect_none
    @test expect_none(None{Float64}(), "isfloat") === nothing
    @test expect_none(convert(Option{Set}, none), "isset") === nothing
    @test_throws ErrorException expect_none(Thing("hello"), "")
    @test_throws ErrorException expect_none(Thing(Bool[]), "bar")

    # and_then
    @test and_then(x -> x + 1, Thing(0.0)) === Thing(1.0)
    @test and_then(x -> abs(x), Thing(-55)) === Thing(55)
    @test and_then(x -> x + 1, None{String}()) === None{String}()
    @test and_then(x -> "foo", None{Int}()) === None{Int}()

    # flatten
    @test flatten(Thing(Thing(11))) == Thing(11)
    @test flatten(Thing(Thing("foo"))) == Thing("foo")
    @test flatten(Thing(None{Float64}())) == None{Float64}()
    @test flatten(None{Option{Dict{Int, Int}}}()) == None{Dict{Int, Int}}()
    @test flatten(Thing(Thing(None{Int}()))) == Thing(None{Int}())
end

@testset "Result" begin
    # instantiation
    @test Ok{Bool, String}(true) isa Result{Bool,String}
    @test Ok{Bool, String}(false).data isa Ok{Bool,String}
    @test Err{Int, Int}(15) isa Result{Int, Int}
    @test_throws TypeError Err{Float64, Int}(1.0)
    @test_throws TypeError Ok{Bool, Int}(5)
    
    # conversion
    @test convert(Result{String, Int}, Ok("foo")) isa Result{String, Int}
    @test convert(Result{String, Int}, Ok("foo")).data isa Ok{String, Int}
    @test convert(Result{String, Int}, Err(15)) isa Result{String, Int}
    @test convert(Result{String, Int}, Err(15)).data isa Err{String, Int}
    @test convert(Result{Union{Int, UInt}, Int}, Ok(15)) isa Result{Union{Int, UInt}, Int}
    @test convert(Result{Union{String, Int}, Int}, Ok("foo")).data isa Ok{Union{String, Int}, Int}

    # convert a result directly to another if all the subtypes match
    x = Ok{Bool, Bool}(true)
    @test convert(Result{Bool, Bool}, x) === x
    @test convert(Result{Integer, AbstractString}, Err{Int, String}("boo")) isa Result{Integer, AbstractString}
    @test convert(Result{Signed, String}, Ok{Int32, String}(Int32(9))) isa Result{Signed, String}
    @test_throws MethodError convert(Result{Dict, Array}, Ok{Int, Bool}(1))

    # convert Result values with differing params. It works if the param of
    # the variant is conveted to a supertype.
    @test convert(Result{Integer, String}, Ok{Int32, Bool}(Int32(1))) isa Result{Integer, String}
    @test convert(Result{Bool, Signed}, Err{String, Int}(15)) isa Result{Bool, Signed}
    @test_throws ErrorException convert(Result{Dict, Integer}, Ok{Bool, Int}(true))
    @test_throws ErrorException convert(Result{Signed, String}, Err{Int, AbstractArray}([]))

    @test_throws MethodError convert(Result{Int, String}, Ok("foo"))
    @test_throws MethodError convert(Result{Int, Int}, Err("foo"))
    @test_throws MethodError convert(Result{String, Int}, Err("foo"))
    @test_throws MethodError convert(Result{Int, String}, Ok([1,2,3]))
    
    # is_error
    @test is_error(convert(Result{Int, Bool}, Err(false)))
    @test is_error(Err{String, AbstractArray}([1,2]))
    @test !is_error(convert(Result{Bool, AbstractFloat}, Ok(true)))
    @test !is_error(Ok{Int, Dict}(11))
    
    # unwrap
    @test unwrap(Ok{Int, String}(9)) === 9
    @test unwrap(convert(Result{Dict, Dict}, Ok(Dict(1=>5)))) == Dict(1=>5)
    @test_throws ErrorException unwrap(Err{Int, String}("foo"))
    @test_throws ErrorException unwrap(Err{Bool, Bool}(true))

    @test unwrap_or(Ok{Int, Float64}(5), 11) === 5
    @test unwrap_or(Ok{Nothing, Nothing}(nothing), 1) === nothing
    @test unwrap_or(Err{String, Dict}(Dict()), "hello") == "hello"
    @test unwrap_or(Err{Int, Int}(1), 1 + 1) === 2
    
    # expect
    @test expect(Ok{Nothing, Int}(nothing), "foo") === nothing
    @test expect(convert(Result{Int,Int}, Ok(17)), " ") === 17
    @test_throws ErrorException expect(Err{Int, UInt}(UInt(11)), "bar")
    @test_throws ErrorException expect(Err{Bool, Bool}(true), "foo")

    # and_then
    @test and_then(x -> x + 1, Ok{Float64, String}(5.0)) === Ok{Float64, String}(6.0)
    @test and_then(x -> abs(x), Ok{Int, Dict}(-55)) === Ok{Int, Dict}(55)
    @test and_then(x -> x + 1, Err{String, Int}(1)) === Err{String, Int}(1)
    @test and_then(x -> "foo", Err{Int, Int}(1)) === Err{Int, Int}(1)
end

@testset "Interaction" begin
    # Construct Option from Result
    @test Option(Ok{String, Int}("foo")) == Thing("foo")
    @test Option(Err{String, Int}(15)) == None{String}()

    # Construct Result from Option
    @test Result(None{String}(), 0x01) == Err{String, UInt8}(0x01)
    @test Result(Thing(0x1234), []) == Ok{UInt16, Vector{Any}}(0x1234)
    @test Result(Thing(1), 2) == Ok{Int, Int}(1)
end

@testset "@?" begin
    # Generic Option usage
    function testf1(x)::Option{typeof(x)}
        iszero(x) ? none : Thing(x + one(x))
    end

    function testf2(x)::Option{String}
        Thing(string(@? testf1(x)))
    end

    @test is_none(testf2(0))
    @test unwrap(testf2(1)) == "2"

    # Generic Result usage
    function testf3(x)::Result{Int, Union{Nothing, Missing}}
        if iszero(x)
            return Err(nothing)
        elseif isone(x)
            return Err(missing)
        else
            return Ok(x + 1)
        end
    end

    function testf4(x)::Result{Float64, Union{Nothing, Missing}}
        y = @? testf3(x)
        Ok(y + 0.5)
    end

    @test is_error(testf4(0))
    @test is_error(testf4(1))
    @test !is_error(testf4(3))
    @test unwrap(testf4(5)) === 6.5

    @test_throws TypeError @? 1 + 1
end

@testset "@unwrap_or" begin
    not_zero(x::Int)::Option{Int} = iszero(x) ? none : Thing(1 + x)

    function my_sum(f, it)
        sum = 0
        for i in it
            sum += @unwrap_or f(i) continue
        end
        sum
    end

    @test my_sum(not_zero, [1,2,0,3,0,1]) == 11

    function not_zero_two(x::Int)::Result{Float64, String}
        iszero(x) && return Err("Zero")
        isnan(x) && return Err("NaN")
        Ok(1 / x)
    end

    @test my_sum(not_zero_two, [1,2,0,2,0,1]) === 3.0

    @test_throws TypeError @unwrap_or (1 + 1) "foo"
end 
    
