#
# CoaXPress.jl -
#
# Julia interface to CoaXPress cameras via Phoenix (PHX) library.
#
#------------------------------------------------------------------------------
#
# This file is part of the `Phoenix.jl` package which is licensed under the MIT
# "Expat" License.
#
# Copyright (C) 2016, Éric Thiébaut & Jonathan Léger.
# Copyright (C) 2017, Éric Thiébaut.
#

export
    CXP_MAGIC,
    CXP_STANDARD,
    CXP_REVISION,
    CXP_XML_MANIFEST_SIZE,
    CXP_XML_MANIFEST_SELECTOR,
    CXP_XML_VERSION,
    CXP_XML_SCHEME_VERSION,
    CXP_XML_URL_ADDRESS,
    CXP_IIDC2_ADDRESS,
    CXP_DEVICE_VENDOR_NAME,
    CXP_DEVICE_MODEL_NAME,
    CXP_DEVICE_MANUFACTURER_INFO,
    CXP_DEVICE_VERSION,
    CXP_DEVICE_SERIAL_NUMBER,
    CXP_DEVICE_USER_ID,
    CXP_WIDTH_ADDRESS,
    CXP_HEIGHT_ADDRESS,
    CXP_ACQUISITION_MODE_ADDRESS,
    CXP_ACQUISITION_START_ADDRESS,
    CXP_ACQUISITION_STOP_ADDRESS,
    CXP_PIXEL_FORMAT_ADDRESS,
    CXP_DEVICE_TAP_GEOMETRY_ADDRESS,
    CXP_IMAGE1_STREAM_ID_ADDRESS,
    CXP_CONNECTION_RESET,
    CXP_DEVICE_CONNECTION_ID,
    CXP_MASTER_HOST_CONNECTION_ID,
    CXP_CONTROL_PACKET_SIZE_MAX,
    CXP_STREAM_PACKET_SIZE_MAX,
    CXP_CONNECTION_CONFIG,
    CXP_CONNECTION_CONFIG_DEFAULT,
    CXP_TEST_MODE,
    CXP_TEST_ERROR_COUNT_SELECTOR,
    CXP_TEST_ERROR_COUNT,
    CXP_TEST_PACKET_COUNT_TX,
    CXP_TEST_PACKET_COUNT_RX,
    CXP_HS_UP_CONNECTION,
    CXP_MANUFACTURER

#---------------------------------------------------------------------------
# TYPES

"""
Abstract type `Register` is used to store (among others) the address (as an
`UInt32` value) of a CoaXPress register.  All concrete sub-types must have a
first member `addr::UInt32`.
"""
abstract type Register end

## Manage to automatically convert a register to a pointer to its
## address member. See refpointer.jl
#function unsafe_convert{T<:Register}(::Type{Ptr{UInt32}}, rgst::T)
#    if isbits(T)
#        return convert(Ptr{UInt32}, data_pointer_from_objref(rgst))
#    else
#        return convert(Ptr{UInt32}, data_pointer_from_objref(rgst.addr))
#    end
#end

"""
`RegisterValue{T}(addr)` is a value of type `T` stored at address `addr`.
"""
immutable RegisterValue{T} <: Register
    addr::UInt32
end

const RegisterEnum = RegisterValue{UInt32}

"""
`RegisterAddress(addr)` stores at address `addr` the address of another
register.
"""
immutable RegisterAddress <: Register
    addr::UInt32
end

"""
`RegisterConstant{T}(addr,val)` is a constant of type `T` stored at address
`addr` with value `val`.
"""
immutable RegisterConstant{T} <: Register
    addr::UInt32
    value::T
end

"""
`RegisterString{N}(addr)` is a fixed length string of length `N` stored at
address `addr`.
"""
immutable RegisterString{N} <: Register
    addr::UInt32
end

"""
`RegisterData(addr)` represents arbitrary data stored at address `addr`.
"""
immutable RegisterData{T} <: Register
    addr::UInt32
end

#---------------------------------------------------------------------------
# CONSTANTS

# Value returned by reading at CXP_STANDARD register.
const CXP_MAGIC = UInt32(0xC0A79AE5)

# Addresses of standard CoaXPress registers.
const CXP_STANDARD                    = RegisterValue{UInt32}(0x00000000)
const CXP_REVISION                    = RegisterValue{UInt32}(0x00000004)
const CXP_XML_MANIFEST_SIZE           = RegisterValue{UInt32}(0x00000008)
const CXP_XML_MANIFEST_SELECTOR       = RegisterValue{UInt32}(0x0000000C)
const CXP_XML_VERSION                 = RegisterValue{UInt32}(0x00000010)
const CXP_XML_SCHEME_VERSION          = RegisterValue{UInt32}(0x00000014)
const CXP_XML_URL_ADDRESS             = RegisterValue{UInt32}(0x00000018)
const CXP_IIDC2_ADDRESS               = RegisterValue{UInt32}(0x0000001C)
const CXP_DEVICE_VENDOR_NAME          = RegisterString{32}(0x00002000)
const CXP_DEVICE_MODEL_NAME           = RegisterString{32}(0x00002020)
const CXP_DEVICE_MANUFACTURER_INFO    = RegisterString{48}(0x00002040)
const CXP_DEVICE_VERSION              = RegisterString{32}(0x00002070)
const CXP_DEVICE_SERIAL_NUMBER        = RegisterString{16}(0x000020B0)
const CXP_DEVICE_USER_ID              = RegisterString{16}(0x000020C0)
const CXP_WIDTH_ADDRESS               = RegisterAddress(0x00003000)
const CXP_HEIGHT_ADDRESS              = RegisterAddress(0x00003004)
const CXP_ACQUISITION_MODE_ADDRESS    = RegisterAddress(0x00003008)
const CXP_ACQUISITION_START_ADDRESS   = RegisterAddress(0x0000300C)
const CXP_ACQUISITION_STOP_ADDRESS    = RegisterAddress(0x00003010)
const CXP_PIXEL_FORMAT_ADDRESS        = RegisterAddress(0x00003014)
const CXP_DEVICE_TAP_GEOMETRY_ADDRESS = RegisterAddress(0x00003018)
const CXP_IMAGE1_STREAM_ID_ADDRESS    = RegisterAddress(0x0000301C)
const CXP_CONNECTION_RESET            = RegisterValue{UInt32}(0x00004000)
const CXP_DEVICE_CONNECTION_ID        = RegisterValue{UInt32}(0x00004004)
const CXP_MASTER_HOST_CONNECTION_ID   = RegisterValue{UInt32}(0x00004008)
const CXP_CONTROL_PACKET_SIZE_MAX     = RegisterValue{UInt32}(0x0000400C)
const CXP_STREAM_PACKET_SIZE_MAX      = RegisterValue{UInt32}(0x00004010)
const CXP_CONNECTION_CONFIG           = RegisterEnum(0x00004014)
const CXP_CONNECTION_CONFIG_DEFAULT   = RegisterValue{UInt32}(0x00004018)
const CXP_TEST_MODE                   = RegisterValue{UInt32}(0x0000401C)
const CXP_TEST_ERROR_COUNT_SELECTOR   = RegisterValue{UInt32}(0x00004020)
const CXP_TEST_ERROR_COUNT            = RegisterValue{UInt32}(0x00004024)
const CXP_TEST_PACKET_COUNT_TX        = RegisterValue{UInt32}(0x00004028)
const CXP_TEST_PACKET_COUNT_RX        = RegisterValue{UInt32}(0x00004030)
const CXP_HS_UP_CONNECTION            = RegisterValue{UInt32}(0x0000403C)
const CXP_MANUFACTURER                = RegisterValue{UInt32}(0x00006000)

#---------------------------------------------------------------------------
