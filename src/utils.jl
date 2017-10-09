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

const _DST_FORMATS = Dict(PHX_DST_FORMAT_Y8   => Monochrome{8},
                          PHX_DST_FORMAT_Y10  => Monochrome{10},
                          PHX_DST_FORMAT_Y12  => Monochrome{12},
                          # FIXME: PHX_DST_FORMAT_Y12B => 12,
                          PHX_DST_FORMAT_Y14  => Monochrome{14},
                          PHX_DST_FORMAT_Y16  => Monochrome{16},
                          PHX_DST_FORMAT_Y32  => Monochrome{32},
                          PHX_DST_FORMAT_Y36  => Monochrome{36},
                          PHX_DST_FORMAT_2Y12 => Monochrome{24},
                          PHX_DST_FORMAT_BAY8  => BayerFormat{ 8},
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

"""

`capture_format_bits(fmt)` yields the number of bits per pixel for the
destination buffer pixel format `fmt`, *e.g.* `PHX_DST_FORMAT_Y8`.

See also: [`best_capture_format`](@ref).

"""
capture_format_bits(format::Integer) :: Int =
    bitsperpixel(get(_DST_FORMATS, format, -1))

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
            error("Don't know how to interpret Bayer color format (0x$(hex(color)))")
        end
    else
        error("Unknown camera color format (0x$(hex(color)))")
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
function cstring(str::AbstractString, len::Integer = length(str)) :: Array{UInt8}
    buf = Array{UInt8}(len + 1)
    m = min(length(str), len)
    @inbounds for i in 1:m
        (c = str[i]) != '\0' || error("string must not have embedded NUL characters")
        buf[i] = c
    end
    @inbounds for i in m+1:len+1
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
    for str in split(cam[PHX_BOARD_PROPERTIES], '\n', keep = false)
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
