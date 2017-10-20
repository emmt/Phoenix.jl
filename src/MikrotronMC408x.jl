#
# MikrotronMC408x.jl --
#
# Configuration and control of CoaXPress camera Mikrotron MC408x.
#
#------------------------------------------------------------------------------
#
# This file is part of the `Phoenix.jl` package which is licensed under the MIT
# "Expat" License.
#
# Copyright (C) 2016, Éric Thiébaut & Jonathan Léger.
# Copyright (C) 2017, Éric Thiébaut.
#

module MikrotronMC408x

importall ScientificCameras
import ScientificCameras: ScientificCamera, ROI
using ScientificCameras.PixelFormats
using Phoenix
importall Phoenix.Development

#
# CoaXPress camera constants for a Mikrotron MC408x camera.  These values have
# been extracted from the XML configuration file of the camera.
#
# FIXME: The XML file says that register HsUpConnection is at address 0x4030,
#         while CoaXPress standard says that it is at address 0x403C.
#

const ACQUISITION_MODE  = RegisterValue{UInt32,ReadWrite}(0x8200)
const ACQUISITION_START = RegisterCommand{UInt32}(0x8204, 1)
const ACQUISITION_STOP  = RegisterCommand{UInt32}(0x8208, 1)

const ACQUISITION_BURST_FRAME_COUNT = RegisterValue{UInt32,ReadWrite}(0x8914)
const TRIGGER_SELECTOR              = RegisterEnum{ReadWrite}(0x8900)
const TRIGGER_MODE                  = RegisterEnum{ReadWrite}(0x8904)
const TRIGGER_SOURCE                = RegisterEnum{ReadWrite}(0x8908)
const TRIGGER_ACTIVATION            = RegisterEnum{ReadWrite}(0x890C)
const TRIGGER_COUNT                 = RegisterValue{Void,Unreachable}(0x891C)
const TRIGGER_DEBOUNCER             = RegisterValue{Void,Unreachable}(0x8918)
const TRIGGER_SOFTWARE              = RegisterEnum{WriteOnly}(0x8910)
const TEST_IMAGE_SELECTOR           = RegisterEnum{ReadWrite}(0x9000)
const EXPOSURE_MODE                 = RegisterEnum{ReadWrite}(0x8944)
const EXPOSURE_TIME                 = RegisterValue{UInt32,ReadWrite}(0x8840)
const EXPOSURE_TIME_MAX             = RegisterValue{UInt32,ReadOnly}(0x8818)
const ACQUISITION_FRAME_RATE        = RegisterValue{UInt32,ReadWrite}(0x8814)
const ACQUISITION_FRAME_RATE_MIN    = 10 # FIXME: the XML file says 16
const ACQUISITION_FRAME_RATE_MAX    = RegisterValue{UInt32,ReadOnly}(0x881C)
const SEQUENCER_CONFIGURATION_MODE  = RegisterValue{UInt32,Unreachable}(0x8874)
const SEQUENCER_MODE                = RegisterValue{UInt32,Unreachable}(0x8870)
const SEQUENCER_SET_SELECTOR        = RegisterValue{Void,Unreachable}(0x8878)
const SEQUENCER_SET_SAVE            = RegisterValue{Void,Unreachable}(0x887C)
const SEQUENCER_SET_NEXT            = RegisterValue{Void,Unreachable}(0x8888)
const USER_SET_SELECTOR             = RegisterEnum{ReadWrite}(0x8820)
const USER_SET_LOAD                 = RegisterCommand{UInt32}(0x8824, 1)
const USER_SET_SAVE                 = RegisterCommand{UInt32}(0x8828, 1)
const USER_SET_DEFAULT_SELECTOR     = RegisterEnum{ReadWrite}(0x882C)
const DEVICE_RESET                  = RegisterCommand{UInt32}(0x8300, 1)

# Image Format Control.
const HORIZONTAL_INCREMENT          = 16
const VERTICAL_INCREMENT            =  2
const REGION_SELECTOR               = RegisterEnum{ReadWrite}(0x8180)
const REGION_MODE                   = RegisterEnum{ReadWrite}(0x8184)
const REGION_DESTINATION            = RegisterEnum{ReadWrite}(0x8188) # always 0x0, i.e. "Stream1"
const WIDTH                         = RegisterValue{UInt32,ReadWrite}(0x8118)
const HEIGHT                        = RegisterValue{UInt32,ReadWrite}(0x811c)
const OFFSET_X                      = RegisterValue{UInt32,ReadWrite}(0x8800)
const OFFSET_Y                      = RegisterValue{UInt32,ReadWrite}(0x8804)
const DECIMATION_HORIZONTAL         = RegisterValue{UInt32,ReadWrite}(0x8190)
const DECIMATION_VERTICAL           = RegisterValue{UInt32,ReadWrite}(0x818c)
const SENSOR_WIDTH                  = RegisterValue{UInt32,ReadOnly}(0x8808)
const SENSOR_HEIGHT                 = RegisterValue{UInt32,ReadOnly}(0x880c)
# WidthMax = ((div(SENSOR_WIDTH - OFFSET_X), 16)*16) # use a bit mask
# HeightMax = ((div(SENSOR_HEIGHT - OFFSET_Y), 2)*2) # use a bit mask
const TAP_GEOMETRY = RegisterEnum{ReadOnly}(0x8160) # always 0x0, i.e. "Geometry_1X_1Y"
const PIXEL_FORMAT = RegisterEnum{ReadWrite}(0x8144)
const IMAGE1_STREAM_ID = RegisterValue{UInt32,ReadOnly}(0x8164)
# const DEVICE_SCANTYPE = RegisterEnum{ReadOnly}(????) always 0x0, i.e. "Areascan"

const REGION_MODE_OFF = UInt32(0x00)
const REGION_MODE_ON  = UInt32(0x01)

const PIXEL_FORMAT_MONO8     = UInt32(0x0101)
const PIXEL_FORMAT_MONO10    = UInt32(0x0102)
const PIXEL_FORMAT_BAYERGR8  = UInt32(0x0311)
const PIXEL_FORMAT_BAYERGR10 = UInt32(0x0312)

const REGION_SELECTOR_REGION0 = UInt32(0x0)
const REGION_SELECTOR_REGION1 = UInt32(0x1)
const REGION_SELECTOR_REGION2 = UInt32(0x2)

# Bits for CONNECTION_CONFIG register (the value is a conbination of speed and
# number of connections):
const CONNECTION_CONFIG_SPEED1250 = UInt32(0x00028)
const CONNECTION_CONFIG_SPEED2500 = UInt32(0x00030)
const CONNECTION_CONFIG_SPEED3125 = UInt32(0x00038)
const CONNECTION_CONFIG_SPEED5000 = UInt32(0x00040)
const CONNECTION_CONFIG_SPEED6250 = UInt32(0x00048)
const CONNECTION_CONFIG_CONNECTION1 = UInt32(0x10000)
const CONNECTION_CONFIG_CONNECTION2 = UInt32(0x20000)
const CONNECTION_CONFIG_CONNECTION3 = UInt32(0x30000)
const CONNECTION_CONFIG_CONNECTION4 = UInt32(0x40000)

const GAIN                            = RegisterValue{UInt32,ReadWrite}(0x8850)
const GAIN_MIN                        =   50
const GAIN_MAX                        = 1000
const BLACK_LEVEL                     = RegisterValue{UInt32,ReadWrite}(0x8854)
const BLACK_LEVEL_MIN                 =    0
const BLACK_LEVEL_MAX                 =  500
const GAMMA                           = RegisterValue{Float32,ReadWrite}(0x8858)
const GAMMA_MIN                       =  0.1
const GAMMA_MAX                       =  3.0
const GAMMA_INCREMENT                 =  0.1
#const LINE_SOURCE                    = RegisterEnum{ReadWrite}(0x????)
#const LINE_SELECTOR                  = RegisterEnum{ReadWrite}(0x????)
const LINE_INVERTER                   = RegisterEnum{ReadWrite}(0x8A20)
const TX_LOGICAL_CONNECTION_RESET     = RegisterValue{Void,Unreachable}(0x9010)
const PRST_ENABLE                     = RegisterValue{Void,Unreachable}(0x9200)
const PULSE_DRAIN_ENABLE              = RegisterValue{Void,Unreachable}(0x9204)
const CUSTOM_SENSOR_CLK_ENABLE        = RegisterValue{Void,Unreachable}(0x9300)
const CUSTOM_SENSOR_CLK               = RegisterValue{Void,Unreachable}(0x9304)
const DEVICE_INFORMATION              = RegisterValue{Void,Unreachable}(0x8A04)
const DEVICE_INFORMATION_SELECTOR     = RegisterValue{Void,Unreachable}(0x8A00)
const ANALOG_REGISTER_SET_SELECTOR    = RegisterValue{Void,Unreachable}(0x20000)
const ANALOG_REGISTER_SELECTOR        = RegisterValue{Void,Unreachable}(0x20004)
const ANALOG_VALUE                    = RegisterValue{Void,Unreachable}(0x20008)
const INFO_FIELD_FRAME_COUNTER_ENABLE = RegisterValue{Void,Unreachable}(0x9310)
const INFO_FIELD_TIME_STAMP_ENABLE    = RegisterValue{Void,Unreachable}(0x9314)
const INFO_FIELD_ROI_ENABLE           = RegisterValue{Void,Unreachable}(0x9318)
const FIXED_PATTERN_NOISE_REDUCTION   = RegisterValue{Void,Unreachable}(0x8A10)
const FILTER_MODE                     = RegisterValue{Void,Unreachable}(0x10014)
const PIXEL_TYPE_F                    = RegisterValue{Void,Unreachable}(0x51004)
const DIN1_CONNECTOR_TYPE             = RegisterValue{Void,Unreachable}(0x8A30)
const IS_IMPLEMENTED_MULTI_ROI        = RegisterValue{Void,Unreachable}(0x50004)
const IS_IMPLEMENTED_SEQUENCER        = RegisterValue{Void,Unreachable}(0x50008)
const CAMERA_TYPE_HEX                 = RegisterValue{Void,Unreachable}(0x51000)
const CAMERA_STATUS                   = RegisterValue{Void,Unreachable}(0x10002200)
const IS_STOPPED                      = RegisterValue{Void,Unreachable}(0x10002204)


# Singleton to uniquely identify this camera model.
struct MikrotronMC408xModel <: CameraModel; end

# Initialize the camera after board is open.
function openhook(cam::Camera{MikrotronMC408xModel})

    # Sanity checks.
    assert_coaxpress(cam)
    vendorname = cam[CXP_DEVICE_VENDOR_NAME]
    if vendorname != "Mikrotron GmbH"
        error("bad device vendor name (got \"$vendorname\", expecting \"Mikrotron GmbH\")")
    end
    modelname = cam[CXP_DEVICE_MODEL_NAME]
    if length(modelname) != 6 || modelname[1:5] != "MC408" ||
        (modelname[6] != '2' && modelname[6] != '3' &&
         modelname[6] != '6' && modelname[6] != '7')
        error("bad device model name (got \"$modelname\", expecting \"MC408[2367]\")")
    end

    # Get size of current ROI.
    xsub = Int(cam[DECIMATION_HORIZONTAL])
    ysub = Int(cam[DECIMATION_VERTICAL])
    width  = div(Int(cam[WIDTH]),  xsub)
    height = div(Int(cam[HEIGHT]), ysub)

    # The following settings are the same as the contents of the configuration
    # file "Mikrotron_MC4080_CXP.pcf".
    cam[PHX_BOARD_VARIANT]      = PHX_DIGITAL
    cam[PHX_CAM_TYPE]           = PHX_CAM_AREASCAN_ROI
    cam[PHX_CAM_FORMAT]         = PHX_CAM_NON_INTERLACED
    cam[PHX_CAM_CLOCK_POLARITY] = PHX_CAM_CLOCK_POS
    cam[PHX_CAM_SRC_COL]        = PHX_CAM_SRC_MONO
    cam[PHX_CAM_DATA_VALID]     = PHX_DISABLE
    cam[PHX_CAM_HTAP_NUM]       = 1
    cam[PHX_CAM_HTAP_DIR]       = PHX_CAM_HTAP_LEFT
    cam[PHX_CAM_HTAP_TYPE]      = PHX_CAM_HTAP_LINEAR
    cam[PHX_CAM_HTAP_ORDER]     = PHX_CAM_HTAP_ASCENDING
    cam[PHX_CAM_VTAP_NUM]       = 1
    cam[PHX_CAM_VTAP_DIR]       = PHX_CAM_VTAP_TOP
    cam[PHX_CAM_VTAP_TYPE]      = PHX_CAM_VTAP_LINEAR
    cam[PHX_CAM_VTAP_ORDER]     = PHX_CAM_VTAP_ASCENDING
    cam[PHX_COMMS_DATA]         = PHX_COMMS_DATA_8
    cam[PHX_COMMS_STOP]         = PHX_COMMS_STOP_1
    cam[PHX_COMMS_PARITY]       = PHX_COMMS_PARITY_NONE
    cam[PHX_COMMS_SPEED]        = 9600
    cam[PHX_COMMS_FLOW]         = PHX_COMMS_FLOW_NONE

    # Set the format of the image sent by the camera.
    srcformat, srcdepth, dstformat = equivalentformat(cam)
    cam[PHX_CAM_SRC_COL]   = srcformat
    cam[PHX_CAM_SRC_DEPTH] = srcdepth
    cam[PHX_DST_FORMAT]    = dstformat
    setactiveregion!(cam, width, height)

    # Acquisition settings.
    cam[PHX_ACQ_BLOCKING]          = PHX_ENABLE
    cam[PHX_ACQ_CONTINUOUS]        = PHX_ENABLE
    cam[PHX_ACQ_XSUB]              = PHX_ACQ_X1
    cam[PHX_ACQ_YSUB]              = PHX_ACQ_X1
    cam[PHX_ACQ_NUM_BUFFERS]       = 1
    cam[PHX_ACQ_IMAGES_PER_BUFFER] = 1
    cam[PHX_ACQ_BUFFER_START]      = 1
    cam[PHX_DATASTREAM_VALID]      = PHX_DATASTREAM_ALWAYS
    cam[PHX_TIMEOUT_DMA]           = 1_000 # milliseconds

    # Set source ROI to match the size of the image sent by the camera.
    setsourceregion!(cam, 0, 0, width, height)

    # Setup destination buffer parameters.  The value of `PHX_BUF_DST_XLENGTH`
    # is the number of bytes per line of the destination buffer (it must be
    # larger of equal the width of the ROI times the number of bits per pixel
    # rounded up to a number of bytes), the value of `PHX_BUF_DST_YLENGTH` is
    # the number of lines in the destination buffer (it must be larger or equal
    # `PHX_ROI_DST_YOFFSET` plus `PHX_ROI_YLENGTH`.
    bits = capture_format_bits(dstformat)
    cam[PHX_ROI_DST_XOFFSET] = 0
    cam[PHX_ROI_DST_YOFFSET] = 0
    cam[PHX_BUF_DST_XLENGTH] = div(width*bits + 7, 8)
    cam[PHX_BUF_DST_YLENGTH] = height
    cam[PHX_BIT_SHIFT]       = 0 # FIXME: PHX_BIT_SHIFT_ALIGN_LSB not defined

    # Use native byte order for the destination buffer.
    if ENDIAN_BOM == 0x04030201
        # Little-endian byte order.
        cam[PHX_DST_ENDIAN] = PHX_DST_LITTLE_ENDIAN
    elseif ENDIAN_BOM == 0x01020304
        # Big-endian byte order.
        cam[PHX_DST_ENDIAN] = PHX_DST_BIG_ENDIAN
    end

    return nothing
end

"""
    equivalentformat(pixfmt) -> (srcfmt, srcdepth, dstfmt)

yields values of parameters `PHX_CAM_SRC_COL`, `PHX_CAM_SRC_DEPTH`
and `PHX_DST_FORMAT` corresponding to the camera pixel format `pixfmt`
which is one of `PIXEL_FORMAT_MONO8`, `PIXEL_FORMAT_MONO10`,
`PIXEL_FORMAT_BAYERGR8` or `PIXEL_FORMAT_BAYERGR10`.

"""
function equivalentformat(pixfmt::Integer)
    local srcfmt::ParamValue, srcdepth::ParamValue
    local dstfmt::ParamValue
    if pixfmt == PIXEL_FORMAT_MONO8
        srcfmt   = PHX_CAM_SRC_MONO
        srcdepth = 8
        dstfmt   = PHX_DST_FORMAT_Y8
    elseif pixfmt == PIXEL_FORMAT_MONO10
        srcfmt   = PHX_CAM_SRC_MONO
        srcdepth = 10
        dstfmt   = PHX_DST_FORMAT_Y16
    elseif pixfmt == PIXEL_FORMAT_BAYERGR8
        srcfmt   = PHX_CAM_SRC_BAY_RGGB
        srcdepth = 8
        dstfmt   = PHX_DST_FORMAT_BAY8
    elseif pixfmt == PIXEL_FORMAT_BAYERGR10
        srcfmt   = PHX_CAM_SRC_BAY_RGGB
        srcdepth = 10
        dstfmt   = PHX_DST_FORMAT_BAY16
    else
        error("unknown pixel format 0x", hex(pixfmt))
    end
    return (srcfmt, srcdepth, dstfmt)
end

equivalentformat(cam::Camera{MikrotronMC408xModel}) =
    equivalentformat(cam[PIXEL_FORMAT])

"""
    setactiveregion!(cam, width, height)

set the dimensions of the active region for camera `cam`.  This is a low-level
method which does not check its arguments.  It is equivalent to:

    cam[PHX_CAM_ACTIVE_XOFFSET] = 0
    cam[PHX_CAM_ACTIVE_YOFFSET] = 0
    cam[PHX_CAM_ACTIVE_XLENGTH] = width
    cam[PHX_CAM_ACTIVE_YLENGTH] = height
    cam[PHX_CAM_XBINNING]       = 1
    cam[PHX_CAM_YBINNING]       = 1

See also: [`setsourceregion!`](@ref).
"""
function setactiveregion!(cam::Camera{MikrotronMC408xModel},
                          width::Integer, height::Integer)
    cam[PHX_CAM_ACTIVE_XOFFSET] = 0
    cam[PHX_CAM_ACTIVE_YOFFSET] = 0
    cam[PHX_CAM_ACTIVE_XLENGTH] = width
    cam[PHX_CAM_ACTIVE_YLENGTH] = height
    cam[PHX_CAM_XBINNING]       = 1
    cam[PHX_CAM_YBINNING]       = 1
    nothing
end

"""
    setsourceregion!(cam, xoff, yoff, width, height)

set the offsets and dimensions of the *source* region for camera `cam`.  This
is a low-level method which does not check its arguments.  It is equivalent to:

    cam[PHX_ROI_SRC_XOFFSET] = xoff
    cam[PHX_ROI_SRC_YOFFSET] = yoff
    cam[PHX_ROI_XLENGTH]     = width
    cam[PHX_ROI_YLENGTH]     = height

The *source* region is the *capture* region, a.k.a. *ROI*, relative to the
*active* region.

See also: [`setcaptureregion!`](@ref), [`setroi!`](@ref).
"""
function setsourceregion!(cam::Camera{MikrotronMC408xModel},
                          xoff::Integer, yoff::Integer,
                          width::Integer, height::Integer)
    cam[PHX_ROI_SRC_XOFFSET] = xoff
    cam[PHX_ROI_SRC_YOFFSET] = yoff
    cam[PHX_ROI_XLENGTH]     = width
    cam[PHX_ROI_YLENGTH]     = height
    nothing
end

starthook(cam::Camera{MikrotronMC408xModel}) =
    send(cam, ACQUISITION_START)

stophook(cam::Camera{MikrotronMC408xModel}) =
    send(cam, ACQUISITION_STOP)


# Extend method.
getfullwidth(cam::Camera{MikrotronMC408xModel}) =
    Int(cam[SENSOR_WIDTH])

# Extend method.
getfullheight(cam::Camera{MikrotronMC408xModel}) =
    Int(cam[SENSOR_HEIGHT])

# Extend method.
function getroi(cam::Camera{MikrotronMC408xModel};
                quiet::Bool = false)

    @assert cam.state > 0

    # The frame grabber receives an image of `camwidth` by `camheight`
    # macro-pixels and all ROI settings on the frame grabber are with
    # macro-pixels.  On the camera, only the width and height of the ROI are
    # expressed in macro-pixels, the offsets and decimation factors are in
    # pixels.

    # Retrieve current settings for the camera active region in macro-pixels.
    xsub      = Int(cam[DECIMATION_HORIZONTAL]) # in pixels
    ysub      = Int(cam[DECIMATION_VERTICAL])   # in pixels
    camxoff   = Int(cam[OFFSET_X])              # in pixels
    camyoff   = Int(cam[OFFSET_Y])              # in pixels
    camwidth  = Int(cam[WIDTH])                 # in macro-pixels
    camheight = Int(cam[HEIGHT])                # in macro-pixels

    # Retrieve current settings for the frame grabber source region.
    srcxoff   = Int(cam[PHX_ROI_SRC_XOFFSET])   # in macro-pixels
    srcyoff   = Int(cam[PHX_ROI_SRC_YOFFSET])   # in macro-pixels
    srcwidth  = Int(cam[PHX_ROI_XLENGTH])       # in macro-pixels
    srcheight = Int(cam[PHX_ROI_YLENGTH])       # in macro-pixels

    # Check settings of the source region and fix them.
    clip = false
    reset = false
    if (srcxoff ≥ camwidth  || srcxoff + srcwidth  < 1 ||
        srcyoff ≥ camheight || srcyoff + srcheight < 1)
        reset = true
        srcxoff   = 0
        srcyoff   = 0
        srcwidth  = camwidth
        srcheight = camheight
    else
        if srcxoff < 0
            clip = true
            srcwidth += srcxoff
            srcxoff = 0
        end
        if srcxoff + srcwidth > camwidth
            clip = true
            srcwidth = camwidth - srcxoff
        end
        if srcyoff < 0
            clip = true
            srcheight += srcyoff
            srcyoff = 0
        end
        if srcyoff + srcheight > camheight
            clip = true
            srcheight = camheight - srcyoff
        end
    end
    if reset || clip
        if ! quiet && reset
            warn("non-overlapping source region has been reset to active region")
        end
        if ! quiet && clip
            warn("source region has been clipped within active region")
        end
        setsourceregion!(cam, srcxoff, srcyoff, srcwidth, srcheight)
    end

    # Make sure the active region is correct.
    setactiveregion!(cam, camwidth, camheight)

    # Compute actual ROI and return it.
    xoff = camxoff + srcxoff*xsub
    yoff = camyoff + srcyoff*ysub
    return ROI(xsub, ysub, xoff, yoff, srcwidth, srcheight)
end

# Extend method.
function setroi!(cam::Camera{MikrotronMC408xModel}, roi::ROI;
                 quiet::Bool = false)
    # Check arguments and retrieve current camera settings.
    @assert cam.state == 1
    fullwidth  = getfullwidth(cam)
    fullheight = getfullheight(cam)
    checkroi(roi, fullwidth, fullheight)

    # Compute new settings for the camera (to use the smallest active region
    # within constraints) and the source region.
    camxoff, camwidth,  srcxoff = fitroi(roi.xsub, roi.xoff, roi.width,
                                         HORIZONTAL_INCREMENT, "horizontal")
    camyoff, camheight, srcyoff = fitroi(roi.ysub, roi.yoff, roi.height,
                                         VERTICAL_INCREMENT, "vertical")

    # Fix settings in a specific order such that the actual camera settings are
    # always valid.
    fixcamroi!(cam, DECIMATION_HORIZONTAL, OFFSET_X, WIDTH,
               roi.xsub, camxoff, camwidth)
    fixcamroi!(cam, DECIMATION_VERTICAL,   OFFSET_Y, HEIGHT,
               roi.ysub, camyoff, camheight)

    # Set frame grabber parameters.
    setactiveregion!(cam, camwidth, camheight)
    setsourceregion!(cam, srcxoff, srcyoff, roi.width, roi.height)
    return nothing
end

"""
    rounddown(a, b)

yields largest multiple of `b` which is smaller or equal `a`.  Arguments and
result are integers, `a` must be nonnegative, `b` must be striclty positive and
result is nonnegative.

See also: [`roundup`](@ref)

"""
rounddown(a::Integer, b::Integer) = div(a, b)*b

"""
    roundup(a, b)

yields smallest multiple of `b` which is larger or equal `a`.  Arguments and
result are integers, `a` must be nonnegative, `b` must be striclty positive and
result is nonnegative.

See also: [`rounddown`](@ref)

"""
roundup(a::Integer, b::Integer) = div((b - 1) + a, b)*b

"""
    fitroi(sub, off, len, inc, dir) -> devoff, devlen, srcoff

yields the offset (in pixels) and the length (in macro-pixels) of the ROI for
the camera and the offset (in macro-pixels) of the ROI for frame grabber to fit
a 1D ROI where `sub` is the subsampling factor, `off` is the offset of the ROI
relative to the sensor, `len` is the length of the ROI (in macro-pixels) and
`inc` is the sensor increment (in pixels).  Last argument is "horizontal" or
"vertical" and is used for error messages.

"""
function fitroi(sub::Int, off::Int, len::Int, inc::Int, dir::String)
    # Start with the largest device offset and reduce it by given increments
    # until a perfect fit is found.
    devoff = rounddown(off, inc)
    while true
        srcoff, remoff = divrem(off - devoff, sub)
        if remoff == 0
            # A perfect offset has been found.
            devlen, remlen = divrem(roundup((len + srcoff)*sub, inc), sub)
            if remlen == 0
                # A perfect fit has been found.
                return (devoff, devlen, srcoff)
            end
        end
        devoff -= inc
        if devoff < 0
            error("cannot adjust $dir offsets to fit ROI")
        end
    end
end

"""
    fixcamroi!(cam, subkey, offkey, lenkey, sub, off, len)

applies 1D ROI settings to the camera `cam` in a specific order so that the
configuration is valid at any moment.  Arguments `subkey`, `offkey` and
`lenkey` are the CoaXPress registers corresponding to `sub` the subsampling
factor (in pixels), `off` the offset of the ROI relative to the sensor (in
pixels) and `len` the length of the ROI (in macro-pixels).

"""
function fixcamroi!(cam::Camera{MikrotronMC408xModel},
                    subkey::Register, offkey::Register, lenkey::Register,
                    sub::Int, off::Int, len::Int)
    oldsub = Int(cam[subkey])
    oldoff = Int(cam[offkey])
    oldlen = Int(cam[lenkey])
    if oldsub > sub
        cam[subkey] = sub
    end
    if oldoff > off
        cam[offkey] = off
    end
    if oldlen != len
        cam[lenkey] = len
    end
    if oldsub < sub
        cam[subkey] = sub
    end
    if oldoff < off
        cam[offkey] = off
    end
    return nothing
end

# Extend method.
function supportedpixelformats(cam::Camera{MikrotronMC408xModel}, buf::Bool)
    if buf
        return CAPTURE_FORMATS
    else
        format = cam[PIXEL_FORMAT]
        if (format == PIXEL_FORMAT_MONO8 ||
            format == PIXEL_FORMAT_MONO10)
            return Union{Monochrome{8},Monochrome{10}}
        elseif (format == PIXEL_FORMAT_BAYERGR8 ||
                format == PIXEL_FORMAT_BAYERGR10)
            return Union{BayerGRBG{8},BayerGRBG{10}}
        else
            error("unexpected pixel format!")
        end
    end
end

# Extend method.
function getpixelformat(cam::Camera{MikrotronMC408xModel})
    fmt = cam[PIXEL_FORMAT]
    return ((fmt == PIXEL_FORMAT_MONO8     ? Monochrome{8}  :
             fmt == PIXEL_FORMAT_MONO10    ? Monochrome{10} :
             fmt == PIXEL_FORMAT_BAYERGR8  ? BayerGRBG{8}   :
             fmt == PIXEL_FORMAT_BAYERGR10 ? BayerGRBG{10}  :
             error("unexpected pixel format!")),
            capture_format(cam[PHX_DST_FORMAT]))
end

# Extend method.
function setpixelformat!(cam::Camera{MikrotronMC408xModel},
                         ::Type{C}, ::Type{B}) where {C <: PixelFormat,
                                                      B <: PixelFormat}
    # Set the camera pixel format and the corresponding pixel format for
    # captured image buffers.
    setpixelformat!(cam, C)

    # Check pixel format of captured images.
    dstfmt = capture_format(B)
    if dstfmt == zero(dstfmt)
        throw(ArgumentError("unsupported pixel format of captured images"))
    end
    if cam[PHX_DST_FORMAT] != dstfmt
        throw(ArgumentError("pixel format of captured images incompatible with camera pixel format"))
    end
    return nothing
end

# Extend method.
function setpixelformat!(cam::Camera{MikrotronMC408xModel},
                         ::Type{T}) where {T <: PixelFormat}
    # Check state.
    if cam.state != 1
        if cam.state == 0
            error("camera not yet open")
        elseif cam.state == 2
            error("acquisition is running")
        else
            error("camera instance corrupted")
        end
    end

    # Determine best matching formats.
    oldfmt = cam[PIXEL_FORMAT]
    newfmt = guesscamerapixelformat(oldfmt, T)
    srccol, srcdepth, dstfmt = equivalentformat(newfmt)

    # Apply the settings.
    if newfmt != oldfmt
        cam[PIXEL_FORMAT] = newfmt
    end
    cam[PHX_CAM_SRC_COL]   = srccol
    cam[PHX_CAM_SRC_DEPTH] = srcdepth
    cam[PHX_DST_FORMAT]    = dstfmt
    return nothing
end

# Determine camera pixel format.
function guesscamerapixelformat(oldfmt::Integer, C::PixelFormat)
    if C <: Monochrome
        if oldfmt != PIXEL_FORMAT_MONO8 && oldfmt != PIXEL_FORMAT_MONO10
            throw(ArgumentError("not a monochrome camera"))
        end
        if C == Monochrome{8}
            return PIXEL_FORMAT_MONO8
        elseif C == Monochrome{10}
            return PIXEL_FORMAT_MONO10
        elseif C != Monochrome
            throw(ArgumentError("unsupported number of bits per pixel"))
        end
    elseif C <: ColorFormat
        if oldfmt != PIXEL_FORMAT_BAYERGR8 && oldfmt != PIXEL_FORMAT_BAYERGR10
            throw(ArgumentError("not a color Bayer camera"))
        end
        if (C == ColorFormat{8} ||
            C == BayerFormat{8} ||
            C == BayerGRBG{8})
            return PIXEL_FORMAT_BAYERGR8
        elseif (C == ColorFormat{10} ||
                C == BayerFormat{10} ||
                C == BayerGRBG{10})
            return PIXEL_FORMAT_BAYERGR10
        elseif (C != ColorFormat &&
                C != BayerFormat &&
                C != BayerGRBG)
            throw(ArgumentError("unsupported number of bits per pixel or color format"))
        end
    end
end

# Extend method.
getspeed(cam::Camera{MikrotronMC408xModel}) =
    (convert(Float64, cam[ACQUISITION_FRAME_RATE]),
     convert(Float64, cam[EXPOSURE_TIME]/1_000_000))

# Extend method.
function setspeed!(cam::Camera{MikrotronMC408xModel},
                   fps::Float64, exp::Float64)
    checkspeed(cam, fps, exp)
    newfps = round(UInt32, fps)
    newexp = round(UInt32, exp*1_000_000)
    oldfps = cam[ACQUISITION_FRAME_RATE]
    oldexp = cam[EXPOSURE_TIME]
    if newfps < oldfps
        cam[ACQUISITION_FRAME_RATE] = newfps
    end
    if newexp != oldexp
        cam[EXPOSURE_TIME] = newexp
    end
    if newfps > oldfps
        cam[ACQUISITION_FRAME_RATE] = newfps
    end
    nothing
end

# Extend method.
getgain(cam::Camera{MikrotronMC408xModel}) =
    convert(Float64, cam[GAIN]/100)

# Extend method.
setgain!(cam::Camera{MikrotronMC408xModel}, gain::Float64) =
    setifneeded!(cam, GAIN, gain*100)

# Extend method.
getbias(cam::Camera{MikrotronMC408xModel}) =
    convert(Float64, cam[BLACK_LEVEL]/100)

# Extend method.
setbias!(cam::Camera{MikrotronMC408xModel}, bias::Float64) =
    setifneeded!(cam, BLACK_LEVEL, bias*100)

# Extend method.
getgamma(cam::Camera{MikrotronMC408xModel}) =
    convert(Float64, cam[GAMMA])

# Extend method.
setgamma!(cam::Camera{MikrotronMC408xModel}, gamma::Float64) =
    setifneeded!(cam, GAMMA, gamma)

function setifneeded!(cam::Camera{MikrotronMC408xModel},
                      reg::RegisterValue{T,ReadWrite},
                      val) where {T<:Integer}
    newval = round(T, val)
    if cam[reg] != newval
        cam[reg] = newval
    end
    nothing
end

function setifneeded!(cam::Camera{MikrotronMC408xModel},
                      reg::RegisterValue{T,ReadWrite},
                      val) where {T<:AbstractFloat}
    newval = convert(T, val)
    if cam[reg] != newval
        cam[reg] = newval
    end
    nothing
end

# This overloading of the method is to treat specifically certain problematic
# parameters such as the pixel format.
function setparam!(cam::Camera{MikrotronMC408xModel},
                   key::RegisterValue{T,A}, val::T) where {T<:Real,A<:Writable}
    # Unfortunately, setting some parameters (as the pixel format or the gamma
    # correction) returns an error with an absurd code
    # (`PHX_ERROR_MALLOC_FAILED`) which, in practice can be ignored as, after a
    # while, getting the actual setting yields the correct value.  A number of
    # queries of the value are necessary (usually 2 are sufficient) before
    # getting a confirmation of the setting.
    #
    # To cope with this issue, we set such parameters ignoring errors and
    # repeatedly query the parameter until it succeeds or a maximum number of
    # tries is exceeded.  To avoid alarming the user, printing of error
    # messages is disabled during this process.
    errmode = printerror(false) # temporarily switch reporting of errors
    buf = Ref{T}(val)
    status = _setparam!(cam, key, buf)
    if status != PHX_OK
        retry = false
        if key.addr == PIXEL_FORMAT.addr && (val == PIXEL_FORMAT_MONO8     ||
                                             val == PIXEL_FORMAT_MONO10    ||
                                             val == PIXEL_FORMAT_BAYERGR8  ||
                                             val == PIXEL_FORMAT_BAYERGR10 )
            for i in 1:3
                if _getparam(cam, key, buf) == PHX_OK && buf[] == val
                    return nothing
                end
            end
            printerror(errmode) # restore previous mode
            error("failed to change pixel format to 0x", hex(val))
        elseif key.addr == GAMMA && (GAMMA_MIN ≤ gamma ≤ GAMMA_MAX)
            for i in 1:3
                if (_getparam(cam, key, buf) == PHX_OK &&
                    abs(buf[] - val) ≤ GAMMA_INCREMENT)
                    return nothing
                end
            end
            printerror(errmode) # restore previous mode
            error(@sprintf("failed to change gamma correction to %0.1f", val))
        end
    end
    printerror(errmode) # restore previous mode
    checkstatus(status)
end

end # module
