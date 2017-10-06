#
# types.jl -
#
# Type definitions for Julia interface to ActiveSilicon Phoenix (PHX) library.
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

Concrete types derived from abstract type `CameraModel` are used to uniquely
identify the different camera models.

"""
abstract type CameraModel end

mutable struct Camera{M<:CameraModel}
    state::Int # 0 initially, 1 when camera open, 2 while acquiring
    handle::Handle
    bufs::Vector{Array{T,2}} where {T} # image buffers for acquisition
    vbufs::Vector{ImageBuff} # virtual buffers currently used
    #context::AcquisitionContext # context shared with acquisition callback
    timeout::UInt32 # time out (in ms) for reading/writing registers
    swap::Bool # swap bytes for read/write control connection?
    coaxpress::Bool # is it a CoaXPress camera?

    function Camera{M}(errorhandler::Ptr{Void} = _PHX_ErrHandlerDefault) where {M}
        # Create a new PHX handle structure.
        handle = Ref{Handle}(0)
        status = ccall(_PHX_Create, Status, (Ptr{Handle}, Ptr{Void}),
                       handle, errorhandler)
        status == PHX_OK || throw(PHXError(status))

        # Create the instance and attach the destroy callback.
        cam = new{M}(0, handle[],
                     Vector{Array{UInt8,2}}(0),
                     Vector{ImageBuff}(0),
                     #AcquisitionContext(),
                     500, false, false)
        finalizer(cam, _destroy)
        return cam
    end
end

# Custom exception to report errors.
struct PHXError <: Exception
   status::Status
end

"""

`Phoenix.Configuration` is a structure to store acquisition parameters.

For now, each acquisition buffer stores a single image (of size `roi_width` by
`roi_height` pixels).  All acquisition buffers have `buf_stride` bytes per line
and a number of lines greater of equal the height of the images.

The following fields are available:

- `roi_width`:  Width of ROI (in pixels, integer).
- `roi_height`: Height of ROI (in pixels, integer).
- `cam_depth`:  Bits per pixel of the camera (integer).
- `cam_xoff`:   Horizontal offset of ROI relative to detector (in pixels, integer).
- `cam_yoff`:   Vertical offset of ROI relative to detector (in pixels, integer).
- `buf_number`  Number of acquisition buffers (integer).
- `buf_xoff`:   Horizontal offset of ROI relative to buffer (in pixels, integer).
- `buf_yoff`:   Vertical offset of ROI relative to buffer (in pixels, integer).
- `buf_stride`: Bytes per line of an acquisition buffer (integer).
- `buf_height`: Number of lines in an acquisition buffer (integer).
- `buf_format`: Pixel format, *e.g.*, `PHX_DST_FORMAT_Y8` (integer).
- `fps`:        Acquisition frame rate (in Hz, real).
- `exposure`:   Exposure time (in seconds, real).
- `gain`:       Analog gain (real).
- `bias`:       Analog bias or black level (real).
- `gamma`:      Gamma correction (real).
- `blocking`:   Acquisition is blocking? (boolean)
- `continuous`: Acquisition is continuous? (boolean)

Note: *integer* and *real* means that field has respectively integer (`Int`)
and floating-point (`Float64`) value.

See also: [`setconfig!`](@ref), [`getconfig!`](@ref), [`fixconfig!`](@ref).

"""
mutable struct Configuration
    roi_width::Int
    roi_height::Int
    cam_depth::Int
    cam_xoff::Int
    cam_yoff::Int
    buf_number::Int
    buf_xoff::Int
    buf_yoff::Int
    buf_stride::Int
    buf_height::Int
    buf_format::Int
    fps::Float64
    exposure::Float64
    gain::Float64
    bias::Float64
    gamma::Float64
    blocking::Bool
    continuous::Bool
    function Configuration()
        new(typemax(Int), typemax(Int), 8, 0, 0,
            1, 0, 0, 0, 0, PHX_DST_FORMAT_Y8,
            20.0, 0.1, 1.0, 0.0, 1.0, false, false)
    end
end

struct Interval{T}
    # Bounds of the allowed interval.
    min::T
    max::T

    # Allowed increment (for floating point intervals, 0 means as small as
    # wanted).
    stp::T

    function Interval{T}(min::T, max::T, stp::T) where {T<:Integer}
        @assert min ≤ max
        @assert stp ≥ one(T)
        new{T}(min, max, stp)
    end

    function Interval{T}(min::T, max::T, stp::T) where {T<:AbstractFloat}
        @assert min ≤ max
        @assert stp ≥ zero(T)
        new{T}(min, max, stp)
    end
end

# Colors (FIXME: use Julia package ColorTypes at https://github.com/JuliaGraphics/ColorTypes.jl)

struct RGB{T}
    r::T
    g::T
    b::T
end
const RGB24 = RGB{UInt8}
const RGB48 = RGB{UInt16}
