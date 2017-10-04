#
# base.jl -
#
# Implements basic and low level methods for Julia interface to ActiveSilicon
# Phoenix (PHX) library.
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

`is_coaxpress(cam)` yields whether Phoenix camara `cam` is a CoaXPress
controlled camera.

See also: [`Phoenix.Camera`](@ref).

"""
is_coaxpress(cam::Camera) = cam.coaxpress

# Make a camera instance usable as an indexable object, which is useful
# to write configuration scripts.

Base.getindex(cam::Camera, param::Param) = getparam(cam, param)
Base.getindex(cam::Camera, reg::RegisterString) = read(cam, reg)
Base.getindex(cam::Camera, reg::RegisterValue) = read(cam, reg)
Base.getindex(cam::Camera, key) = error("invalid key type $(typeof(key))")

Base.setindex!(cam::Camera, val, param::Param) = setparam!(cam, param, val)
Base.setindex!(cam::Camera, val, reg::RegisterString) = write(cam, reg, val)
Base.setindex!(cam::Camera, val, reg::RegisterValue) = write(cam, reg, val)
Base.setindex!(cam::Camera, val, key) = error("invalid key type $(typeof(key))")

@inline function _check(status::Status)
    status == PHX_OK || throw(PHXError(status))
    nothing
end

"""
    cstring(str)

yields a vector of bytes (`UInt8`) with the contents of the string `str` and
properly zero-terminated.  This buffer is independent from the input string and
its contents can be overwritten.  An error is thrown if `str` contains any
embedded NUL characters (which would cause the string to be silently truncated
if the C routine treats NUL as the terminator).

An alternative (without the checking of embedded NUL characters) is:

    push!(convert(Vector{UInt8}, str), convert(UInt8, 0))

"""
function cstring(str::AbstractString) :: Array{UInt8}
    n = length(str)
    buf = Array{UInt8}(n + 1)
    i = 0
    for c in str
        c != '\0' || error("string must not have embedded NUL characters")
        i += 1
        buf[i] = c
    end
    buf[n + 1] = 0
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

#-------------------------------------------------------------------------------
# Get/set Frame Grabber Parameters
# ================================

"""
    getparam(cam, param) -> val

yields the value `val` of parameter `param` for the camera `cam`.  Beware that
the camera board must be open before retrieving parameters (otherwise you get a
`PHX_ERROR_BAD_HANDLE` error).

This method implements the syntax:

    cam[param] -> val

See also: [`setparam!`](@ref).

"""
function getparam{T<:Integer,A}(cam::Camera, param::Param{T,A}) :: T
    ref = Ref{T}(0)
    _check(_getparam(cam.handle, param.ident, ref))
    return ref[]
end

function getparam{A}(cam::Camera, param::Param{String,A}) :: String
    ref = Ref{Ptr{UInt8}}(0)
    _check(_getparam(cam.handle, param.ident, ref))
    return (ref[] == C_NULL ? "" : unsafe_string(ref[]))
end

function getparam{A}(cam::Camera, param::Param{Ptr{Void},A}) :: Ptr{Void}
    ref = Ref{Ptr{Void}}(0)
    _check(_getparam(cam.handle, param.ident, ref))
    return ref[]
end

getparam{A}(cam::Camera, param::Param{Void,A}) =
    error("write only parameter or undetermined parameter type")

_getparam{T}(handle::Handle, param::Cuint, ref::Ref{T}) =
    ccall(_PHX_ParameterGet, Status, (Handle, Cuint, Ptr{T}),
          handle, param, ref)

"""
    setparam!(cam, param, val)

set parameter `param` of camera `cam` to the value `val`.  This method
implements the syntax:

    cam[param] = val


See also: [`getparam`](@ref).

"""
setparam!{A,T<:Integer}(cam::Camera, param::Param{A,T}, val::Integer) =
    _check(_setparam!(cam.handle, param.ident, Ref{T}(val)))

setparam!{A}(cam::Camera, param::Param{A,String}, val::AbstractString) =
    _check(_setparam!(cam.handle, param.ident, Ref(pointer(cstring(val)))))

setparam!{A}(cam::Camera, param::Param{A,Void}) =
    error("read only parameter or undetermined parameter type")

# # FIXME: only for ImageBuff?
# function setparam!{A,T}(cam::Camera, param::Param{A,Ptr{T}}, val::Vector{T})
#     _check(ccall(_PHX_ParameterSet, Status, (Handle, Cuint, Ptr{T}),
#                  cam.handle, param, val))
# end

_setparam!{T}(handle::Handle, param::Cuint, ref::Ref{T}) =
    ccall(_PHX_ParameterSet, Status, (Handle, Cuint, Ptr{T}),
          handle, param, ref)

#------------------------------------------------------------------------------
# Reading/Writing CoaXPress Registers
# ===================================
#

function read{N}(cam::Camera, reg::RegisterString{N})
    buf = Array{UInt8}(N)
    _check(_readregister(cam, reg, buf, N))
    return unsafe_string(pointer(buf))
end

function write{N}(cam::Camera, reg::RegisterString{N}, str::AbstractString)
    @assert isascii(str)
    buf = Array{UInt8}(N)
    n = min(length(str), N)
    @inbounds for i in 1:n
        buf[i] = str[i]
    end
    @inbounds for i in n+1:N
        buf[i] = zero(UInt8)
    end
    _check(_writeregister(cam, reg, buf, N))
end

function read{T}(cam::Camera, reg::RegisterValue{T})
    buf = Ref{T}(0)
    _check(_readregister(cam, reg, buf, sizeof(T)))
    return (cam.swap ? bswap(buf[]) : buf[]) :: T
end

function write{T}(cam::Camera, reg::RegisterConstant{T})
    data = Ref{T}(cam.swap ? bswap(reg.value) : reg.value)
    _check(_writeregister(cam, reg, data, sizeof(T)))
end

function write{T}(cam::Camera, reg::RegisterValue{T}, value)
    temp = convert(T, value)
    data = Ref{T}(cam.swap ? bswap(temp) : temp)
    _check(_writeregister(cam, reg, data, sizeof(T)))
end

# Indirect read of register.
function read{T}(cam::Camera, reg::RegisterAddress, ::Type{T})
    buf = Ref{UInt32}(0)
    _check(_readregister(cam, reg, buf, 4))
    addr = (cam.swap ? bswap(buf[]) : buf[])
    read(cam, RegisterValue{T}(addr))
end

readstream(args...) = _check(_readstream(args...))


#-------------------------------------------------------------------------------
# Low Level Wrapper to Phoenix Dynamic Library
# ============================================
#

const _callback_ptr = Ref{Ptr{Void}}(0)
function __init__()
    _callback_ptr[] = C_NULL # FIXME: use real callback here
    const name = (is_linux() ? "LD_LIBRARY_PATH" :
                  is_apple() ? "DYLD_LIBRARY_PATH" : "")
    libdir = dirname(realpath(_PHXLIB))
    if name != ""
        found = false
        for dir in split(get(Base.ENV, name, ""), ":", keep=false)
            if isdir(dir) && realpath(dir) == libdir
                found = true
                break
            end
        end
        if ! found
            print_with_color(:yellow, STDERR,
                             "\n",
                             "WARNING: Directory of '$_PHXLIB'\n",
                             "         is not in your environment variable $name.\n",
                             "         You may have to call Julia as:\n\n",
                             "             $name='$libdir' julia\n\n")
        end
    end
end

# Manage to load the dynamic library and its symbols with appropriate flags.
# It is still needed to start Julia with the correct dynamic library search
# path (as checked above).
const _PHXHANDLE = Libdl.dlopen(_PHXLIB, (Libdl.RTLD_LAZY |
                                          Libdl.RTLD_DEEPBIND |
                                          Libdl.RTLD_GLOBAL))
for sym in (:_PHX_Create, :_PHX_Open, :_PHX_Close, :_PHX_Destroy,
            :_PHX_StreamRead, :_PHX_ParameterGet, :_PHX_ParameterSet,
            :_PHX_ControlRead, :_PHX_ControlWrite, :_PHX_Action,
            :_PHX_ErrCodeDecode, :_PHX_ErrHandlerDefault)
    @eval const $sym = Libdl.dlsym(_PHXHANDLE, $(string(sym)[2:end]))
end

"""
    open(model; configfile="",
                boardtype=0,
                boardnumber=PHX_BOARD_AUTO,
                channelnumber=PHX_CHANNEL_AUTO,
                boardmode=PHX_MODE_NORMAL)

yields a new camera instance.

    open(cam) -> cam

opens an ActiveSilicon board, configuring the hardware.  This operation must be
performed after creating the camera and setting some initial parameters.

See also: [`close`](@ref).

"""
Base.open{M<:CameraModel}(::Type{M}; kwds...) =
    open(Camera{M}(); kwds...)

function Base.open(cam::Camera;
                   configfile::String = "",
                   boardtype::Integer = 0,
                   boardnumber::Integer = PHX_BOARD_AUTO,
                   channelnumber::Integer = PHX_CHANNEL_AUTO,
                   boardmode::Integer = PHX_MODE_NORMAL)
    # Check state.
    if cam.state != 0
        if cam.state == 1 || cam.state == 2
            warn("camera has already been opened")
            return cam
        else
            error("camera structure corrupted")
        end
    end

    # Create references for parameter values and camera handle (these
    # references will persist until the final call to `PHX_Open`, i.e. we
    # do not assume that a copy of these settings is immediately made).
    ref_configfile = Ref{Ptr{UInt8}}(length(configfile) > 0 ?
                                     pointer(cstring(configfile)) :
                                     Ptr{UInt8}(0))
    ref_boardtype = Ref{ParamValue}(boardtype)
    ref_boardnumber = Ref{ParamValue}(boardnumber)
    ref_channelnumber = Ref{ParamValue}(channelnumber)
    ref_boardmode = Ref{ParamValue}(boardmode)

    # Set specific parameters.
    if boardtype != 0
        _check(_setparam!(cam.handle,
                          PHX_BOARD_VARIANT.ident, ref_boardtype))
    end
    _check(_setparam!(cam.handle,
                      PHX_BOARD_NUMBER.ident, ref_boardnumber))
    _check(_setparam!(cam.handle,
                      PHX_CHANNEL_NUMBER.ident, ref_channelnumber))
    _check(_setparam!(cam.handle,
                      PHX_CONFIG_MODE.ident, ref_boardmode))

    # Set configuration file.
    _check(_setparam!(cam.handle,
                      PHX_CONFIG_FILE.ident, ref_configfile))

    # Open the camera.
    _check(ccall(_PHX_Open, Status, (Handle,), cam.handle))
    cam.state = 1

    # Discover whether we have a CoaXPress camera.
    if (cam[PHX_CXP_INFO] & PHX_CXP_CAMERA_DISCOVERED) == 0
        cam.coaxpress = false
    else
        # Figure out byte order.
        magic = cam[CXP_STANDARD]
        if magic == CXP_MAGIC
            cam.coaxpress = true
        elseif magic == bswap(CXP_MAGIC)
            cam.coaxpress = true
            cam.swap = ! cam.swap
        else
            error("unexpected magic number for CoaXPress camera")
        end

        # Get current width and height.
        width = read(cam, CXP_WIDTH_ADDRESS, UInt32)
        height = read(cam, CXP_HEIGHT_ADDRESS, UInt32)
        cam[PHX_CAM_ACTIVE_XLENGTH] = width
        cam[PHX_CAM_ACTIVE_YLENGTH] = height

        # Get device vendor name and device model name.
        vendorname = cam[CXP_DEVICE_VENDOR_NAME]
        modelname = cam[CXP_DEVICE_MODEL_NAME]
        println("vendor name: $vendorname")
        println("model name:  $modelname")
    end

    # Apply specific post-open configuration.
    _openhook(cam)

    return cam
end

"""
    _openhook(cam)

performs specific operations just after camera `cam` has been opened.  This
function should return nothing but may throw exceptions to signal errors.

See also: [`open`](@ref)

"""
_openhook(cam::Camera) = nothing

"""
    close(cam) -> cam

closes an Active Silicon board, releasing the hardware.  The camera is
automatically closed when finalized by the garbage collector, so calling this
method is optional.

See also: [`open`](@ref).

"""
function Base.close(cam::Camera)
    if cam.state == 0
        warn("camera has already been closed")
    elseif cam.state == 1
        # Note that PHX_Close requires the address of the handle but left its
        # contents unchanged.
        ref = Ref(cam.handle)
        status = ccall(_PHX_Close, Status, (Ptr{Handle},), ref)
        #cam.handle = ref[] # not needed (cf. note above)?
        status == PHX_OK || throw(PHXError(status))
        cam.state = 0
    elseif cam.state == 2
        error("cannot close camera while acquisition is running")
    else
        error("camera structure corrupted")
    end
    return cam
end

"""
    _readstream(cam, cmd, ptr) -> status

initiates and controls the acquisition of stream data such as images.  The
destination of the data can be system memory, graphics memory, or other user
addressable memory, such as slave PCI cards.  `cam` is a PHX camera, `cmd` is
the command to be performed and `ptr` is a command-specific parameter (ususally
a pointer).

"""
_readstream(cam::Camera, cmd::Acq, ptr::Ptr{Void}) =
    ccall(_PHX_StreamRead, Status, (Handle, Acq, Ptr{Void}),
          cam.handle, cmd, ptr)

"""
    _readregister(cam, reg, data, num, timeout = cam.timeout)

reatds register `reg` from camera `cam`.


See also: [`_readcontrol`](@ref), [`_writeregister`](@ref).

"""
function _readregister(cam::Camera, reg::Register, data, num::Integer,
                       timeout::Integer = cam.timeout)
    _readcontrol(cam.handle, PHX_REGISTER_DEVICE,
                 Ref(reg.addr), data, Ref{UInt32}(num), timeout)
end

"""
    _readcontrol(handle, src, param, buf, num, timeout) -> status

This function receives `num[]` bytes from Active Silicon board `handle` via the
control port selected by `src` and `param` and stores them in buffer `buf`.  If
a data error occurs during reception of a byte, or a packet error occurs, or
the timeout period `timeout` (in milliseconds) is exceeded, no further bytes
will be stored in `buf`.  (Note: Depending on the protocol, the underlying
hardware may retry a read before reporting an error).  The actual number of
bytes received within the specified timeout period is stored in `num[]`.  Note
that registers in a CoaXPress device (e.g. camera) are big-endian.  Therefore
byte swapping (e.g. with `bswap`) may be needed when using this function to
access a CoaXPress device.  A standard status is returned.

See also: [`_readregister`](@ref), [`_writecontrol`](@ref).

"""
function _readcontrol(handle::Handle, src::ControlPort, param, buf,
                      num::Ref{UInt32}, timeout::Integer)
    ccall(_PHX_ControlRead, Status,
          (Handle, UInt32, Ptr{Void}, Ptr{Void}, Ptr{UInt32}, UInt32),
          handle, src.port, param, buf, num, timeout)
end

"""
    _writeregister(cam, reg, data, num, timeout = cam.timeout)

writes register `reg` to camera `cam`.


See also: [`_writecontrol`](@ref), [`_readregister`](@ref).

"""
function _writeregister(cam::Camera, reg::Register, data, num::Integer,
                        timeout::Integer = cam.timeout)
    _writecontrol(cam.handle, PHX_REGISTER_DEVICE,
                  Ref(reg.addr), data, Ref{UInt32}(num), timeout)
end

"""
    _writecontrol(handle, src, param, buf, num, timeout) -> status

This function sends `num[]` bytes from buffer `buf` to Active Silicon board
`handle` via the control port selected by `src` and `param`.  If a data error
occurs during transmission of a byte, or a packet error occurs, or the timeout
period `timeout` (in milliseconds) is exceeded, no further bytes will be
transmitted.  (Note: Depending on the protocol, the underlying hardware may
retry a write before reporting an error).  The actual number of bytes
transmitted within the specified timeout period is stored in `num[]`.  Note
that registers in a CoaXPress device (e.g. camera) are big-endian.  Therefore
byte swapping (e.g. with `bswap`) may be needed when using this function to
access a CoaXPress device.  A standard status is returned.

See also: [`_writeregister`](@ref), [`_readcontrol`](@ref).

"""
function _writecontrol(handle::Handle, src::ControlPort, param, buf,
                       num::Ref{UInt32}, timeout::Integer)
    ccall(_PHX_ControlWrite, Status,
          (Handle, UInt32, Ptr{Void}, Ptr{Void}, Ptr{UInt32}, UInt32),
          handle, src.port, param, buf, num, timeout)
end

"""
    _action(cam, act, prm, ptr) -> status

performs the specified action.

"""
_action(cam::Camera, act::Action, prm::ActionParam, ptr::Ptr{Void}) =
    ccall(_PHX_Action, Status, (Handle, Action, ActionParam, Ptr{Void}),
          cam.handle, act, prm, ptr)

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
