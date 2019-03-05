#
# acquisition.jl -
#
# Implements acquisition of images for Julia interface to ActiveSilicon Phoenix
# (PHX) library.
#
#------------------------------------------------------------------------------
#
# This file is part of the `Phoenix.jl` package which is licensed under the MIT
# "Expat" License.
#
# Copyright (C) 2017-2019, Éric Thiébaut (https://github.com/emmt/Phoenix.jl).
# Copyright (C) 2016, Éric Thiébaut & Jonathan Léger.
#

const SUCCESS = Cint(0)
const FAILURE = Cint(-1)

"""
    _offsetof(x::DataType, s::Symbol)

yields the byte offset of field `s` in structure `x`.  Beware that this is
slower than requested the offset by index.

"""
function _offsetof(::Type{T}, s::Symbol) where {T}
    for i in 1:nfields(T)
        if fieldname(T, i) == s
            return fieldoffset(T, i)
        end
    end
    throw(ArgumentError("type `$T` has no field `$s`"))
end

const _offsetof_context_cond      = _offsetof(AcquisitionContext, :cond)
const _offsetof_context_mutex     = _offsetof(AcquisitionContext, :mutex)
const _offsetof_context_imgbuf    = _offsetof(AcquisitionContext, :imgbuf)
const _offsetof_context_imgctx    = _offsetof(AcquisitionContext, :imgctx)
const _offsetof_context_index     = _offsetof(AcquisitionContext, :index)
const _offsetof_context_sec       = _offsetof(AcquisitionContext, :sec)
const _offsetof_context_usec      = _offsetof(AcquisitionContext, :usec)
const _offsetof_context_number    = _offsetof(AcquisitionContext, :number)
const _offsetof_context_overflows = _offsetof(AcquisitionContext, :overflows)
const _offsetof_context_synclosts = _offsetof(AcquisitionContext, :synclosts)
const _offsetof_context_pending   = _offsetof(AcquisitionContext, :pending)
const _offsetof_context_events    = _offsetof(AcquisitionContext, :events)

const _offsetof_framedata_sec     = _offsetof(FrameData, :sec)
const _offsetof_framedata_usec    = _offsetof(FrameData, :usec)
const _offsetof_framedata_index   = _offsetof(FrameData, :index)

@assert _offsetof_context_imgctx == _offsetof_context_imgbuf + sizeof(Ptr{Cvoid})
@assert _offsetof_context_usec == _offsetof_context_sec + sizeof(_typeof_tv_sec)

# similar to unsafe_load but re-cast pointer as needed.
@inline _load(::Type{T}, ptr::Ptr) where {T} =
    unsafe_load(Ptr{T}(ptr))

@inline _load(::Type{T}, ptr::Ptr{T}) where {T} =
    unsafe_load(ptr)

# similar to unsafe_store! but re-cast pointer as needed.
@inline _store!(::Type{T}, ptr::Ptr, val) where {T} =
    unsafe_store!(Ptr{T}(ptr), val)

@inline _store!(::Type{T}, ptr::Ptr{T}, val) where {T} =
    unsafe_store!(ptr, val)

@inline _increment!(::Type{T}, ptr::Ptr) where {T} =
    _increment!(T, Ptr{T}(ptr))

@inline _increment!(::Type{T}, ptr::Ptr{T}) where {T} =
    unsafe_store!(ptr, unsafe_load(ptr) + one(T))

@inline _decrement!(::Type{T}, ptr::Ptr) where {T} =
    _decrement!(T, Ptr{T}(ptr))

@inline _decrement!(::Type{T}, ptr::Ptr{T}) where {T} =
    unsafe_store!(ptr, unsafe_load(ptr) - one(T))


"""
Callback for acquisition.

This method does not use any Julia internals (unless the pointer
`_PHX_StreamRead[]` is incorrectly initialized) as you can figure out by
calling:

    code_native(Phoenix._callback, (Phoenix.Handle, UInt32, Ptr{Cvoid}))

which has only a call to `jl_throw` if the above mentioned pointer is
incorrect.  This callback is therefore thread safe.

"""
function _callback(handle::Handle, events::UInt32, ctx::Ptr{Cvoid})
    #ccall(:printf, Cint, (Cstring, Cuint, Ptr{Cvoid}),
    #      "_callback called events=0x%0x, ctx=0x%p\n", events, ctx)
    mutex = _load(Ptr{Cvoid}, ctx + _offsetof_context_mutex)
    cond  = _load(Ptr{Cvoid}, ctx + _offsetof_context_cond)
    if ccall(:pthread_mutex_lock, Cint, (Ptr{Cvoid},), mutex) == SUCCESS
        if (PHX_INTRPT_BUFFER_READY & events) != 0
            # A new frame is available.
            # Take its arrival time stamp.
            ccall(:gettimeofday, Cint, (Ptr{Cvoid}, Ptr{Cvoid}),
                  ctx + _offsetof_context_sec, C_NULL)
            # Get last captured image buffer.
            status = ccall(_PHX_StreamRead[],
                           Status, (Handle, Acq, Ptr{ImageBuff}),
                           handle, PHX_BUFFER_GET,
                           ctx + _offsetof_context_imgbuf)
            if status != PHX_OK
                # FIXME: this is not an overflow
                _increment!(Int, ctx + _offsetof_context_overflows)
            else
                # Store the index of the last captured image.
                imgctx = _load(Ptr{Cvoid}, ctx + _offsetof_context_imgctx)
                _store!(Int, ctx + _offsetof_context_index,
                        _load(Int, imgctx + _offsetof_framedata_index))
                # Store the time stamp.
                _store!(_typeof_tv_sec, imgctx + _offsetof_framedata_sec,
                        _load(_typeof_tv_sec, ctx + _offsetof_context_sec))
                _store!(_typeof_tv_usec, imgctx + _offsetof_framedata_usec,
                        _load(_typeof_tv_usec, ctx + _offsetof_context_usec))
                # Update counters.
                _increment!(Int, ctx + _offsetof_context_number)
                _increment!(Int, ctx + _offsetof_context_pending)
            end
        end
        if (PHX_INTRPT_FIFO_OVERFLOW & events) != 0
            # Fifo overflow.
            _increment!(Int, ctx + _offsetof_context_number)
            _increment!(Int, ctx + _offsetof_context_overflows)
        end
        if (PHX_INTRPT_SYNC_LOST & events) != 0
            # Synchronization lost.
            _increment!(Int, ctx + _offsetof_context_number)
            _increment!(Int, ctx + _offsetof_context_synclosts)
        end
        if (_load(UInt, ctx + _offsetof_context_events) & events) != 0
            # Signal condition for waiting thread.
            ccall(:pthread_cond_signal, Cint, (Ptr{Cvoid},), cond)
        end
        ccall(:pthread_mutex_unlock, Cint, (Ptr{Cvoid},), mutex)
    end
    return nothing
end

# Extend method.
wait(cam::Camera, timeout::Float64, drop::Bool) =
    wait(cam, TimeSpec(time() + timeout), drop)

# FIXME: Something not specified in the doc. is that, when continuous
# acquisition and blocking mode are both enabled, all calls to `PHX_BUFFER_GET`
# yield the same image buffer until `PHX_BUFFER_RELEASE` is called.  It seems
# that there is no needs to have a `PHX_BUFFER_GET` matches a
# `PHX_BUFFER_RELEASE` and that every `PHX_BUFFER_RELEASE` moves to the next
# buffer.  However, acquisition buffers are used in their given order so it is
# not too difficult to figure out where we are if we count the number of
# frames.
#

function wait(cam::Camera, timeout::TimeSpec, drop::Bool)
    # Check state.
    if cam.state != 2
        if cam.state == 0 || cam.state == 1
            error("acquisition has not been started")
        else
            error("camera instance corrupted")
        end
    end

    # Because we cannot throw anything while the mutex is locked, we defer
    # reporting of error and use the following variables to keep track of what
    # happens while the mutex was locked.
    #
    # `index` is the index of the next image buffer to process, 0 if there
    #         are none, -1 if there have been some errors;
    #
    # `errname` is the identifier of the origin of the failure to return a new
    #         image buffer to process;
    #
    # `errcode` is the associated error code (may be: a Phoenix status or a
    #         POSIX thread error code);
    local index::Int = 0 # index of frame to process if any
    local errname::Symbol = Symbol()
    local errcode::Int    = 0
    imgbuf = Ref{ImageBuff}()
    ctx = cam.context # shortcut

    # Lock mutex and wait for next image, taking care to not throw anything
    # while the mutex is locked.
    code = ccall(:pthread_mutex_lock, Cint, (Ptr{Cvoid},), ctx.mutex)
    if code != SUCCESS
        index, errname, errcode = -1, :lock, Int(code)
    else
        # While there are no pending frames, wait for the condition to be
        # signaled or an error to occur.  This is done in a `while` loop to
        # cope with spurious signaled conditions.
        while ctx.pending == 0
            # This code is prepared to face spurious signaled conditions.
            if isforever(timeout)
                code = ccall(:pthread_cond_wait, Cint,
                             (Ptr{Cvoid}, Ptr{Cvoid}),
                             ctx.cond, ctx.mutex)
                if code != SUCCESS
                    index, errname, errcode = -1, :wait, Int(code)
                    break
                end
            else
                code = ccall(:pthread_cond_timedwait, Cint,
                             (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{TimeSpec}),
                             ctx.cond, ctx.mutex, Ref(timeout))
                if code != SUCCESS
                    index, errname, errcode = -1, :timedwait, Int(code)
                    break
                end
            end
        end
        if index ≥ 0 && drop
            # If no errors occured so far, get rid of unprocessed pending image
            # buffers.
            while ctx.pending > 1
                status = _readstream(cam, PHX_BUFFER_RELEASE, C_NULL)
                if status != PHX_OK
                    index, errname, errcode = -1, :releasebuffer, Int(status)
                    break
                end
                ctx.pending -= 1
                ctx.overflows += 1
            end
        end
        if index ≥ 0 && ctx.pending ≥ 1
            # If no errors occured so far and at least one image buffer is
            # unprocessed, manage to return the index of this buffer.
            ctx.pending -= 1
            index = ctx.index - ctx.pending
            if index ≤ 0
                index += length(cam.imgs)
            end
        end
        # Unlock the mutex (whatever the errors so far).
        code = ccall(:pthread_mutex_unlock, Cint, (Ptr{Cvoid},), ctx.mutex)
        if code != SUCCESS && index ≥ 0
            index, errname, errcode = -1, :unlock, Int(code)
        end
    end

    # Mutex has been unlocked, report errors if any.
    if index ≤ 0
        if errname == :timedwait && errcode == Libc.ETIMEDOUT
            throw(TimeoutError())
        end
        msg = (errname == :lock ?
               "failed to lock mutex" :
               errname == :unlock ?
               "failed to unlock mutex" :
               errname == :wait || errname == :timedwait ?
               "failed to wait for condition" :
               errname == :getbuffer ?
               "failed to get image buffer [$(geterrormessage(errcode))]" :
               errname == :releasebuffer ?
               "failed to release image buffer [$(geterrormessage(errcode))]" :
               "some error occured while waiting for next frame [$errname, $errcode]")
        error(msg)
    end

    # Retrieve time stamp of last frame and fix registered time stamp to be
    # (approximately) that of the previous frame.
    ticks = cam.ctxs[index].sec + cam.ctxs[index].usec*1E-6
    return (cam.imgs[index], ticks)
end

# Extend method.
function read(cam::Camera, ::Type{T}, num::Int;
              skip::Integer = 0,
              timeout::Real = defaulttimeout(cam),
              truncate::Bool = false) where {T}
    # Check arguments.
    num ≥ 1 || throw(ArgumentError("invalid number of images"))
    skip ≥ 0 || throw(ArgumentError("invalid number of images to skip"))
    timeout > zero(timeout) || throw(ArgumentError("invalid timeout"))

    # Start acquisition with given callback and collect images.
    imgs = Vector{Array{T,2}}(undef, num)
    cnt = 0
    start(cam, T, num + 1) # FIXME: hack to avoid loosing one frame
    while cnt < num
        try
            img, ticks = wait(cam, timeout, false)
            if skip > zero(skip)
                # Skip this frame.
                skip -= one(skip)
                release(cam)
            else
                # Store this frame.
                cnt += 1
                imgs[cnt] = img
                release(cam)
            end
        catch err
            if truncate && isa(err, TimeoutError)
                @warn "Acquisition timeout after $cnt image(s)"
                num = cnt
                resize!(imgs, num)
            else
                abort(cam)
                rethrow(err)
            end
        end
    end

    # Stop immediately.
    abort(cam)

    # Return images.
    return imgs
end

# Extend method.
function read(cam::Camera, ::Type{T};
              skip::Integer = 0,
              timeout::Real = defaulttimeout(cam)) where {T}
    # Check arguments.
    skip ≥ 0 || throw(ArgumentError("invalid number of images to skip"))
    timeout > zero(timeout) || throw(ArgumentError("invalid timeout"))

    # Acquire a single image.
    start(cam, T, (skip > zero(skip) ? 2 : 1))
    while true
        try
            img, ticks = wait(cam, timeout, false)
            if skip > zero(skip)
                # Skip this frame.
                skip -= one(skip)
                release(cam)
            else
                # Stop immediately and return image.
                abort(cam)
                return img
            end
        catch err
            abort(cam)
            rethrow(err)
        end
    end
end

# Extend method.
function getcapturebitstype(cam::Camera)
    bufpix = capture_format(cam[PHX_DST_FORMAT])
    T = equivalentbitstype(bufpix)
    return (T == Nothing ? UInt8 : T)
end

# Extend method.
release(cam::Camera) =
    readstream(cam, PHX_BUFFER_RELEASE, C_NULL)

#
# Allocates image buffers for acquisition with camera `cam` and start
# continuous acquisition.
#
# On entry, it is assumed that the frame grabber configuration is consistent
# with the camera settings.  In particular:
#
# * The size of the region of interest (ROI) to capture is given by parameters
#   `PHX_ROI_XLENGTH` and `PHX_ROI_YLENGTH`.
#
# * The pixel format of the captured image is given by the parameter
#   `PHX_DST_FORMAT`.
#
# On exit, `nbufs` image buffers of type `T` are allocated and referenced by
# `cam`, their size as small as possible but sufficient to store the captured
# ROI and the following parameters are updated accordingly:
#
# * `PHX_ROI_DST_XOFFSET` and `PHX_ROI_DST_YOFFSET` are both set to 0.
#
# * `PHX_BUF_DST_XLENGTH` is set to the number of bytes per row of the ROI and
#   `PHX_BUF_DST_YLENGTH` is set to the number of rows in the ROI.
#
# * `PHX_ACQ_IMAGES_PER_BUFFER`, `PHX_ACQ_BUFFER_START` and
#   `PHX_COUNT_BUFFER_READY` are all set to `1`.
#
# * `PHX_ACQ_NUM_BUFFERS` (alias `PHX_ACQ_NUM_IMAGES`) is set to `nbufs` while
#   `PHX_DST_PTRS_VIRT` and `PHX_DST_PTR_TYPE` are set to require the frame
#   grabber to use the provided image buffers.
#
function start(cam::Camera, ::Type{T}, nbufs::Int = 2) where {T}
    # Check arguments.
    if cam.state != 1
        if cam.state == 0
            error("camera must be open")
        elseif cam.state == 2
            error("acquisition must not be running")
        else
            error("camera instance corrupted")
        end
    end
    nbufs ≥ 1 || throw(ArgumentError("invalid number of image buffers"))

    # FIXME: Benchmark this to see whether it is worth avoiding recreating the
    #        virtual buffers.

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
        @warn "capture format does not exactly fit in chosen pixel type"
    end
    width = div(width*dstbits + arrbits - 1, arrbits) # roundup array width
    cam[PHX_ROI_DST_XOFFSET] = 0
    cam[PHX_ROI_DST_YOFFSET] = 0
    cam[PHX_BUF_DST_XLENGTH] = width*sizeof(T)
    cam[PHX_BUF_DST_YLENGTH] = height

    # Allocate image buffers.
    imgs = [zeros(T, width, height) for i in 1:nbufs]
    ctxs = [FrameData(0, 0, i) for i in 1:nbufs]
    bufs = [i ≤ nbufs ?
            ImageBuff(pointer(imgs[i]),
                      pointer(ctxs) + (i - 1)*sizeof(FrameData)) :
            ImageBuff(C_NULL, C_NULL) for i in 1:nbufs+1]

    # Instruct Phoenix to use the virtual buffers. The PHX_CACHE_FLUSH here is
    # to make sure that the new buffers do replace the old ones, if any, before
    # they may be claimed by the garbage collector.  (FIXME: I am not sure
    # whether this is really needed and I do not known the effects of the
    # `PHX_FORCE_REWRITE` flag.)
    cam[PHX_ACQ_IMAGES_PER_BUFFER] = 1
    cam[PHX_ACQ_BUFFER_START]      = 1
    cam[PHX_ACQ_NUM_BUFFERS]       = nbufs
    cam[PHX_DST_PTRS_VIRT]         = bufs
    cam[(PHX_DST_PTR_TYPE|PHX_CACHE_FLUSH|
         PHX_FORCE_REWRITE)] = PHX_DST_PTR_USER_VIRT

    # Store image buffers and metadata in camera instance to prevent claim by
    # garbage collector.
    cam.imgs = imgs
    cam.ctxs = ctxs
    cam.bufs = bufs # FIXME: Not sure this is needed if the above has immediate
                    #        effects.  We can check this by not setting this
                    #        reference, call the garbage collector and attempt
                    #        acquisition, the result should be quite obvious...

    # Configure frame grabber for continuous acquisition and enable interrupts
    # for expected events.
    cam[PHX_ACQ_BLOCKING]       = PHX_ENABLE
    cam[PHX_ACQ_CONTINUOUS]     = PHX_ENABLE
    cam[PHX_COUNT_BUFFER_READY] = 1
    cam[PHX_INTRPT_CLR]         = ~zero(ParamValue)
    cam[PHX_INTRPT_SET]         = (PHX_INTRPT_GLOBAL_ENABLE |
                                   PHX_INTRPT_FIFO_OVERFLOW |
                                   PHX_INTRPT_SYNC_LOST |
                                   PHX_INTRPT_BUFFER_READY)

    # Configure acquisition context.
    cam.context.imgbuf    = C_NULL
    cam.context.imgctx    = C_NULL
    cam.context.index     = 0
    cam.context.sec       = 0
    cam.context.usec      = 0
    cam.context.number    = 0
    cam.context.overflows = 0
    cam.context.synclosts = 0
    cam.context.pending   = 0
    cam.context.events    = PHX_INTRPT_BUFFER_READY;
    cam[PHX_EVENT_CONTEXT] = Ref(cam.context)

    # Start acquisition with our own callback.
    readstream(cam, PHX_START, _callback_ptr[])

    # Send specific start command, aborting acquisition in case of errors.
    try
        starthook(cam)
    catch err
        _readstream(cam, PHX_ABORT, C_NULL)
        _readstream(cam, PHX_UNLOCK, C_NULL)
        rethrow(err)
    end

    # Finally, set camera state.
    cam.state = 2
    return nothing
end

"""

`starthook(cam)` is called to perform specific actions for starting
acquisition.  This function should return nothing but may throw exceptions to
signal errors.

See also: [`start`](@ref), [`stophook`](@ref).

"""
starthook(::Camera) = nothing

"""
    stop(cam)

stops acquisition by camera `cam` after current image.

See also: [`abort`](@ref), [`start`](@ref), [`stophook`](@ref).

"""
stop(cam::Camera) = _stop(cam, PHX_STOP)

"""
    abort(cam)

aborts acquisition by camera `cam` without waiting for current image.

See also: [`stop`](@ref), [`start`](@ref).

"""
abort(cam::Camera) = _stop(cam, PHX_ABORT)

function _stop(cam::Camera, cmd::Acq)
    if cam.state == 0
        error("camera must be open")
    elseif cam.state == 1
        @warn "no acquisition is running"
    elseif cam.state == 2
        # Stop/abort acquisition.
        status = _readstream(cam, cmd, C_NULL)
        if status != PHX_OK
            @warn string("Failure in ", :PHX_StreamRead, " with ",
                         (cmd == PHX_STOP  ? :PHX_STOP :
                          cmd == PHX_ABORT ? :PHX_ABORT : cmd),
                         " :\n         ", geterrormessage(status))
        end
        # Unlock all buffers.
        status = _readstream(cam, PHX_UNLOCK, C_NULL)
        if status != PHX_OK && status != PHX_ERROR_NOT_IMPLEMENTED
            @warn string("Failure in ", :PHX_StreamRead, " with ",
                         :PHX_UNLOCK, ":\n         ",
                         geterrormessage(status))
        end
        # Call specific stop command.
        try
            stophook(cam)
        catch err
            rethrow(err)
        finally
            cam.state = 1
        end
    else
        error("camera instance corrupted")
    end
    return nothing
end

"""

`stophook(cam)` is called to perform specific actions for stopping
acquisition.  This function should return nothing but may throw exceptions to
signal errors.

See also: [`stop`](@ref), [`starthook`](@ref).

"""
stophook(::Camera) = nothing
