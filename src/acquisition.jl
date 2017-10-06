#
# acquistion.jl -
#
# Implements acquistion of images for Julia interface to ActiveSilicon Phoenix
# (PHX) library.
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

    acquire(cam, [T, ] n=1) -> imgs

yields a vector of `n` image(s) acquired by the camera `cam`.  Optional arguemnt `T`
is the pixel type of the image(s).

See also: [`start`](@ref).

"""
function acquire(cam::Camera, ::Type{T}, nbufs::Int) where {T}
    # Allocate image buffers and instruct the frame grabber to use them.
    nbufs ≥ 1 || throw(ArgumentError("invalid number of image buffers"))
    setbuffers!(cam, T, nbufs)

    error("not yet implemented!")
end

acquire(cam::Camera, ::Type{T}, nbufs::Integer) where {T} =
    acquire(cam, T, convert(Int, nbufs))

function acquire(cam::Camera, nbufs::Integer = 1)
    T, format = best_capture_format(cam)
    cam[PHX_DST_FORMAT] = format
    acquire(cam, T, nbufs)
end

"""

    start(cam, T, nbufs=1) -> bufs

starts acquisition of images by the camera `cam`.  This method allocates `nbufs`
image buffers of pixel type `T` for the acquisition and returns these buffers as a
vector of 2D arrays of elemnt type `T`.

Some methods can be used to retrieve infromation about the image buffers:
- `lenght(cam)` yields the number of image buffers;
- `eltype(cam)` yields the pixel type of the image buffers;
- `cam[i]`, with `i` integer, yields the `i`-th image buffer (a 2D array);

See also: [`stop`](@ref).

"""
Base.start(cam::Camera, ::Type{T}, nbufs::Integer) where {T} =
    start(cam, T, convert(Int, nbufs))

function Base.start(cam::Camera, nbufs::Integer) where {T} =
    T, format = best_capture_format(cam)
    cam[PHX_DST_FORMAT] = format
    start(cam, T, nbufs)
end

function Base.start(cam::Camera, ::Type{T}, nbufs::Int = 2) where {T}
    # Allocate image buffers and instruct the frame grabber to use them.
    nbufs ≥ 1 || throw(ArgumentError("invalid number of image buffers"))
    setbuffers!(cam, T, nbufs)

    # Enable interrupts for expected events and setup callback context.
    cam[PHX_INTRPT_CLR]    = ~zero(ParamValue)
    cam[PHX_INTRPT_SET]    = (PHX_INTRPT_GLOBAL_ENABLE|
                              PHX_INTRPT_FIFO_OVERFLOW|
                              PHX_INTRPT_BUFFER_READY)
    cam[PHX_EVENT_CONTEXT] = C_NULL # cam.context.handle

    # Start acquisition with given callback.
    readstream(cam, PHX_START, _callback_ptr[])

    # Send specific start command, aborting acquisition in case of errors.
    try
        _starthook(cam)
    catch err
        readstream(cam, PHX_ABORT, _callback_ptr[])
        readstream(cam, PHX_UNLOCK, C_NULL)
        rethrow(err)
    end

    # Update state and return the acquisition buffers.
    cam.state = 2
    return cam.bufs

end

setbuffers!(cam::Camera, ::Type{T}, nbufs::Integer) where {T} =
    setbuffers!(cam, T, convert(Int, nbufs))

function setbuffers!(cam::Camera, nbufs::Integer = 1)
    T, format = best_capture_format(cam)
    cam[PHX_DST_FORMAT] = format
    setbuffers!(cam, T, nbufs)
end

# FIXME: benchmark this to see whether it is worth avoiding recreating the virtual buffers.
function setbuffers!(cam::Camera, ::Type{T}, nbufs::Int) where {T}
    if cam.state != 1
        if cam.state == 0
            error("camera must be open")
        elseif cam.state == 2
            error("acquisition must not be running")
        else
            error("camera instance corrupted")
        end
    end
    if nbufs > 0
        # Figure out buffer size.
        width  = Int(cam[PHX_ROI_XLENGTH])
        height = Int(cam[PHX_ROI_YLENGTH])
        if width < 1 || height < 1
            error("invalid ROI dimension(s) (`PHX_ROI_XLENGTH`, `PHX_ROI_YLENGTH`)")
        end
        dstbits = capture_format_bits(cam[PHX_DST_FORMAT])
        if dstbits ≤ 0
            error("invalid capture pixel format (`PHX_DST_FORMAT`)")
        end
        arrbits = sizeof(T)*8
        if arrbits != dstbits
            warn("Capture format does not exactly fit in chosen pixel type")
        end
        width = div(width*dstbits + arrbits - 1, arrbits) # roundup array width
        cam[PHX_ROI_DST_XOFFSET] = 0
        cam[PHX_ROI_DST_YOFFSET] = 0
        cam[PHX_BUF_DST_XLENGTH] = width*sizeof(T)
        cam[PHX_BUF_DST_YLENGTH] = height
    elseif nbufs == 0
        width = 0
        height = 0
    else
        throw(ArgumentError("invalid number of image buffers"))
    end
    bufs = [zeros(T, width, height) for i in 1:nbufs]
    vbufs = [i ≤ nbufs ?
             ImageBuff(pointer(bufs[i]), Ptr{Void}(i)) :
             ImageBuff(C_NULL, C_NULL) for i in 1:nbufs+1]

    # Instruct Phoenix to use the virtual buffers. The PHX_CACHE_FLUSH here is
    # to make sure that the new buffers do replace the old ones, if any, before
    # they may be claimed by the garbage collector.  (FIXME: I am not sure
    # whetherv this is really needed and I do not known the effects of the
    # PHX_FORCE_REWRITE flag.)
    cam[PHX_ACQ_NUM_BUFFERS] = nbufs
    cam[PHX_DST_PTRS_VIRT]   = vbufs
    cam[(PHX_DST_PTR_TYPE|PHX_CACHE_FLUSH|
         PHX_FORCE_REWRITE)] = PHX_DST_PTR_USER_VIRT

    # Store image buffers in camera instance to prevent claim by garbage collector.
    cam.bufs = bufs
    cam.vbufs = vbufs # (FIXME: not sure this is needed if the above has immediate effects)
    return cam
end

"""

`_starthook(cam)` is called to perform specific actions for starting
acquisition.  This function should return nothing but may throw exceptions to
signal errors.

See also: [`start`](@ref), [`_stophook`](@ref).

"""
_starthook(::Camera) = nothing

"""
    stop(cam)

stops acquisition by camera `cam` after current image.

See also: [`abort`](@ref), [`start`](@ref), [`_stophook`](@ref).

"""
function stop(cam::Camera, cmd::Acq = PHX_STOP)
    if cam.state == 0
        error("camera must be open")
    elseif cam.state == 1
        warn("no acquisition is running")
    elseif cam.state == 2
        # Stop/abort acquistion, unlock all buffers and call specific
        # stop command.
        readstream(cam, cmd, C_NULL)
        try
            readstream(cam, PHX_UNLOCK, C_NULL)
        catch err
            warn(string(err))
        end
        _stophook(cam)
        cam.state = 1
    else
        error("camera instance corrupted")
    end
    return nothing
end

"""
    abort(cam)

aborts acquisition by camera `cam` without waiting for current image.

See also: [`stop`](@ref), [`start`](@ref).

"""
abort(cam::Camera) = stop(cam, PHX_ABORT)

"""

`_stophook(cam)` is called to perform specific actions for stopping
acquisition.  This function should return nothing but may throw exceptions to
signal errors.

See also: [`stop`](@ref), [`_starthook`](@ref).

"""
_stophook(::Camera) = nothing

#function waitframe(cam::Camera)
#    @assert(cam.running, "acquistion must be running")
#    _check(ccall(_phx_wait_frame, Status,
#                 (Ptr{Void}, Ptr{Void}), cam.handle, cam.frame))
#    return frame.context, frame.number, frame.overflows
#end

releaseframe(cam::Camera) = readstream(cam, PHX_BUFFER_RELEASE, C_NULL)
