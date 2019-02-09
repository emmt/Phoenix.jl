#
# utils.jl -
#
# Implements utility methods for Julia interface to ActiveSilicon Phoenix (PHX)
# library.
#
#------------------------------------------------------------------------------
#
# This file is part of the `Phoenix.jl` package which is licensed under the MIT
# "Expat" License.
#
# Copyright (C) 2016, Éric Thiébaut & Jonathan Léger.
# Copyright (C) 2017, Éric Thiébaut.
#

function histogram(arr::AbstractArray{T,N}) where {T <: Integer, N}
    amin, amax = extrema(arr)
    cmin, cmax = Int(amin), Int(amax)
    off = 1 - cmin
    n = cmax + off
    y = zeros(Int, n)
    x = cmin:cmax
    @inbounds for v in arr
        i = off + Int(v)
        y[i] += 1
    end
    return (x, y)
end

"""
    fieldoffset(x::DataType, s::Symbol)

yields the byte offset of field `s` in structure `x`.  Beware that this is
slower than requested the offset by index.

"""
Base.fieldoffset(::Type{T}, s::Symbol) where {T} =
    fieldoffset(T, fieldindex(T, s))

"""
    fieldindex(x::DataType, s::Symbol)

yields the index of field `s` in structure `x`.

See also: [`nfields`](@ref), [`fieldname`](@ref), [`fieldoffset`](@ref).

"""
function fieldindex(::Type{T}, s::Symbol) where {T}
    for i in 1:nfields(T)
        if fieldname(T, i) == s
            return i
        end
    end
    throw(ArgumentError("type `$T` has no field `$s`"))
end

const _DST_FORMATS = Dict(PHX_DST_FORMAT_Y8   => Monochrome{8},
                          PHX_DST_FORMAT_Y10  => Monochrome{10},
                          PHX_DST_FORMAT_Y12  => Monochrome{12},
                          # FIXME: PHX_DST_FORMAT_Y12B => 12,
                          PHX_DST_FORMAT_Y14  => Monochrome{14},
                          PHX_DST_FORMAT_Y16  => Monochrome{16},
                          PHX_DST_FORMAT_Y32  => Monochrome{32},
                          PHX_DST_FORMAT_Y36  => Monochrome{36},
                          PHX_DST_FORMAT_2Y12 => Monochrome{24},
                          PHX_DST_FORMAT_BAY8  => BayerFormat{8},
                          PHX_DST_FORMAT_BAY10 => BayerFormat{10},
                          PHX_DST_FORMAT_BAY12 => BayerFormat{12},
                          PHX_DST_FORMAT_BAY14 => BayerFormat{14},
                          PHX_DST_FORMAT_BAY16 => BayerFormat{16},
                          PHX_DST_FORMAT_RGB15 => RGB{15},
                          PHX_DST_FORMAT_RGB16 => RGB{16},
                          PHX_DST_FORMAT_RGB24 => RGB{24},
                          PHX_DST_FORMAT_RGB32 => RGB{32},
                          PHX_DST_FORMAT_RGB36 => RGB{36},
                          PHX_DST_FORMAT_RGB48 => RGB{48},
                          PHX_DST_FORMAT_BGR15 => BGR{15},
                          PHX_DST_FORMAT_BGR16 => BGR{16},
                          PHX_DST_FORMAT_BGR24 => BGR{24},
                          PHX_DST_FORMAT_BGR32 => BGR{32},
                          PHX_DST_FORMAT_BGR36 => BGR{36},
                          PHX_DST_FORMAT_BGR48 => BGR{48},
                          PHX_DST_FORMAT_BGRX32 => BGRX{32},
                          PHX_DST_FORMAT_RGBX32 => RGBX{32},
                          # FIXME: PHX_DST_FORMAT_RRGGBB8 => 8,
                          PHX_DST_FORMAT_XBGR32 => XBGR{32},
                          PHX_DST_FORMAT_XRGB32 => XRGB{32},
                          PHX_DST_FORMAT_YUV422 => YUV422)

const CAPTURE_FORMATS = Union{Monochrome{8},
                              Monochrome{10},
                              Monochrome{12},
                              Monochrome{14},
                              Monochrome{16},
                              Monochrome{32},
                              Monochrome{36},
                              Monochrome{24},
                              BayerFormat{8},
                              BayerFormat{10},
                              BayerFormat{12},
                              BayerFormat{14},
                              BayerFormat{16},
                              RGB{15},
                              RGB{16},
                              RGB{24},
                              RGB{32},
                              RGB{36},
                              RGB{48},
                              BGR{15},
                              BGR{16},
                              BGR{24},
                              BGR{32},
                              BGR{36},
                              BGR{48},
                              BGRX{32},
                              RGBX{32},
                              XBGR{32},
                              XRGB{32},
                              YUV422}

"""

    capture_format(fmt) -> pix

yields the pixel format corresponding to the destination buffer pixel format
`fmt`, and conversely:

    capture_format(pix) -> fmt

For instance:

    capture_format(PHX_DST_FORMAT_Y8) -> Monochrome{8}
    capture_format(Monochrome{8}) -> PHX_DST_FORMAT_Y8


See also: [`best_capture_format`](@ref), [`capture_format_bits`](@ref).

"""
function capture_format(fmt::Integer)
    if haskey(_DST_FORMATS, fmt)
        return getindex(_DST_FORMATS, fmt)
    end
    throw(ArgumentError("unknown capture pixel format"))
end

capture_format(::Type{T}) where {T<:Monochrome{8}} = PHX_DST_FORMAT_Y8
capture_format(::Type{T}) where {T<:Monochrome{10}} = PHX_DST_FORMAT_Y10
capture_format(::Type{T}) where {T<:Monochrome{12}} = PHX_DST_FORMAT_Y12
# FIXME: PHX_DST_FORMAT_Y12B
capture_format(::Type{T}) where {T<:Monochrome{14}} = PHX_DST_FORMAT_Y14
capture_format(::Type{T}) where {T<:Monochrome{16}} = PHX_DST_FORMAT_Y16
capture_format(::Type{T}) where {T<:Monochrome{32}} = PHX_DST_FORMAT_Y32
capture_format(::Type{T}) where {T<:Monochrome{36}} = PHX_DST_FORMAT_Y36
capture_format(::Type{T}) where {T<:Monochrome{24}} = PHX_DST_FORMAT_2Y12
capture_format(::Type{T}) where {T<:BayerFormat{8}} = PHX_DST_FORMAT_BAY8
capture_format(::Type{T}) where {T<:BayerFormat{10}} = PHX_DST_FORMAT_BAY10
capture_format(::Type{T}) where {T<:BayerFormat{12}} = PHX_DST_FORMAT_BAY12
capture_format(::Type{T}) where {T<:BayerFormat{14}} = PHX_DST_FORMAT_BAY14
capture_format(::Type{T}) where {T<:BayerFormat{16}} = PHX_DST_FORMAT_BAY16
capture_format(::Type{T}) where {T<:RGB{15}} = PHX_DST_FORMAT_RGB15
capture_format(::Type{T}) where {T<:RGB{16}} = PHX_DST_FORMAT_RGB16
capture_format(::Type{T}) where {T<:RGB{24}} = PHX_DST_FORMAT_RGB24
capture_format(::Type{T}) where {T<:RGB{32}} = PHX_DST_FORMAT_RGB32
capture_format(::Type{T}) where {T<:RGB{36}} = PHX_DST_FORMAT_RGB36
capture_format(::Type{T}) where {T<:RGB{48}} = PHX_DST_FORMAT_RGB48
capture_format(::Type{T}) where {T<:BGR{15}} = PHX_DST_FORMAT_BGR15
capture_format(::Type{T}) where {T<:BGR{16}} = PHX_DST_FORMAT_BGR16
capture_format(::Type{T}) where {T<:BGR{24}} = PHX_DST_FORMAT_BGR24
capture_format(::Type{T}) where {T<:BGR{32}} = PHX_DST_FORMAT_BGR32
capture_format(::Type{T}) where {T<:BGR{36}} = PHX_DST_FORMAT_BGR36
capture_format(::Type{T}) where {T<:BGR{48}} = PHX_DST_FORMAT_BGR48
capture_format(::Type{T}) where {T<:BGRX{32}} = PHX_DST_FORMAT_BGRX32
capture_format(::Type{T}) where {T<:RGBX{32}} = PHX_DST_FORMAT_RGBX32
# FIXME: PHX_DST_FORMAT_RRGGBB8
capture_format(::Type{T}) where {T<:XBGR{32}} = PHX_DST_FORMAT_XBGR32
capture_format(::Type{T}) where {T<:XRGB{32}} = PHX_DST_FORMAT_XRGB32
capture_format(::Type{T}) where {T<:YUV422} = PHX_DST_FORMAT_YUV422
capture_format(::Type{T}) where {T<:PixelFormat} = ParamValue(0)


"""

`capture_format_bits(fmt)` yields the number of bits per pixel for the
destination buffer pixel format `fmt`, *e.g.* `PHX_DST_FORMAT_Y8`.

See also: [`best_capture_format`](@ref).

"""
capture_format_bits(fmt::Integer) :: Int =
    (haskey(_DST_FORMATS, fmt) ?
     bitsperpixel(getindex(_DST_FORMATS, fmt)) : -1)

"""

    best_capture_format(cam) -> (T, pixelformat)

yields the Julia pixel type `T` and Phoenix pixel format `pixelformat` for the
destination image buffer(s) which are as close as possible as that of the
source image buffer(s) for camera `cam`.  The value of `T` can be used to
allocate a Julia array while `pixelformat` can be used to set
`cam[PHX_DST_FORMAT]`.

The method can also be called with the color format (`cam[PHX_CAM_SRC_COL]`)
and the number of bits per pixel (`cam[PHX_CAM_SRC_DEPTH]`) of the camera:

    best_capture_format(color, depth) -> (T, pixelformat)

See also: [`capture_format_bits`](@ref).

"""
best_capture_format(cam::Camera) =
    best_capture_format(cam[PHX_CAM_SRC_COL], cam[PHX_CAM_SRC_DEPTH])

function best_capture_format(color::Integer, depth::Integer)
    local T::DataType, format::ParamValue
    if color == PHX_CAM_SRC_MONO
        if depth ≤ 8
            T, format = UInt8, PHX_DST_FORMAT_Y8
        elseif depth ≤ 16
            T, format = UInt16, PHX_DST_FORMAT_Y16
        elseif depth ≤ 32
            T, format = UInt32, PHX_DST_FORMAT_Y32
        else
            error("Unsupported monochrome camera depth $(Int(depth))")
        end
    elseif color == PHX_CAM_SRC_YUV422
        T, format = YUV422BitsType, PHX_DST_FORMAT_YUV422
    elseif color == PHX_CAM_SRC_RGB
        if depth == 8
            T, format = RGB24BitsType, PHX_DST_FORMAT_RGB24
        elseif depth == 16
            T, format = RGB48BitsType, PHX_DST_FORMAT_RGB48
        else
            error("Unsupported RGB camera depth $(Int(depth))")
        end
    elseif (color == PHX_CAM_SRC_BAY_RGGB || color == PHX_CAM_SRC_BAY_GRBG ||
            color == PHX_CAM_SRC_BAY_GBRG || color == PHX_CAM_SRC_BAY_BGGR)
        if depth ≤ 8
            T, format = UInt8, PHX_DST_FORMAT_BAY8
        elseif depth ≤ 16
            T, format = UInt16, PHX_DST_FORMAT_BAY16
        else
            error("Don't know how to interpret Bayer color format (0x$(string(color, base=16)))")
        end
    else
        error("Unknown camera color format (0x$(string(color, base=16)))")
    end
    @assert sizeof(T)*8 == capture_format_bits(format)
    return T, format
end


"""

    cstring(str, len = strlen(str))

yields a vector of bytes (`UInt8`) with the contents of the string `str` and
properly zero-terminated.  This buffer is independent from the input string and
its contents can be overwritten.  An error is thrown if `str` contains any
embedded NUL characters (which would cause the string to be silently truncated
if the C routine treats NUL as the terminator).

An alternative (without the checking of embedded NUL characters) is:

    push!(convert(Vector{UInt8}, str), convert(UInt8, 0))

"""
function cstring(str::AbstractString,
                 len::Integer = length(str)) :: Array{UInt8}
    buf = Array{UInt8}(undef, len + 1)
    i = 0
    @inbounds for c in str
        if i ≥ len
            break
        end
        c != '\0' || error("string must not have embedded NUL characters")
        i += 1
        buf[i] = c
    end
    @inbounds while i ≤ len
        i += 1
        buf[i] = zero(UInt8)
    end
    return buf
end


function Base.summary(cam::Camera)

    # Get hardware revision.
    @printf("Hardware revision:       %.2x:%.2x:%.2x\n",
            cam[PHX_REV_HW_MAJOR],
            cam[PHX_REV_HW_MINOR],
            cam[PHX_REV_HW_SUBMINOR])

    # Get software revision.
    @printf("Software revision:       %.2x:%.2x:%.2x\n",
            cam[PHX_REV_SW_MAJOR],
            cam[PHX_REV_SW_MINOR],
            cam[PHX_REV_SW_SUBMINOR])

    # Get the board properties.
    println("Board properties:")
    for str in split(cam[PHX_BOARD_PROPERTIES], '\n', keepempty = false)
        println("    ", str)
    end

    # CoaXPress camera?
    @printf("CoaXPress camera:         %s\n",
            (is_coaxpress(cam) ? "true" : "false"))
    if is_coaxpress(cam)

    end

   @printf("Camera active xoffset:    %4d\n",
           Int(cam[PHX_CAM_ACTIVE_XOFFSET]))
   @printf("Camera active yoffset:    %4d\n",
           Int(cam[PHX_CAM_ACTIVE_YOFFSET]))
   @printf("Camera active xlength:    %4d\n",
           Int(cam[PHX_CAM_ACTIVE_XLENGTH]))
   @printf("Camera active ylength:    %4d\n",
           Int(cam[PHX_CAM_ACTIVE_YLENGTH]))

end

"""

`is_coaxpress(cam)` yields whether Phoenix camara `cam` is a CoaXPress
controlled camera.

See also: [`Phoenix.Camera`](@ref), [`Phoenix.assert_coaxpress`](@ref).

"""
is_coaxpress(cam::Camera) = cam.coaxpress

"""

`assert_coaxpress(cam)` checks whether Phoenix camara `cam` is a CoaXPress
controlled camera and throw an error otherwise.

See also: [`Phoenix.is_coaxpress`](@ref).

"""
function assert_coaxpress(cam::Camera)
    if is_coaxpress(cam)
        magic = cam[CXP_STANDARD]
        if magic != CXP_MAGIC
            if magic == bswap(CXP_MAGIC)
                error("bad byte swapping flag")
            else
                error("unexpected magic number for CoaXPress camera")
            end
        end
    else
        error("not a CoaXPress camera")
    end
    return nothing
end

getvendorname(cam::Camera) =
    is_coaxpress(cam) ? cam[CXP_DEVICE_VENDOR_NAME] : ""

getmodelname(cam::Camera) =
    is_coaxpress(cam) ? cam[CXP_DEVICE_MODEL_NAME] : ""

getdevicemanufacturer(cam::Camera) =
    is_coaxpress(cam) ? cam[CXP_DEVICE_MANUFACTURER_INFO] : ""

getdeviceversion(cam::Camera) =
    is_coaxpress(cam) ? cam[CXP_DEVICE_VERSION] : ""

getdeviceserialnumber(cam::Camera) =
    is_coaxpress(cam) ? cam[CXP_DEVICE_SERIAL_NUMBER] : ""

getdeviceuserid(cam::Camera) =
    is_coaxpress(cam) ? cam[CXP_DEVICE_USER_ID] : ""

subsampling_parameter(sub::Integer) =
    (sub == 1 ? PHX_ACQ_X1 :
     sub == 2 ? PHX_ACQ_X2 :
     sub == 4 ? PHX_ACQ_X4 :
     sub == 8 ? PHX_ACQ_X8 :
     error("unsupported horizontal subsampling ratio"))

"""

    gettimeofday()

yields the current time since the epoch as a `TimeVal` structure.
To convert it in seconds, just convert the result into a float:

    float(gettimeofday())

which yields the is the same as

"""
function gettimeofday()
    tvref = Ref{TimeVal}()
    status = ccall(:gettimeofday, Cint, (Ptr{TimeVal}, Ptr{Nothing}),
                   tvref, C_NULL)
    status == SUCCESS || error("gettimeofday failed")
    return tvref[]
end


TimeVal(sec::Real) = TimeVal(convert(Float64, sec))
TimeVal(sec::Integer) = TimeVal(sec, 0)
TimeVal(tv::TimeVal) = tv
function TimeVal(ts::TimeSpec)
    µs, ns = divrem(ts.nsec, 1_000)
    s, µs = divrem(µs + (ns ≥ 500 ? 1 : 0), 1_000_000)
    return TimeVal(ts.sec + s, µs)
end
function TimeVal(sec::Float64)
    if isfinite(sec)
        s = trunc(Int, sec)
        µs = round(Int, (sec - s)*1_000_000)
        if µs ≥ 1_000_000
            d, µs = divrem(µs, 1_000_000)
            s += d
        end
        return TimeVal(s, µs)
    elseif isinf(sec)
        return TimeVal(sec == Inf ? typemax(_typeof_tv_sec) :
                        typemin(_typeof_tv_sec), 0)
    else
        throw(DomainError())
    end
end
#Base.convert(::Type{TimeVal}, x) = TimeVal(x)
Base.float(tv::TimeVal) = (convert(Float64, tv.sec) +
                           convert(Float64, tv.usec)*1E-6)

"""

    TimeSpec(s [, ns])

yields a `TimeSpec` value for `s` seconds and `ns` nanoseconds.  If both `s`
and `ns` are specified, they must be integres; otherwise, `s` can be a
fractional number of seconds.  For instance:

    TimeSpec(time() + 10.3)

yields a `TimeSpec` instance for `10.3` seconds later.  Use the `float` method
to convert a `TimeSpec` value in a floating-point value in seconds.

"""
TimeSpec(sec::Real) = TimeSpec(convert(Float64, sec))
TimeSpec(sec::Integer) = TimeSpec(sec, 0)
TimeSpec(tv::TimeVal) = TimeSpec(tv.sec, tv.usec*1_000)
TimeSpec(ts::TimeSpec) = ts
function TimeSpec(sec::Float64)
    if isfinite(sec)
        s = trunc(Int, sec)
        ns = round(Int, (sec - s)*1_000_000_000)
        if ns ≥ 1_000_000_000
            d, ns = divrem(ns, 1_000_000_000)
            s += d
        end
        return TimeSpec(s, ns)
    elseif isinf(sec)
        return TimeSpec(sec == Inf ? typemax(_typeof_tv_sec) :
                        typemin(_typeof_tv_sec), 0)
    else
        throw(DomainError())
    end
end
#Base.convert(::Type{TimeSpec}, x) = TimeSpec(x)
Base.float(ts::TimeSpec) = (convert(Float64, ts.sec) +
                            convert(Float64, ts.nsec)*1E-9)



#function Base.(+)(ts::TimeSpec, tv::TimeVal)
#    sec, nsec = divrem(ts.nsec + 1_000*tv.usec, 1_000_000_000)
#    sec += ts.sec + tv.sec
#    return TimeSpec(sec, nsec)
#end
#
#Base.(+)(tv::TimeVal, ts::TimeSpec) = ts + tv

"""
    isforever(ts)

yeilds whether the time specified `ts` should be consider as being forever,
that is in a quasi-infinite future (due to the finite precision, this is
more than 292.3 billions years).

"""
isforever(ts::TimeSpec) = (ts.sec ≥ typemax(_typeof_tv_sec))
