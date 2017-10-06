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

"""

    setconfig!(cfg, cam) -> cfg

or

    setconfig!(cam, cfg) -> cfg

apply the settings in configuration `cfg` to the camera `cam`.  The
configuration is returned, possibly modified to reflect the actual settings.

See also: [`getconfig!`](@ref), [`Phoenix.Configuration`](@ref),
[`fixconfig!`](@ref).

"""
setconfig!(cfg::Configuration, cam::Camera) =
    error("method `setconfig!` is not available for this camera model")

setconfig!(cam::Camera, cfg::Configuration) =
    setconfig!(cfg, cam)

"""

    getconfig!(cfg, cam) -> cfg

or

    getconfig!(cam, cfg) -> cfg

or

    getconfig!(cam) -> cfg

yield the actual configuration settings of the camera `cam`.  If provided,
argument `cfg` is udated.  This routine may fix inconsistencies in the camera
settings, this is why the method is called `getconfig!` in all the cases (not
`getconfig`).  The returned configuration reflects the actual settings of the
camera.

See also: [`setconfig!`](@ref), [`Phoenix.Configuration`](@ref),
[`fixconfig!`](@ref).

"""
getconfig!(cfg::Configuration, cam::Camera) =
    error("method `getconfig!` is not available for this camera model")

getconfig!(cam::Camera) =
    getconfig!(Configuration(), cam)

getconfig!(cam::Camera, cfg::Configuration) =
    getconfig!(cfg, cam)

"""
    getfullwidth(cam)  -> fullwidth
    getfullheight(cam) -> fullheight
    getfullsize(cam)   -> (fullwidth, fullheight)

respectively yield the maximum width, height and size for the images captured
by the camera `cam`.  Note that these values may be underestimated or incorrect
if improper parameters have been set.  These methods may be overridden for
specific camera models to give robust results.

See also: [`fixconfig!`](@ref).

"""
getfullwidth(cam::Camera) =
    Int(cam[PHX_CAM_ACTIVE_XOFFSET]) + Int(cam[PHX_CAM_ACTIVE_XLENGTH])

getfullheight(cam::Camera) =
    Int(cam[PHX_CAM_ACTIVE_YOFFSET]) + Int(cam[PHX_CAM_ACTIVE_YLENGTH])

fullsize(cam::Camera) =
    (getfullwidth(cam), getfullheight(cam))

@doc @doc(getfullwidth) getfullheight
@doc @doc(getfullwidth) getfullsize


"""

    fixroi(off, len, dim) -> flags, off, len

fixes region of interest (ROI) offset `off` and length `len` so as to best fit
in the range `[0,dim-1]`.  Bits in returned `flags` indicates which fixes have
been applied (first bit is set if ROI has been clipped, second bit is set if
ROI was empty, third bit is set if lengh of ROI was less than 1).

See also: [`fixconfig!`](@ref).

"""
function fixroi(off::Int, len::Int, dim::Int)
    @assert dim ≥ 1
    flags = 0
    if len < 1
        # Fix too small length.
        flags |= 4
        len = 1
    end
    if off ≥ dim
        # Fix empty region.
        flags |= 2
        off = dim - 1
        len = 1
    elseif off + len ≤ 0
        # Fix empty region.
        flags |= 2
        off = 0
        len = 1
     else
        # Clip overlapping region as needed.
        if off < 0
            flags |= 1
            len += off
            off = 0
        end
        if off + len > dim
            flags |= 1
            len = dim - off
        end
    end
    return flags, off, len
end

"""

    fixbuf(off, len, dim) -> flags, off, len

fixes buffer offset `off` and length `len` so as to make sure that a ROI of
length `dim` fit into the buffer.  If any settings need to be fixed, it is
attempted to avoid growing the size of the buffer.  Bits in returned `flags`
indicates which fixes have been applied (first bit is set if offset was
changed, second bit is set if length was too small).

See also: [`fixconfig!`](@ref).

"""
function fixbuf(off::Int, len::Int, dim::Int)
    @assert dim ≥ 1
    flags = 0
    if off < 0
        # Fix too small offset.
        flags |= 1
        off = 0
    end
    if dim > len
        # Fix too small length.
        flags |= 2
        len = dim
    end
    if off + dim > len
        # Fix too large offset.
        flags |= 1
        off = len - dim
    end
    return flags, off, len
end

"""
The calls:

    fixconfig!(cfg, fullwidth, fullheight) -> cfg

or

    fixconfig!(cfg, fullsize) -> cfg

fix configuration settings in `cfg`, taking into account the full size of the
detector provided by `fullsize = (fullwidth, fullheight)` in pixels.  The
updated configuration is returned.  If any settings need to be fixed, it is
attempted to avoid growing the size of the image buffers and to keep a
consistent region of interest (ROI).

Keyword `quiet` can be set `true` (default is `false`) to avoid signaling the
fixes made.

Keyword `shrink` can be set `true` (default is `false`) to (silently) shrink
the image buffers to their minimal size.

The call:

    fixconfig!(cfg, cam)

where `cam` is a camera instance is identical to:

    fixconfig!(cfg, getfullsize(cam))

See also: [`setconfig!`](@ref), [`Phoenix.Configuration`](@ref),
[`getfullsize`](@ref).

"""
function fixconfig!(cfg::Configuration, fullsize::NTuple{2,Int};
                    quiet::Bool = false, shrink::Bool = false)
    # Make sure max. dimensions are correct.
    @assert fullsize[1] ≥ 1 && fullsize[2] ≥ 1
    fullwidth, fullheight = fullsize

    # Before making any changes, check buffer format.
    bits = capture_format_bits(cfg.buf_format)
    bits ≤ 0 && error("invalid (or unknown) buffer format")

    # First, fix dimensions and offsets of the region of interest (ROI).  This
    # is done by clipping the ROI to the sensor dimensions or by using a
    # dimension of one pixel at the nearest edge if the intersection is empty.
    xflags, xoff, width  = fixroi(cfg.cam_xoff, cfg.roi_width,  fullwidth)
    yflags, yoff, height = fixroi(cfg.cam_yoff, cfg.roi_height, fullheight)
    if ! quiet && (xflags|yflags) != 0
        flags = (xflags|yflags)
        (flags&4) == 0 || warn("too small ROI has been fixed")
        (flags&2) == 0 || warn("empty ROI has been fixed")
        (flags&1) == 0 || warn("ROI has been clipped")
    end
    cfg.roi_width = width
    cfg.roi_height = height
    cfg.cam_xoff = xoff
    cfg.cam_yoff = yoff

    # Second, fix buffer settings.
    if cfg.buf_number < 1
        cfg.buf_number = 1
        quiet || warn("number of buffers has been fixed")
    end
    if shrink
        # Use as few memory as possible.
        cfg.buf_xoff   = 0
        cfg.buf_yoff   = 0
        cfg.buf_stride = div(width*bits + 7, 8)
        cfg.buf_height = height
    else
        buf_xoff   = cfg.buf_xoff
        buf_yoff   = cfg.buf_yoff
        buf_width  = div(cfg.buf_stride*8, bits)
        buf_height = cfg.buf_height
        xflags, buf_xoff, buf_width  = fixbuf(buf_xoff, buf_width,  width)
        yflags, buf_yoff, buf_height = fixbuf(buf_yoff, buf_height, height)
        if ! quiet && (xflags|yflags) != 0
            flags = (xflags|yflags)
            (flags&1) == 0 || warn("buffer offset(s) have been fixed")
            (flags&2) == 0 || warn("buffer dimension(s) were too small")
        end
        cfg.buf_xoff   = buf_xoff
        cfg.buf_yoff   = buf_yoff
        cfg.buf_stride = div(buf_width*bits + 7, 8)
        cfg.buf_height = buf_height
    end

    return cfg
end

fixconfig!(cfg::Configuration, cam::Camera; kwds...) =
    fixconfig!(cfg, getfullsize(cam); kwds...)

fixconfig!(cfg::Configuration, fullwidth::Integer, fullheight::Integer; kwds...) =
    fixconfig!(cfg, (convert(Int, fullwidth), convert(Int, fullheight)); kwds...)

Interval(::Type{T}, min::Real, max::Real) where {T<:Real} =
    Interval(convert(T, min), convert(T, max))

Interval(::Type{T}, min::Real, max::Real, stp::Real) where {T<:Real} =
    Interval(convert(T, min), convert(T, max), convert(T, stp))

Interval(min::T, max::T) where {T<:Integer} =
    Interval{T}(min, max, one(T))

Interval(min::T, max::T) where {T<:AbstractFloat} =
    Interval{T}(min, max, zero(T))

Interval(min::A, max::B) where {A<:Real,B<:Real} =
    (T = promote_type(A, B);
     Interval(convert(T, min), convert(T, max)))

Interval(min::A, max::B, stp::C) where {A<:Real,B<:Real,C<:Real} =
    (T = promote_type(A, B, C);
     Interval(convert(T, min), convert(T, max), convert(T, stp)))

restrict(val, I::Interval{T}) where {T<:Integer} =
    clamp((I.stp == one(T) ? round(T, val) : round(T, val/I.stp))*I.stp,
          I.min, I.max)

restrict(val, I::Interval{T}) where {T<:AbstractFloat} =
    clamp((I.stp == zero(T) ? convert(T, val) : round(convert(T, val/I.stp), 0))*I.stp,
          I.min, I.max)

const _DST_FORMAT_BITS = Dict{ParamValue,Int}(PHX_DST_FORMAT_Y8   =>  8,
                                              PHX_DST_FORMAT_Y10  => 10,
                                              PHX_DST_FORMAT_Y12  => 12,
                                              # FIXME: PHX_DST_FORMAT_Y12B => 12,
                                              PHX_DST_FORMAT_Y14  => 14,
                                              PHX_DST_FORMAT_Y16  => 16,
                                              PHX_DST_FORMAT_Y32  => 32,
                                              PHX_DST_FORMAT_Y36  => 36,
                                              PHX_DST_FORMAT_2Y12 => 24,
                                              PHX_DST_FORMAT_BAY8  =>  8,
                                              PHX_DST_FORMAT_BAY10 => 10,
                                              PHX_DST_FORMAT_BAY12 => 12,
                                              PHX_DST_FORMAT_BAY14 => 14,
                                              PHX_DST_FORMAT_BAY16 => 16,
                                              PHX_DST_FORMAT_RGB15 => 15,
                                              PHX_DST_FORMAT_RGB16 => 16,
                                              PHX_DST_FORMAT_RGB24 => 24,
                                              PHX_DST_FORMAT_RGB32 => 32,
                                              PHX_DST_FORMAT_RGB36 => 36,
                                              PHX_DST_FORMAT_RGB48 => 48,
                                              PHX_DST_FORMAT_BGR15 => 15,
                                              PHX_DST_FORMAT_BGR16 => 16,
                                              PHX_DST_FORMAT_BGR24 => 24,
                                              PHX_DST_FORMAT_BGR32 => 32,
                                              PHX_DST_FORMAT_BGR36 => 36,
                                              PHX_DST_FORMAT_BGR48 => 48,
                                              PHX_DST_FORMAT_BGRX32 => 32,
                                              PHX_DST_FORMAT_RGBX32 => 32,
                                              # FIXME: PHX_DST_FORMAT_RRGGBB8 => 8,
                                              PHX_DST_FORMAT_XBGR32 => 32,
                                              PHX_DST_FORMAT_XRGB32 => 32,
                                              PHX_DST_FORMAT_YUV422 => 16)
"""

`capture_format_bits(fmt)` yields the number of bits for the destination buffer
pixel format `fmt`, *e.g.* `PHX_DST_FORMAT_Y8`.

See also: [`best_capture_format`](@ref).

"""
capture_format_bits(format::Integer) :: Int =
    get(_DST_FORMAT_BITS, format, -1)

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
            T, format = UInt16, PHX_DST_FORMAT_Y32
        else
            error("Unsupported monochrome camera depth $(Int(depth))")
        end
    elseif color == PHX_CAM_SRC_YUV422
        T, format = UInt16, PHX_DST_FORMAT_YUV422
    elseif color == PHX_CAM_SRC_RGB
        if depth == 8
            T, format = RGB24, PHX_DST_FORMAT_RGB24
        elseif depth == 16
            T, format = RGB48, PHX_DST_FORMAT_RGB48
        else
            error("Unsupported RGB camera depth $(Int(depth))")
        end
    elseif (color == PHX_CAM_SRC_BAY_RGGB || color == PHX_CAM_SRC_BAY_GRBG ||
            color == PHX_CAM_SRC_BAY_GBRG || color == PHX_CAM_SRC_BAY_BGGR)
        error("Don't know how to interpret Bayer color format (0x$(hex(color)))")
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
