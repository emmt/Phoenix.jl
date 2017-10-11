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

mutable struct Camera{M<:CameraModel} <: ScientificCamera
    state::Int # 0 initially, 1 when camera open, 2 while acquiring
    handle::Handle
    bufs::Vector{Array{T,2}} where {T} # image buffers for acquisition
    vbufs::Vector{ImageBuff} # virtual buffers currently used
    #context::AcquisitionContext # context shared with acquisition callback
    timeout::UInt32 # time out (in ms) for reading/writing registers
    swap::Bool # swap bytes for read/write control connection?
    coaxpress::Bool # is it a CoaXPress camera?

    function Camera{M}(errorhandler::Ptr{Void} = _errorhandler_ptr[]) where {M}
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

"""

`_destroy(cam)` is the finalizer method for a Phoenix camera instance.  It
*must not* be called directly.

See also: [`Phoenix.Camera`](@ref).

"""
function _destroy(cam::Camera)
    if cam.handle != 0
        if cam.state > 1
            # Abort acquisition (using the private routine which does not throw
            # exceptions).
            _readstream(cam, PHX_ABORT, C_NULL)
            _readstream(cam, PHX_UNLOCK, C_NULL)
            _stophook(cam)
        end
        ref = Ref(cam.handle)
        if cam.state > 0
            # Close the camera.
            ccall(_PHX_Close, Status, (Ptr{Handle},), ref)
        end
        # Release other ressources.
        ccall(_PHX_Destroy, Status, (Ptr{Handle},), ref)
        cam.handle = 0 # to avoid doing this more than once
    end
end


# Custom exception to report errors.
struct PHXError <: Exception
   status::Status
end

struct TimeVal
    sec::_typeof_tv_sec    # seconds
    usec::_typeof_tv_usec  # microseconds
end

struct TimeSpec
    sec::_typeof_tv_sec    # seconds
    nsec::_typeof_tv_nsec  # nanoseconds
end

