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

"""

`AcquisitionContext` is used to share information between the acquisition
callback and the main Julia thread.  It has the following fields:

- `mutex` is a lock to protect the contents of the structure;

- `cond` is a condition variable to signal events to the processing thread;

- `events` is the mask of events to be signaled to the processing thread;

- `number` is the total number frames so far (it tries to take into account
  all the frames: captured frames but also overflows and synchronization losts);

- `overflows`: is the number of overflows (or dropped frames) so far;

- `synclosts` is the number of synchronization losts so far

- `pending` is the number of image buffers ready for being processed;

See also: [`read`](@ref), [`start`](@ref), [`wait`](@ref).

"""
mutable struct AcquisitionContext
    mutex::Ptr{Nothing}   # Lock to protect this structure
    cond::Ptr{Nothing}    # Condition to signal events
    # The 2 following fields should exactly match `ImageBuff` structure
    imgbuf::Ptr{Nothing}  # Address of last captured image buffer
    imgctx::Ptr{Nothing}  # Address of context associated with last ...
    index::Int            # Index of last captured image buffer
    # The 2 following fields should exactly match `TimeVal` structure
    sec::_typeof_tv_sec   # Time stamp (seconds) of last captured image
    usec::_typeof_tv_usec # Time stamp (microseconds) of last captured image
    number::Int           # Number of image buffers so far
    overflows::Int        # Number of overflows so far
    synclosts::Int        # Number of synchronization losts so far
    pending::Int          # Number of pending image buffers
    events::UInt          # Mask of events to be signaled
    function AcquisitionContext()
        ctx = new(C_NULL, C_NULL, C_NULL, C_NULL,
                  0, 0, 0, 0, 0, 0, 0, 0)
        ctx.mutex = Libc.malloc(_sizeof_pthread_mutex_t)
        if ctx.mutex == C_NULL
            throw(OutOfMemoryError())
        end
        if ccall(:pthread_mutex_init, Cint, (Ptr{Nothing}, Ptr{Nothing}),
                 ctx.mutex, C_NULL) != SUCCESS
            _destroy(ctx)
            error("pthread_mutex_init failed")
        end
        ctx.cond = Libc.malloc(_sizeof_pthread_cond_t)
        if ctx.cond == C_NULL
            _destroy(ctx)
            throw(OutOfMemoryError())
        end
        if ccall(:pthread_cond_init, Cint, (Ptr{Nothing}, Ptr{Nothing}),
                 ctx.cond, C_NULL) != SUCCESS
            _destroy(ctx)
            error("pthread_cond_init failed")
        end
        return finalizer(_destroy, ctx)
    end
end

# Beware must not be mutable!
struct FrameData
    sec::_typeof_tv_sec   # Time stamp (seconds)
    usec::_typeof_tv_usec # Time stamp (microseconds)
    index::Int
end

"""

`_destroy(obj)` is the finalizer method for a Phoenix camera instance or an
acquisition context.  It *must not* be called directly.

See also: [`Phoenix.Camera`](@ref), [`Phoenix.AcquisitionContext`](@ref).

"""
function _destroy(ctx::AcquisitionContext)
    # This is the destructor of an AcquisitionContext instance.
    if ctx.cond != C_NULL
        cond = ctx.cond
        ctx.cond = C_NULL
        ccall(:pthread_cond_destroy, Cint, (Ptr{Nothing},), cond)
        Libc.free(cond)
    end
    if ctx.mutex != C_NULL
        mutex = ctx.mutex
        ctx.mutex = C_NULL
        ccall(:pthread_mutex_destroy, Cint, (Ptr{Nothing},), mutex)
        Libc.free(mutex)
    end
end


"""

Concrete types derived from abstract type `CameraModel` are used to uniquely
identify the different camera models.

"""
abstract type CameraModel end

mutable struct Camera{M<:CameraModel} <: ScientificCamera
    state::Int # 0 initially, 1 when camera open, 2 while acquiring
    handle::Handle
    imgs::Vector{Array{T,2}} where {T} # images for acquisition
    ctxs::Vector{FrameData} # metadata for captured images
    bufs::Vector{ImageBuff} # virtual image buffers currently used
    context::AcquisitionContext # context shared with acquisition callback
    timeout::UInt32 # time out (in ms) for reading/writing registers
    swap::Bool # swap bytes for read/write control connection?
    coaxpress::Bool # is it a CoaXPress camera?

    function Camera{M}(errorhandler::Ptr{Nothing} = _errorhandler_ptr[]) where {M}
        # Create a new PHX handle structure.
        handle = Ref{Handle}(0)
        status = ccall(_PHX_Create[], Status, (Ptr{Handle}, Ptr{Nothing}),
                       handle, errorhandler)
        status == PHX_OK || throw(PHXError(status))

        # Create the instance and attach the destroy callback.
        cam = new{M}(0, handle[],
                     Vector{Array{UInt8,2}}(undef, 0),
                     Vector{FrameData}(undef, 0),
                     Vector{ImageBuff}(undef, 0),
                     AcquisitionContext(),
                     500, false, false)
        return finalizer(_destroy, cam)
    end
end

function _destroy(cam::Camera)
    if cam.handle != 0
        if cam.state > 1
            # Abort acquisition (using the private routine which does not throw
            # exceptions).
            _readstream(cam, PHX_ABORT, C_NULL)
            _readstream(cam, PHX_UNLOCK, C_NULL)
            stophook(cam)
        end
        ref = Ref(cam.handle)
        if cam.state > 0
            # Close the camera.
            ccall(_PHX_Close[], Status, (Ptr{Handle},), ref)
        end
        # Release other ressources.
        ccall(_PHX_Destroy[], Status, (Ptr{Handle},), ref)
        cam.handle = 0 # to avoid doing this more than once
    end
end
