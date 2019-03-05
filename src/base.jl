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
# Copyright (C) 2017-2019, Éric Thiébaut (https://github.com/emmt/Phoenix.jl).
# Copyright (C) 2016, Éric Thiébaut & Jonathan Léger.
#

# Override bitwise operators for frame grabber parameters.
(~)(x::Param{T,A}) where {T,A} = Param{T,A}(~x.ident)
(|)(x::Param{T,A}, y::Integer) where {T,A} = Param{T,A}(x.ident | y)
(&)(x::Param{T,A}, y::Integer) where {T,A} = Param{T,A}(x.ident & y)
xor(x::Param{T,A}, y::Integer) where {T,A} = Param{T,A}(xor(x.ident, y))

# Conversion to integer values of frame grabber parameters.
convert(::Type{ParamValue}, x::Param) = x.ident
convert(::Type{T}, x::Param) where {T<:Integer} = convert(T, x.ident)

# Override `isreadable` and `iswritable` methods for frame grabber parameters
# and CoaXPress registers.  For the more general case, we do not want to
# pollute the other modules so we left the method definition be local to this
# module.
isreadable(::Any) = false
iswritable(::Any) = false
Base.isreadable(::Type{A}) where {A<:Readable} = true
Base.iswritable(::Type{A}) where {A<:Writable} = true
Base.isreadable(::Param) = false
Base.iswritable(::Param) = false
Base.isreadable(::Param{T,A}) where {T,A<:Readable} = true
Base.iswritable(::Param{T,A}) where {T,A<:Writable} = true
Base.isreadable(::Register) = false
Base.iswritable(::Register) = false
Base.isreadable(::RegisterValue{T,A}) where {T,A<:Readable} = true
Base.iswritable(::RegisterValue{T,A}) where {T,A<:Writable} = true
Base.isreadable(::RegisterAddress{T,A}) where {T,A<:Readable} = true
Base.iswritable(::RegisterAddress{T,A}) where {T,A<:Writable} = true
Base.isreadable(::RegisterString{N,A}) where {N,A<:Readable} = true
Base.iswritable(::RegisterString{N,A}) where {N,A<:Writable} = true


# Make a camera instance usable as an indexable object, which is useful
# to write configuration scripts.

Base.getindex(cam::Camera, param::Param) = getparam(cam, param)
Base.getindex(cam::Camera, reg::Register) = getparam(cam, reg)
Base.getindex(cam::Camera, key) = error("invalid key type `$(typeof(key))`")

Base.setindex!(cam::Camera, val, param::Param) = setparam!(cam, param, val)
Base.setindex!(cam::Camera, val, reg::Register) = setparam!(cam, reg, val)
Base.setindex!(cam::Camera, val, key) = error("invalid key type `$(typeof(key))`")

# Other overrides.
Base.eltype(cam::Camera) = eltype(eltype(cam.bufs))
Base.length(cam::Camera) = length(cam.bufs)
Base.getindex(cam::Camera, i::Integer) = getindex(cam.bufs, i)

@inline checkstatus(status::Status) =
    (status == PHX_OK || throw(PHXError(status)); nothing)

#-------------------------------------------------------------------------------
# Get/set Frame Grabber Parameters
# ================================

"""
    getparam(cam, key) -> val

yields the value `val` associated with `key` for the camera `cam`.  Argument
`key` can be a frame grabber parameter or a CoaXPress register (which must be
readable, *i.e.* `isreadable(key)` must be true).  Beware that the camera board
must be open before retrieving parameters (otherwise you get a
`PHX_ERROR_BAD_HANDLE` error).

This method implements the syntax:

    cam[key] -> val

A variant is available which does not throw an error but returns a status and
stores the value in `buf` (a pointer or a reference):

    _getparam(cam, key, buf) -> status


See also: [`setparam!`](@ref), [`isreadable`](@ref).

"""
function getparam(cam::Camera,
                  key::Param{T,A}) :: T where {T<:Integer,A<:Readable}
    buf = Ref{T}()
    checkstatus(_getparam(cam, key, buf))
    return buf[]
end

function getparam(cam::Camera,
                  key::Param{String,A}) :: String where {A<:Readable}
    buf = Ref{Ptr{UInt8}}()
    checkstatus(_getparam(cam, key, buf))
    return (buf[] == C_NULL ? "" : unsafe_string(buf[]))
end

function getparam(cam::Camera,
                  key::Param{Ptr{Cvoid},A}) :: Ptr{Cvoid} where {A<:Readable}
    buf = Ref{Ptr{Cvoid}}()
    checkstatus(_getparam(cam, key, buf))
    return buf[]
end

function getparam(cam::Camera,
                  key::RegisterString{N,A}) where {N,A<:Readable}
    buf = Array{UInt8}(undef, N)
    checkstatus(_readregister(cam, key, buf, N))
    return unsafe_string(pointer(buf))
end

function getparam(cam::Camera,
                  key::RegisterValue{T,A}) where {T<:Real,A<:Readable}
    buf = Ref{T}()
    checkstatus(_getparam(cam, key, buf))
    return buf[]
end

getparam(cam::Camera, key::RegisterAddress{T,A}) where {T,A<:Readable} =
    getparam(cam, resolve(cam, key))

getparam(cam::Camera, key::Param) =
    error("unreadable parameter or undetermined parameter type")

getparam(cam::Camera, key::Register) =
    error("attempt to get an unreadable CoaXPress parameter")

function _getparam(cam::Camera,
                   key::Param{T,A},
                   buf::Union{Ptr,Ref}) where {T,A<:Readable}
    ccall(_PHX_ParameterGet[], Status, (Handle, Cuint, Ptr{Cvoid}),
          cam.handle, key.ident, buf)
end

function _getparam(cam::Camera,
                   key::RegisterValue{T,A},
                   buf::Ref{T}) where {T<:Real,A<:Readable}
    status = _readregister(cam, key, buf, sizeof(T))
    if cam.swap
        buf[] = bswap(buf[])
    end
    return status
end

@doc @doc(getparam) _getparam

"""

    resolve(cam, regaddr) -> regval

yields the CoaXPress register at indirect register address `regaddr` for camera
`cam`.

See also: [`getparam`](@ref), [`setparam!`](@ref).

"""
function resolve(cam::Camera, reg::RegisterAddress{T,A}) where {T,A<:AccessMode}
    buf = Ref{UInt32}()
    checkstatus(_readregister(cam, reg, buf, 4))
    addr = (cam.swap ? bswap(buf[]) : buf[])
    return RegisterValue{T,A}(addr)
end

"""
    setparam!(cam, key, val)

set the value associated with `key` to be `val` for the camera `cam`.  Argument
`key` can be a frame grabber parameter or a CoaXPress register (which must be
writable, *i.e.* `iswritable(key)` must be true).  This method implements the
syntax:

    cam[key] = val

A variant is available which does not throw an error but returns a status and
stores the value in `buf` (a pointer or a reference):

    _setparam(cam, key, buf) -> status

Beware that this low-level version does not check its arguments.


See also: [`getparam`](@ref), [`iswritable`](@ref).

"""
function setparam!(cam::Camera,
                   key::Param{T,A},
                   val::Integer) where {T<:Integer,A<:Writable}
    checkstatus(_setparam!(cam, key, Ref{T}(val)))
end

function setparam!(cam::Camera,
                   key::Param{String,A},
                   str::AbstractString) where {A<:Writable}
    checkstatus(_setparam!(cam, key, Ref(pointer(cstring(str)))))
end

function setparam!(cam::Camera,
                   key::Param{Nothing,A},
                   ::Nothing) where {A<:Writable}
    checkstatus(_setparam!(cam, key, C_NULL))
end

function setparam!(cam::Camera,
                   key::Param{Ptr{T},A},
                   buf::Union{Vector{T},Ptr{T},Ref{T}}) where {T,A<:Writable}
    checkstatus(_setparam!(cam, key, buf))
end

function setparam!(cam::Camera,
                   key::Param{Ptr{Cvoid},A},
                   buf::Union{Vector,Ptr,Ref}) where {A<:Writable}
    checkstatus(_setparam!(cam, key, buf))
end

function setparam!(cam::Camera,
                   key::RegisterString{N,A},
                   str::AbstractString) where {N,A<:Writable}
    buf = Array{UInt8}(undef, N)
    i = 0
    @inbounds for c in str
        if i ≥ N
            break
        end
        c != '\0' || error("string must not have embedded NUL characters")
        i += 1
        buf[i] = c
    end
    @inbounds while i < N
        i += 1
        buf[i] = zero(UInt8)
    end
    checkstatus(_writeregister(cam, key, buf, N))
end

function setparam!(cam::Camera,
                   key::RegisterValue{T,A},
                   val::Real) where {T<:Real,A<:Writable}
    setparam!(cam, key, convert(T, val))
end

function setparam!(cam::Camera,
                   key::RegisterValue{T,A},
                   val::T) where {T<:Real,A<:Writable}
    checkstatus(_setparam!(cam, key, Ref{T}(val)))
end

function setparam!(cam::Camera,
                   key::RegisterAddress{T,A},
                   val) where {T,A<:Writable}
    setparam!(cam, resolve(cam, key), val)
end

setparam!(cam::Camera, key::Param, val) =
    error("unwritable parameter or undetermined parameter type")

setparam!(cam::Camera, key::Register, val) =
    error("attempt to set an unwritable CoaXPress parameter")

function _setparam!(cam::Camera,
                    key::Param{T,A},
                    buf::Union{Ptr,Ref,Vector}) where {T,A<:Writable}
    ccall(_PHX_ParameterSet[], Status, (Handle, Cuint, Ptr{Cvoid}),
          cam.handle, key.ident, buf)
end

function _setparam!(cam::Camera,
                    key::RegisterValue{T,A},
                    buf::Ref{T}) where {T<:Real,A<:Writable}
    if cam.swap
        buf[] = bswap(buf[])
    end
    _writeregister(cam, key, buf, sizeof(T))
end

@doc @doc(setparam!) _setparam!

"""
    flushcache(cam)

makes sure that cached frame grabber parameters are effectively written to the
hardware.

"""
function flushcache(cam::Camera)
    cam[Param{Ptr{Cvoid},WriteOnly}(PHX_DUMMY_PARAM|PHX_CACHE_FLUSH)] = C_NULL
    nothing
end

"""
    saveconfig(cam, name, what = PHX_SAVE_ALL)

saves the actual configuration of camera `cam` in file `name`.  Optional
argument `what` specifies which parameters to save, it can be a combination
(*i.e.* bitwise or) of:

- `PHX_SAVE_CAM` to save the camera specific parameters.  These describe the
  camera.

- `PHX_SAVE_SYS` to save the system specific parameters.  These describe how
  the camera is connected to the Active Silicon board.

- `PHX_SAVE_APP` to save the application specific parameters.

- `PHX_SAVE_ALL` to save all three of the above types of parameters.

"""
function saveconfig(cam::Camera, name::AbstractString,
                    what::Integer = PHX_SAVE_ALL)
    flushcache(cam)
    status = ccall(_PHX_Action[], Status,
                   (Handle, Action, ActionParam, Ptr{Cvoid}),
                   cam.handle, PHX_CONFIG_SAVE, what, cstring(name))
    checkstatus(status)
end

#------------------------------------------------------------------------------
# Reading/Writing CoaXPress Registers
# ===================================
#

function send(cam::Camera, reg::RegisterCommand{T}) where {T}
    data = Ref{T}(cam.swap ? bswap(reg.value) : reg.value)
    checkstatus(_writeregister(cam, reg, data, sizeof(T)))
end

readstream(args...) = checkstatus(_readstream(args...))


#-------------------------------------------------------------------------------
# Low Level Wrapper to Phoenix Dynamic Library
# ============================================
#

const _PHX_FUNCTIONS = (:_PHX_Create, :_PHX_Open, :_PHX_Close, :_PHX_Destroy,
                        :_PHX_StreamRead, :_PHX_ParameterGet,
                        :_PHX_ParameterSet, :_PHX_ControlRead,
                        :_PHX_ControlWrite, :_PHX_Action,
                        :_PHX_ErrCodeDecode, :_PHX_ErrHandlerDefault)
for sym in _PHX_FUNCTIONS
    @eval const $sym = Ref{Ptr{Cvoid}}(0)
end

function _errorhandler end
function _callback end

const _errorhandler_ptr = Ref{Ptr{Cvoid}}(0)
const _callback_ptr = Ref{Ptr{Cvoid}}(0)
function __init__()
    _errorhandler_ptr[] = @cfunction(_errorhandler, Nothing,
                                     (Ptr{Cchar}, Status, Ptr{Cchar}))
    _callback_ptr[] = @cfunction(_callback, Nothing,
                                 (Handle, UInt32, Ptr{Cvoid}))

    # Manage to load the dynamic library and its symbols with appropriate
    # flags.  It is still needed to start Julia with the correct dynamic library
    # search path (as checked above).
    handle = Libdl.dlopen(_PHXLIB, (Libdl.RTLD_LAZY |
                                    Libdl.RTLD_DEEPBIND |
                                    Libdl.RTLD_GLOBAL))
    for sym in _PHX_FUNCTIONS
        @eval $sym[] = Libdl.dlsym($handle, $(string(sym)[2:end]))
    end
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
Base.open(::Type{M}; kwds...) where {M<:CameraModel} =
    open(Camera{M}(); kwds...)

function Base.open(cam::Camera;
                   configfile::String = "",
                   boardtype::Integer = 0,
                   boardnumber::Integer = PHX_BOARD_AUTO,
                   channelnumber::Integer = PHX_CHANNEL_AUTO,
                   boardmode::Integer = PHX_MODE_NORMAL,
                   quiet::Bool = false)
    # Check state.
    if cam.state != 0
        if cam.state == 1 || cam.state == 2
            @warn "camera has already been opened"
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

    # Set initial parameters.
    if boardtype != 0
        checkstatus(_setparam!(cam, PHX_BOARD_VARIANT, ref_boardtype))
    end
    checkstatus(_setparam!(cam, PHX_BOARD_NUMBER,   ref_boardnumber))
    checkstatus(_setparam!(cam, PHX_CHANNEL_NUMBER, ref_channelnumber))
    checkstatus(_setparam!(cam, PHX_CONFIG_MODE,    ref_boardmode))
    checkstatus(_setparam!(cam, PHX_CONFIG_FILE,    ref_configfile))

    # Open the camera.
    checkstatus(ccall(_PHX_Open[], Status, (Handle,), cam.handle))
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

        # Get current width and height and initialize parameters.
        width  = cam[CXP_WIDTH_ADDRESS]
        height = cam[CXP_HEIGHT_ADDRESS]
        cam[PHX_CAM_ACTIVE_XOFFSET] = 0
        cam[PHX_CAM_ACTIVE_YOFFSET] = 0
        cam[PHX_CAM_ACTIVE_XLENGTH] = width
        cam[PHX_CAM_ACTIVE_YLENGTH] = height

        if ! quiet
            vendorname  = cam[CXP_DEVICE_VENDOR_NAME]
            modelname   = cam[CXP_DEVICE_MODEL_NAME]
            pixelformat = cam[CXP_PIXEL_FORMAT_ADDRESS]
            @info "Vendor name:  $vendorname"
            @info "Model name:   $modelname"
            @info "Image size:   $width × $height pixels"
            @info "Pixel format: 0x$(string(pixelformat, base=16))"
        end
    end

    # Apply specific post-open configuration.
    openhook(cam)

    return cam
end

"""
    openhook(cam)

performs specific operations just after camera `cam` has been opened.  This
function should return nothing but may throw exceptions to signal errors.

See also: [`open`](@ref)

"""
openhook(cam::Camera) = nothing

"""
    close(cam)

closes an Active Silicon board, releasing the hardware.  The camera is
automatically closed when finalized by the garbage collector, so calling this
method is optional.

See also: [`open`](@ref).

"""
function Base.close(cam::Camera)
    if cam.state == 0
        @warn "camera has already been closed"
    elseif cam.state == 1
        # Note that PHX_Close requires the address of the handle but left its
        # contents unchanged.
        ref = Ref(cam.handle)
        status = ccall(_PHX_Close[], Status, (Ptr{Handle},), ref)
        #cam.handle = ref[] # not needed (cf. note above)?
        status == PHX_OK || throw(PHXError(status))
        cam.state = 0
    elseif cam.state == 2
        error("cannot close camera while acquisition is running")
    else
        error("camera structure corrupted")
    end
    return nothing
end


"""
    _readstream(cam, cmd, ptr) -> status

initiates and controls the acquisition of stream data such as images.  The
destination of the data can be system memory, graphics memory, or other user
addressable memory, such as slave PCI cards.  `cam` is a PHX camera, `cmd` is
the command to be performed and `ptr` is a command-specific parameter (ususally
a pointer).

"""
_readstream(cam::Camera, cmd::Acq, ptr::Union{Ref,Ptr}) =
    ccall(_PHX_StreamRead[], Status, (Handle, Acq, Ptr{Cvoid}),
          cam.handle, cmd, ptr)

"""
    _readregister(cam, reg, data, num, timeout = cam.timeout)

reads register `reg` from camera `cam`.

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
    ccall(_PHX_ControlRead[], Status,
          (Handle, UInt32, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{UInt32}, UInt32),
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
    ccall(_PHX_ControlWrite[], Status,
          (Handle, UInt32, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{UInt32}, UInt32),
          handle, src.port, param, buf, num, timeout)
end
