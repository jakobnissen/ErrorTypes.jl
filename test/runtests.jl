using ErrorTypes
using Test

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

    # Errors if converting from different result type
    @test_throws MethodError convert(Result{Int, UInt}, Ok{Int, Int}(1))
    @test_throws MethodError convert(Result{Int, UInt}, Err{UInt, UInt}(UInt(1)))
    @test_throws MethodError convert(Result{Dict, Integer}, Ok{Bool, Int}(true))
    @test_throws MethodError convert(Result{Signed, String}, Err{Int, AbstractArray}([]))

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

    # unwrap_err
    @test unwrap_err(Err{String, UInt}(UInt(19))) == UInt(19)
    @test unwrap_err(Err{AbstractDict, String}("bar")) == "bar"
    @test_throws ErrorException unwrap_err(Ok{Int, Int}(1))
    @test_throws ErrorException unwrap_err(Ok{String, Int}("bar"))

    # expect_err
    @test expect_err(Err{Vector, AbstractString}("x"), "foo") == "x"
    @test expect_err(Err{Int, UInt8}(0xa4), "mistake!") == 0xa4
    @test_throws ErrorException expect_err(Ok{Int, UInt8}(15), "foobar")
    @test_throws ErrorException expect_err(Ok{Vector, AbstractString}([]), "xx")
    

    # and_then
    @test and_then(x -> x + 1, Float64, Ok{Float64, String}(5.0)) === Ok{Float64, String}(6.0)
    @test and_then(x -> abs(x) % UInt8, UInt8, Ok{Int, Dict}(-55)) === Ok{UInt8, Dict}(UInt8(55))
    @test and_then(x -> x + 1, Bool, Err{String, Int}(1)) === Err{Bool, Int}(1)
    @test and_then(x -> "foo", Dict, Err{Int, Int}(1)) === Err{Dict, Int}(1)
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
    @test_throws MethodError flatten(some(Err{Int, UInt}(UInt(1))))
    @test_throws MethodError flatten(Ok{Option{Int}, Missing}(some(5)))
end

@testset "Result/Option conversion" begin
    # Construct Option from Result
    @test Option(Ok{String, Int}("foo")) == some("foo")
    @test Option(Err{String, Int}(15)) == none(String)

    # Construct Result from Option
    @test Result(none(String), 0x01) == Err{String, UInt8}(0x01)
    @test Result(some(0x1234), []) == Ok{UInt16, Vector{Any}}(0x1234)
    @test Result(some(1), 2) == Ok{Int, Int}(1)
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

