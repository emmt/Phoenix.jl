#
# Phoenix.jl -
#
# Julia interface to ActiveSilicon Phoenix (PHX) library.
#
#------------------------------------------------------------------------------
#
# This file is part of the `Phoenix.jl` package which is licensed under the MIT
# "Expat" License.
#
# Copyright (C) 2016, Éric Thiébaut & Jonathan Léger.
# Copyright (C) 2017, Éric Thiébaut.
#

module Phoenix

# Import `ScientificCameras` methods in such a way (i.e. with `importall`) that
# they can be extended in this modul and re-exprot them to make things easier
# for the end-user.

importall ScientificCameras
import ScientificCameras: ScientificCamera
using ScientificCameras.PixelFormats
export
    PHXError,
    open,
    close,
    read,
    start,
    stop,
    abort,
    wait,
    release,
    getdecimation,
    setdecimation!,
    getfullsize,
    getfullwidth,
    getfullheight,
    getroi,
    setroi!,
    checkroi,
    getpixelformat,
    setpixelformat!,
    getcapturebitstype,
    supportedpixelformats,
    bitsperpixel,
    equivalentbitstype,
    getspeed,
    setspeed!,
    checkspeed,
    getgain,
    setgain!,
    getbias,
    setbias!,
    getgamma,
    setgamma!

include("constants.jl")
include("CoaXPress.jl")
include("types.jl")
include("base.jl")
include("utils.jl")
include("errors.jl")
include("acquisition.jl")

module Development

import
    ..AccessMode,
    ..Unreachable,
    ..ReadOnly,
    ..WriteOnly,
    ..ReadWrite,
    ..Readable,
    ..Writable,
    ..Handle,
    ..FnTypes,
    ..PhxFn,
    ..CamConfigLoad,
    ..ActionParam,
    ..Action,
    ..ComParam,
    ..ParamCompatibility,
    ..ParamValue,
    ..IOMethod,
    ..BoardInfo,
    ..PcieInfo,
    ..CxpInfo,
    ..Acq,
    ..BufferParam,
    ..Timeouts,
    ..Status,
    ..LutCtrl,
    ..ControlPort,
    ..ImageBuff,
    ..UserBuff,
    ..TimeStamp,
    ..Colour,
    ..LutInfo,
    ..Param,
    ..Register,
    ..RegisterValue,
    ..RegisterEnum,
    ..RegisterAddress,
    ..RegisterCommand,
    ..RegisterString,
    ..checkstatus,
    ..getparam,
    .._getparam,
    ..resolve,
    ..setparam!,
    .._setparam!,
    ..flushcache,
    ..saveconfig,
    ..readstream,
    .._readstream,
    .._readregister,
    .._readcontrol,
    .._writeregister,
    .._writecontrol,
    ..fieldindex,
    ..CAPTURE_FORMATS,
    ..capture_format,
    ..capture_format_bits,
    ..best_capture_format,
    ..cstring,
    ..is_coaxpress,
    ..assert_coaxpress,
    ..getvendorname,
    ..getmodelname,
    ..getdevicemanufacturer,
    ..getdeviceversion,
    ..getdeviceserialnumber,
    ..getdeviceuserid,
    ..subsampling_parameter,
    ..gettimeofday,
    ..TimeVal,
    ..TimeSpec,
    ..AcquisitionContext,
    ..CameraModel,
    ..Camera,
    ..isforever,
    ..geterrormessage,
    ..geterrorsymbol,
    ..printerror,
    ..openhook,
    ..starthook,
    ..stophook

export
    AccessMode,
    Unreachable,
    ReadOnly,
    WriteOnly,
    ReadWrite,
    Readable,
    Writable,
    Handle,
    FnTypes,
    PhxFn,
    CamConfigLoad,
    ActionParam,
    Action,
    ComParam,
    ParamCompatibility,
    ParamValue,
    IOMethod,
    BoardInfo,
    PcieInfo,
    CxpInfo,
    Acq,
    BufferParam,
    Timeouts,
    Status,
    LutCtrl,
    ControlPort,
    ImageBuff,
    UserBuff,
    TimeStamp,
    Colour,
    LutInfo,
    Param,
    Register,
    RegisterValue,
    RegisterEnum,
    RegisterAddress,
    RegisterCommand,
    RegisterString,
    checkstatus,
    getparam,
    _getparam,
    resolve,
    setparam!,
    _setparam!,
    flushcache,
    saveconfig,
    readstream,
    _readstream,
    _readregister,
    _readcontrol,
    _writeregister,
    _writecontrol,
    fieldindex,
    CAPTURE_FORMATS,
    capture_format,
    capture_format_bits,
    best_capture_format,
    cstring,
    is_coaxpress,
    assert_coaxpress,
    getvendorname,
    getmodelname,
    getdevicemanufacturer,
    getdeviceversion,
    getdeviceserialnumber,
    getdeviceuserid,
    subsampling_parameter,
    gettimeofday,
    TimeVal,
    TimeSpec,
    AcquisitionContext,
    CameraModel,
    Camera,
    isforever,
    geterrormessage,
    geterrorsymbol,
    printerror,
    openhook,
    starthook,
    stophook

end # module Phoenix.Development

include("models.jl")

end # module Phoenix
