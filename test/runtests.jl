using ErrorTypes
using Test

@testset "Result" begin
    # instantiation
    @test Result{Bool, String}(Ok(true)) isa Result{Bool,String}
    @test Result{Bool, String}(Ok(false)) isa Result{Bool,String}
    @test Result{Int, Int}(Err(15)) isa Result{Int, Int}
    @test_throws MethodError Err{Int}(1.0)
    @test_throws MethodError Ok{Bool}(5)
    
    # conversion
    @test convert(Result{String, Int}, Ok("foo")) isa Result{String, Int}
    @test convert(Result{String, Int}, Ok("foo")).x isa Ok{String}
    @test convert(Result{String, Int}, Err(15)) isa Result{String, Int}
    @test convert(Result{String, Int}, Err(15)).x isa Err{Int}
    @test convert(Result{Union{Int, UInt}, Int}, Ok(15)) isa Result{Union{Int, UInt}, Int}
    @test convert(Result{Union{String, Int}, Int}, Ok("foo")).x isa Ok{Union{String, Int}}

    # convert a result directly to another if all the subtypes match
    x = Ok{Bool}(true)
    @test convert(Result{Bool, Bool}, x).x isa Ok{Bool}
    @test convert(Result{Integer, AbstractString}, Err{String}("boo")) isa Result{Integer, AbstractString}
    @test convert(Result{Signed, String}, Ok{Int32}(Int32(9))) isa Result{Signed, String}
    @test_throws MethodError convert(Result{Dict, Array}, Ok{Int}(1))

    # Errors if converting from different result type
    @test_throws MethodError convert(Result{UInt, Int}, Ok{Int}(1))
    @test_throws MethodError convert(Result{UInt, Int}, Err{Int}(UInt(1)))
    @test_throws MethodError convert(Result{Dict, Integer}, Ok{Bool}(true))
    @test_throws MethodError convert(Result{Signed, String}, Err{AbstractArray}([]))

    @test_throws MethodError convert(Result{Int, String}, Ok("foo"))
    @test_throws MethodError convert(Result{Int, Int}, Err("foo"))
    @test_throws MethodError convert(Result{String, Int}, Err("foo"))
    @test_throws MethodError convert(Result{Int, String}, Ok([1,2,3]))
    
    # is_error
    @test is_error(convert(Result{Int, Bool}, Err(false)))
    @test is_error(Result{String, AbstractArray}(Err([1,2])))
    @test !is_error(convert(Result{Bool, AbstractFloat}, Ok(true)))
    @test !is_error(Result{Int, Dict}(Ok(11)))
    
    # unwrap
    @test unwrap(Result{Int, String}(Ok(9))) === 9
    @test unwrap(convert(Result{Dict, Dict}, Ok(Dict(1=>5)))) == Dict(1=>5)
    @test_throws ErrorException unwrap(Result{Int, String}(Err("foo")))
    @test_throws ErrorException unwrap(Result{Bool, Bool}(Err(true)))

    @test unwrap_or(Result{Int, Float64}(Ok(5)), 11) === 5
    @test unwrap_or(Result{Nothing, Nothing}(Ok(nothing)), 1) === nothing
    @test unwrap_or(Result{String, Dict}(Err(Dict())), "hello") == "hello"
    @test unwrap_or(Result{Int, Int}(Err(1)), 1 + 1) === 2
    
    # expect
    @test expect(Result{Nothing, Int}(Ok(nothing)), "foo") === nothing
    @test expect(convert(Result{Int,Int}, Ok(17)), " ") === 17
    @test_throws ErrorException expect(Result{Int, UInt}(Err(UInt(11))), "bar")
    @test_throws ErrorException expect(Result{Bool, Bool}(Err(true)), "foo")

    # unwrap_err
    @test unwrap_err(Result{String, UInt}(Err(UInt(19)))) == UInt(19)
    @test unwrap_err(Result{AbstractDict, String}(Err("bar"))) == "bar"
    @test_throws ErrorException unwrap_err(Result{Int, Int}(Ok(1)))
    @test_throws ErrorException unwrap_err(Result{String, Int}(Ok("bar")))

    # expect_err
    @test expect_err(Result{Vector, AbstractString}(Err("x")), "foo") == "x"
    @test expect_err(Result{Int, UInt8}(Err(0xa4)), "mistake!") == 0xa4
    @test_throws ErrorException expect_err(Result{Int, UInt8}(Ok(15)), "foobar")
    @test_throws ErrorException expect_err(Result{Vector, AbstractString}(Ok([])), "xx")
    
    # and_then
    @test and_then(x -> x + 1, Float64, Result{Float64, String}(Ok(5.0))) === Result{Float64, String}(Ok(6.0))
    @test and_then(x -> abs(x) % UInt8, UInt8, Result{Int, Dict}(Ok(-55))) === Result{UInt8, Dict}(Ok(UInt8(55)))
    @test and_then(x -> x + 1, Bool, Result{String, Int}(Err(1))) === Result{Bool, Int}(Err(1))
    @test and_then(x -> "foo", Dict, Result{Int, Int}(Err(1))) === Result{Dict, Int}(Err(1))
end

@testset "Option" begin
    # instantiation
    @test none(Int) isa Option{Int}
    @test !(none(Float32) isa Option{AbstractFloat})
    @test !(none(Int) isa Err)

    # Conversion from none
    @test convert(Option{Int}, none) isa Option{Int}
    @test convert(Option{Some{Nothing}}, none) isa Option{Some{Nothing}}
    @test_throws MethodError convert(Int, none)
    @test_throws MethodError convert(Option{String}, "foo")

    # Convert from Option
    @test convert(Option{Integer}, some(1)) isa Option{Integer}
    @test convert(Option{AbstractString}, none(String)) isa Option{AbstractString}
    @test convert(Option{Union{String, Dict}}, some("foo")) isa Option{Union{String, Dict}}
    @test convert(Option{Float64}, none(Float64)) isa Option{Float64}
    @test_throws MethodError convert(Option{String}, some(1))
    @test_throws MethodError convert(Option{String}, none(Int))

    # flatten
    @test flatten(some(some(11))) === some(11)
    @test flatten(some(some("foo"))) == some("foo")
    @test flatten(some(none(Float64))) == none(Float64)
    @test flatten(none(Option{Dict{Int, Int}})) == none(Dict{Int, Int})
    @test flatten(some(some(none(Int)))) == some(none(Int))
    @test_throws MethodError flatten(some(Result{Int, UInt}(Err(UInt(1)))))
    @test_throws MethodError flatten(Result{Option{Int}, Missing}(Ok(some(5))))
end

@testset "Result/Option conversion" begin
    # Construct Option from Result
    @test Option(Result{String, Int}(Ok("foo"))) == some("foo")
    @test Option(Result{String, Int}(Err(15))) == none(String)

    # Construct Result from Option
    @test Result(none(String), 0x01) == Result{String, UInt8}(Err(0x01))
    @test Result(some(0x1234), []) == Result{UInt16, Vector{Any}}(Ok(0x1234))
    @test Result(some(1), 2) == Result{Int, Int}(Ok(1))
end

@testset "@?" begin
    # Generic Option usage
    function testf1(x)::Option{typeof(x)}
        iszero(x) ? none : some(x + one(x))
    end

    function testf2(x)::Option{String}
        some(string(@? testf1(x)))
    end

    @test is_error(testf2(0))
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
    not_zero(x::Int)::Option{Int} = iszero(x) ? none : some(1 + x)

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

