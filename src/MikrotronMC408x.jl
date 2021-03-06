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
# Copyright (C) 2017-2019, Éric Thiébaut (https://github.com/emmt/Phoenix.jl).
# Copyright (C) 2016, Éric Thiébaut & Jonathan Léger.
#

module MikrotronMC408x

using ScientificCameras, ScientificCameras.PixelFormats
for sym in names(ScientificCameras)
    if sym != :ScientificCameras
        @eval begin
            import ScientificCameras: $sym
        end
    end
end
import ScientificCameras: ScientificCamera, ROI, setspeed!

using Phoenix
for sym in Phoenix._DEVEL_SYMBOLS
    @eval begin
        import Phoenix: $sym
    end
end

macro exportmethods()
    :(export
      setfixedpatternnoisereduction!,
      getfixedpatternnoisereduction,
      setinfofieldframecounter!,
      getinfofieldframecounter,
      setinfofieldtimestamp!,
      getinfofieldtimestamp,
      setinfofieldroi!,
      getinfofieldroi,
      setfiltermode!,
      getfiltermode)
end
@exportmethods

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
const TRIGGER_COUNT                 = RegisterValue{Nothing,Unreachable}(0x891C)
const TRIGGER_DEBOUNCER             = RegisterValue{Nothing,Unreachable}(0x8918)
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
const SEQUENCER_SET_SELECTOR        = RegisterValue{Nothing,Unreachable}(0x8878)
const SEQUENCER_SET_SAVE            = RegisterValue{Nothing,Unreachable}(0x887C)
const SEQUENCER_SET_NEXT            = RegisterValue{Nothing,Unreachable}(0x8888)
const USER_SET_SELECTOR             = RegisterEnum{ReadWrite}(0x8820)
const USER_SET_LOAD                 = RegisterCommand{UInt32}(0x8824, 1)
const USER_SET_SAVE                 = RegisterCommand{UInt32}(0x8828, 1)
const USER_SET_DEFAULT_SELECTOR     = RegisterEnum{ReadWrite}(0x882C)
const DEVICE_RESET                  = RegisterCommand{UInt32}(0x8300, 1)
const CONNECTION_RESET              = RegisterCommand{UInt32}(0x4000, 1)
const CONNECTION_CONFIG             = RegisterValue{UInt32,ReadWrite}(0x4014)
const CONNECTION_DEFAULT            = RegisterValue{UInt32,ReadOnly}(0x4018)

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

# Possible values for CXP_DEVICE_INFORMATION_SELECTOR.
const DEVICE_INFORMATION_SELECTOR_SERIAL_NUMBER     =  0
const DEVICE_INFORMATION_SELECTOR_DEVICE_TYPE       =  1
const DEVICE_INFORMATION_SELECTOR_DEVICE_SUBTYPE    =  2
const DEVICE_INFORMATION_SELECTOR_HARDWARE_REVISION =  3
const DEVICE_INFORMATION_SELECTOR_FPGA_VERSION      =  4
const DEVICE_INFORMATION_SELECTOR_SOFTWARE_VERSION  =  5
const DEVICE_INFORMATION_SELECTOR_POWER_SOURCE      = 20
const DEVICE_INFORMATION_SELECTOR_POWER_CONSUMPTION = 21
const DEVICE_INFORMATION_SELECTOR_POWER_VOLTAGE     = 22
const DEVICE_INFORMATION_SELECTOR_TEMPERATURE       = 23

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
const TX_LOGICAL_CONNECTION_RESET     = RegisterValue{Nothing,Unreachable}(0x9010)
const PRST_ENABLE                     = RegisterValue{UInt32,ReadWrite}(0x9200)
const PULSE_DRAIN_ENABLE              = RegisterValue{UInt32,ReadWrite}(0x9204)
const CUSTOM_SENSOR_CLK_ENABLE        = RegisterValue{Nothing,Unreachable}(0x9300)
const CUSTOM_SENSOR_CLK               = RegisterValue{Nothing,Unreachable}(0x9304)
const DEVICE_INFORMATION              = RegisterValue{UInt32,ReadOnly}(0x8A04)
const DEVICE_INFORMATION_SELECTOR     = RegisterValue{UInt32,ReadWrite}(0x8A00)
const ANALOG_REGISTER_SET_SELECTOR    = RegisterValue{Nothing,Unreachable}(0x20000)
const ANALOG_REGISTER_SELECTOR        = RegisterValue{Nothing,Unreachable}(0x20004)
const ANALOG_VALUE                    = RegisterValue{Nothing,Unreachable}(0x20008)
const INFO_FIELD_FRAME_COUNTER_ENABLE = RegisterValue{UInt32,ReadWrite}(0x9310)
const INFO_FIELD_TIME_STAMP_ENABLE    = RegisterValue{UInt32,ReadWrite}(0x9314)
const INFO_FIELD_ROI_ENABLE           = RegisterValue{UInt32,ReadWrite}(0x9318)
const FIXED_PATTERN_NOISE_REDUCTION   = RegisterValue{UInt32,ReadWrite}(0x8A10)
const FILTER_MODE                     = RegisterEnum{ReadWrite}(0x10014)
const PIXEL_TYPE_F                    = RegisterValue{Nothing,Unreachable}(0x51004)
const DIN1_CONNECTOR_TYPE             = RegisterValue{Nothing,Unreachable}(0x8A30)
const IS_IMPLEMENTED_MULTI_ROI        = RegisterValue{Nothing,Unreachable}(0x50004)
const IS_IMPLEMENTED_SEQUENCER        = RegisterValue{Nothing,Unreachable}(0x50008)
const CAMERA_TYPE_HEX                 = RegisterValue{Nothing,Unreachable}(0x51000)
const CAMERA_STATUS                   = RegisterValue{Nothing,Unreachable}(0x10002200)
const IS_STOPPED                      = RegisterValue{Nothing,Unreachable}(0x10002204)

const FILTER_MODE_RAW                 = UInt32(0)
const FILTER_MODE_MONO                = UInt32(1)
const FILTER_MODE_COLOR               = UInt32(2)


# Singleton to uniquely identify this camera model.
struct MikrotronMC408xModel <: CameraModel; end

# Initialize the camera after board is open.
function _openhook(cam::Camera{MikrotronMC408xModel})

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

    # Get current hardware settings.
    xsub   = Int(cam[DECIMATION_HORIZONTAL]) # in pixels
    ysub   = Int(cam[DECIMATION_VERTICAL])   # in pixels
    width  = Int(cam[WIDTH])                 # in macro-pixels
    height = Int(cam[HEIGHT])                # in macro-pixels

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

    return nothing # FIXME: return PXH_OK?
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
        error("unknown pixel format 0x", string(pixfmt, base=16))
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

_starthook(cam::Camera{MikrotronMC408xModel}) =
    exec(cam, ACQUISITION_START)

_stophook(cam::Camera{MikrotronMC408xModel}) =
    exec(cam, ACQUISITION_STOP)


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

    # Make sure the active region is correct.
    setactiveregion!(cam, camwidth, camheight)

    # Retrieve current settings for the frame grabber ROI.
    srcxoff   = Int(cam[PHX_ROI_SRC_XOFFSET])   # in macro-pixels
    srcyoff   = Int(cam[PHX_ROI_SRC_YOFFSET])   # in macro-pixels
    width  = Int(cam[PHX_ROI_XLENGTH])       # in macro-pixels
    height = Int(cam[PHX_ROI_YLENGTH])       # in macro-pixels

    # Check settings of the source region and fix them (try to clip first and
    # reset in last resort).
    clip = false
    reset = false
    if srcxoff < 0
        clip = true
        width += srcxoff
        srcxoff = 0
    end
    if srcxoff + width > camwidth
        clip = true
        width = camwidth - srcxoff
    end
    if srcyoff < 0
        clip = true
        height += srcyoff
        srcyoff = 0
    end
    if srcyoff + height > camheight
        clip = true
        height = camheight - srcyoff
    end
    if width < 1 || height < 1
        reset = true
        srcxoff   = 0
        srcyoff   = 0
        width  = camwidth
        height = camheight
    end
    if reset || clip
        quiet || @warn (reset ?
                        "non-overlapping ROI has been reset to active region" :
                        "ROI has been clipped within active region")
        setsourceregion!(cam, srcxoff, srcyoff, width, height)
    end

    # Compute actual ROI and return it.
    xoff = camxoff + srcxoff*xsub
    yoff = camyoff + srcyoff*ysub
    return ROI(xsub, ysub, xoff, yoff, width, height)
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
                                         HORIZONTAL_INCREMENT, fullwidth,
                                         "horizontal")
    camyoff, camheight, srcyoff = fitroi(roi.ysub, roi.yoff, roi.height,
                                         VERTICAL_INCREMENT, fullheight,
                                         "vertical")

    # Compute actual size of ROI.
    width  = min(roi.width,  camwidth  - srcxoff)
    height = min(roi.height, camheight - srcyoff)

    if true
        # FIXME: There is a bug in the frame grabber which yields corrupted
        # images when the size of the ROI does not match what is sent by the
        # camera.
        srcxoff = 0
        srcyoff = 0
        width = camwidth
        height = camheight
    end

    # Fix settings in a specific order such that the actual camera settings are
    # always valid.
    fixcamroi!(cam,
               DECIMATION_HORIZONTAL, roi.xsub,
               OFFSET_X,              camxoff,
               WIDTH,                 camwidth)
    fixcamroi!(cam,
               DECIMATION_VERTICAL,   roi.ysub,
               OFFSET_Y,              camyoff,
               HEIGHT,                camheight)

    # Set frame grabber parameters.
    setactiveregion!(cam, camwidth, camheight)
    setsourceregion!(cam, srcxoff, srcyoff, width, height)
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
roundup(a::Integer, b::Integer) = rounddown((b - one(b)) + a, b)

"""
     divrnd(a, b) -> q

yields `a/b` rounded to the nearest integer.  Arguments are assumed to be
positive integers.  The result is the same as `round(Int, a/b)` but (slightly)
faster.

"""
divrnd(a::Integer, b::Integer) = div(2a + b, 2b)

"""
    fitroi(sub, off, len, inc, lim, dir) -> devoff, devlen, srcoff

yields the offset (in pixels) and the length (in macro-pixels) of the ROI for
the camera and the offset (in macro-pixels) of the ROI for the frame grabber to
fit a 1D ROI where `sub` is the subsampling factor, `off` is the offset of the
ROI relative to the sensor, `len` is the length of the ROI (in macro-pixels),
`inc` is the sensor increment (in pixels) and `lim` is the maximum length (in
pixels) of the device.  Last argument is `"horizontal"` or `"vertical"` and is
used for error messages.

"""
function fitroi(sub::Int, off::Int, len::Int, inc::Int, lim::Int, dir::String)
    # Check consistency of arguments.
    @assert inc ≥ 1
    @assert lim ≥ 1 && rem(lim, inc) == 0
    @assert sub ≥ 1
    @assert len ≥ 1
    @assert off ≥ 0
    @assert off + len*sub ≤ lim

    # We have to make a compromise between exactness of the ROI (which is not
    # always possible if `sub > 1`) and smallness of the size of the region
    # sent by the camera.  If the region sent by the camera is large enough to
    # encompass the requested ROI, then the maximal error on each side of the
    # ROI is striclty less than a macro-pixel because it is always possible to
    # reduce the final image by macro-pixel adjustments.  The strategy is then
    # to choose the smallest possible region on the camera which encompasses
    # the requested ROI and, then, to compute macro-pixel adjustments to
    # approximate the requested ROI.

    # Offset in multiple of `inc` pixels which best fits by below the requested
    # offset.
    devoff = rounddown(off, inc)

    # Length of the region sent by the camera contrained to be a multiple of
    # `inc` and `sub` (hence a multiple of their Least Common Multiple), at or
    # after end of ROI (if possible) and whithin camera limits.
    mul = lcm(inc, sub)
    pixlen = min(roundup(off + len*sub - devoff, mul),
                 rounddown(lim - devoff, mul))

    # Size of region sent by the camera in macro-pixels.
    devlen = div(pixlen, sub)

    # Source offset in macro-pixels to best fits by below the requested ROI.
    srcoff = div(off - devoff, sub)

    return (devoff, devlen, srcoff)
end

# Other possible strategy
# =======================
#
# The region of interest is `roi = (a,b]` in pixels with
#
#     a = off
#     b = off + len⋅sub
#
# which is approximated by:
#
#     ap = k⋅inc + l⋅sub
#     bp = k⋅inc + m⋅lcm(inc,sub) - n⋅sub
#
# where: `k ≥ 0`, `l ≥ 0`, `m > 0` and `n ≥ 0` are all nonnegative integers
# and:
#
#     devoff = k⋅inc
#     devlen = m⋅lcm(inc,sub)/sub
#     srcoff = l
#
# so as to minimize the misfit:
#
#     err = abs(ap - a) + abs(bp - b)
#
# and for the same misfit, the objective is to minimize the number of
# transmitted macro-pixels hence `devlen` (or equivalently `m`).
#
# If `k` and `m` are given, the best `l` and `n` are:
#
#     l = argmin_{l ≥ 0} abs(k⋅inc + l⋅sub - a)
#       = max(0, round(Int, (a - k⋅inc)/sub))
#
#     n = argmin_{n ≥ 0} abs(k⋅inc + m⋅lcm(inc,sub) - n⋅sub - b)
#       = max(0, round(Int, (k⋅inc + m⋅lcm(inc,sub) - b)/sub))
#

"""
    fixcamroi!(cam, subkey, offkey, lenkey, sub, off, len)

applies 1D ROI settings to the camera `cam` in a specific order so that the
configuration is valid at any moment.  Arguments `subkey`, `offkey` and
`lenkey` are the CoaXPress registers corresponding to `sub` the subsampling
factor (in pixels), `off` the offset of the ROI relative to the sensor (in
pixels) and `len` the length of the ROI (in macro-pixels).

"""
function fixcamroi!(cam::Camera{MikrotronMC408xModel},
                    subkey::Register, sub::Int,
                    offkey::Register, off::Int,
                    lenkey::Register, len::Int)
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
    return (fmt == PIXEL_FORMAT_MONO8     ? Monochrome{8}  :
            fmt == PIXEL_FORMAT_MONO10    ? Monochrome{10} :
            fmt == PIXEL_FORMAT_BAYERGR8  ? BayerGRBG{8}   :
            fmt == PIXEL_FORMAT_BAYERGR10 ? BayerGRBG{10}  :
            error("unexpected pixel format!"))
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
    newfmt = guesspixelformat(oldfmt, T)
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
function guesspixelformat(oldfmt::Integer,
                          ::Type{C}) where {C <:PixelFormat}
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

getframespersecond(cam::Camera{MikrotronMC408xModel}) =
    convert(Float64, cam[ACQUISITION_FRAME_RATE])

getexposuretime(cam::Camera{MikrotronMC408xModel}) =
    convert(Float64, cam[EXPOSURE_TIME]/1_000_000)

# Extend method.
getspeed(cam::Camera{MikrotronMC408xModel}) =
    (getframespersecond(cam), getexposuretime(cam))

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

function setspeed!(cam::Camera{MikrotronMC408xModel},
                   fps::Real, exp::AbstractString)
    setspeed!(cam, fps, Symbol(exp))
end

function setspeed!(cam::Camera{MikrotronMC408xModel},
                   fps::Real, exp::Symbol)
    if exp == :max
        setspeed!(cam, fps, 1e-6)
        setspeed!(cam, fps, 1e-6*cam[EXPOSURE_TIME_MAX])
    else
        error("exposure can be a value of `:max`")
    end
    nothing
end

# Extend method.
getgain(cam::Camera{MikrotronMC408xModel}) =
    convert(Float64, cam[GAIN])

# Extend method.
setgain!(cam::Camera{MikrotronMC408xModel}, gain::Float64) =
    setifneeded!(cam, GAIN, round(UInt32, gain))

# Extend method.
getbias(cam::Camera{MikrotronMC408xModel}) =
    convert(Float64, cam[BLACK_LEVEL])

# Extend method.
setbias!(cam::Camera{MikrotronMC408xModel}, bias::Float64) =
    setifneeded!(cam, BLACK_LEVEL, round(UInt32, bias))

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
                   key::RegisterValue{T,A},
                   val::T) :: T where {T<:Real,A<:Writable}
    #
    # Unfortunately, setting some parameters (as the pixel format or the gamma
    # correction) returns an error with an absurd code
    # (`PHX_ERROR_MALLOC_FAILED`) even if the value has been correctly set.
    # The error cannot be just ignored as further reads of registers yield
    # wrong values.  The strategy is to close and re-open the camera when such
    # an error occurs which solves the problem in practice to the cost of the
    # time spent to close and re-open (0.4 sec.).  To avoid alarming the user,
    # printing of error messages is disabled during this process.
    #
    # Other (unsuccessful) strategies have been tried:
    # - Calling PHX_ControlReset yields a PHX_ERROR_BAD_HANDLE error.
    # - Re-reading the register until its value is OK (this does not work for
    #   write-only registers).
    #
    errmode = printerror(false) # temporarily switch off reporting of errors
    buf = Ref{T}(val)
    status = _setparam!(cam, key, buf)
    printerror(errmode) # restore previous mode
    if status == PHX_ERROR_MALLOC_FAILED && 1 ≤ cam.state ≤ 2
        if cam.state == 2
            @warn "Acquisition will be aborted due to setting a bogus parameter"
        end
        close(cam)
        open(cam; quiet=true)
        if _getparam(cam, key, buf) != PHX_OK || buf[] != val
            error("failed to change register value")
        end
    elseif status != PHX_OK
        _printlasterror()
        checkstatus(status)
    end
    return val
end

"""
    setfixedpatternnoisereduction!(cam, val)

switches the Fixed Pattern Noise Reduction feature on or off for camera `cam`.

    getfixedpatternnoisereduction(cam)

yields the current setting.

"""
setfixedpatternnoisereduction!(cam::Camera{MikrotronMC408xModel}, val::Bool) =
    cam[FIXED_PATTERN_NOISE_REDUCTION] = (val ? one(UInt32) : zero(UInt32))

getfixedpatternnoisereduction(cam::Camera{MikrotronMC408xModel}) =
    (cam[FIXED_PATTERN_NOISE_REDUCTION] != zero(UInt32))

@doc @doc(setfixedpatternnoisereduction!) getfixedpatternnoisereduction

"""
    setinfofieldframecounter!(cam, val)

enables/disables the *frame counter* info field in the images captured by
camera `cam`.  If enabled, the Frame Counter info field overwrites the 1-st to
4-th pixels of the images as a 32-bit unsigned integer.

    getinfofieldframecounter(cam)

yields the current setting.

    getinfofieldframecounter(cam, i)

yields the value of the frame counter info field in `i`-th captured image
buffer.

"""
setinfofieldframecounter!(cam::Camera{MikrotronMC408xModel}, val::Bool) =
    cam[INFO_FIELD_FRAME_COUNTER_ENABLE] = (val ? one(UInt32) : zero(UInt32))

getinfofieldframecounter(cam::Camera{MikrotronMC408xModel}) =
    (cam[INFO_FIELD_FRAME_COUNTER_ENABLE] != zero(UInt32))

getinfofieldframecounter(cam::Camera{MikrotronMC408xModel}, i::Integer) =
    convert(Int, getinfofieldvalue(UInt32, cam.imgs[i], 0))

@doc @doc(setinfofieldframecounter!) getinfofieldframecounter

"""
    setinfofieldtimestamp!(cam, val)

enables/disables the *time stamp* info field in the images captured by camera
`cam`.  The frequency of the time stamp counter amounts to 25 MHz (period = 40
nanoseconds) and is stored as a 32-bit unsigned integer.  If enabled, the time
stamp info field overwrites the 5-th to 8-th pixels of the images.

    getinfofieldtimestamp(cam)

yields the current setting.

    getinfofieldtimestamp(cam, i)

yields the value (in seconds) of the time stamp info field in `i`-th captured
image buffer.

"""
setinfofieldtimestamp!(cam::Camera{MikrotronMC408xModel}, val::Bool) =
    cam[INFO_FIELD_TIME_STAMP_ENABLE] = (val ? one(UInt32) : zero(UInt32))

getinfofieldtimestamp(cam::Camera{MikrotronMC408xModel}) =
    (cam[INFO_FIELD_TIME_STAMP_ENABLE] != zero(UInt32))

# The frequency of the time stamp counter amounts to 25 MHz (period = 40 nanoseconds).
getinfofieldtimestamp(cam::Camera{MikrotronMC408xModel}, i::Integer) =
    getinfofieldvalue(UInt32, cam.imgs[i], 4)*40e-9

getinfofieldvalue(::Type{UInt16}, img::Array{UInt8,2}, off::Int) =
    ((convert(UInt16, img[off+2]) <<  8) | convert(UInt16, img[off+1]))

getinfofieldvalue(::Type{UInt32}, img::Array{UInt8,2}, off::Int) =
    ((convert(UInt32, img[off+4]) << 24) |
     (convert(UInt32, img[off+3]) << 16) |
     (convert(UInt32, img[off+2]) <<  8) | convert(UInt32, img[off+1]))

getinfofieldvalue(::Type{UInt32}, img::Array{UInt16,2}, off::Int) =
    ((convert(UInt32, img[off+4] & 0x00FF) << 24) |
     (convert(UInt32, img[off+3] & 0x00FF) << 16) |
     (convert(UInt32, img[off+2] & 0x00FF) <<  8) | convert(UInt32, img[off+1] & 0x00FF))

@doc @doc(setinfofieldtimestamp!) getinfofieldtimestamp

"""
    setinfofieldroi!(cam, val)

enables/disables the *ROI* info field in the images captured by camera `cam`.
If enabled, the ROI info field overwrites the 9-th to 16-th pixels of the
images.  The ROI info is only available in 8-bit pixel format mode.

    getinfofieldroi(cam)

yields the current setting.

    getinfofieldroi(cam, i)

yields the value of the ROI info field in `i`-th captured image buffer.

"""
setinfofieldroi!(cam::Camera{MikrotronMC408xModel}, val::Bool) =
    cam[INFO_FIELD_ROI_ENABLE] = (val ? one(UInt32) : zero(UInt32))

getinfofieldroi(cam::Camera{MikrotronMC408xModel}) =
    (cam[INFO_FIELD_ROI_ENABLE] != zero(UInt32))

function getinfofieldroi(cam::Camera{MikrotronMC408xModel}, i::Integer)
    img = cam.imgs[i]
    xoff   = convert(Int, getinfofieldvalue(UInt16, img,  8))
    width  = convert(Int, getinfofieldvalue(UInt16, img, 10))
    yoff   = convert(Int, getinfofieldvalue(UInt16, img, 12))
    height = convert(Int, getinfofieldvalue(UInt16, img, 14))
    return (xoff, yoff, width, height)
end

@doc @doc(setinfofieldroi!) getinfofieldroi

"""
    setfiltermode!(cam, val)

enables/disables the image filter mode of the camera `cam`.

    getfiltermode(cam)

yiels the current setting.

"""
function setfiltermode!(cam::Camera{MikrotronMC408xModel}, val::Bool)
    if val
        format = cam[PIXEL_FORMAT]
        if (format == PIXEL_FORMAT_BAYERGR8 ||
            format == PIXEL_FORMAT_BAYERGR10)
            cam[FILTER_MODE] = FILTER_MODE_COLOR
        elseif (format == PIXEL_FORMAT_MONO8 ||
                format == PIXEL_FORMAT_MONO10)
            cam[FILTER_MODE] = FILTER_MODE_MONO
        else
            error("unknown pixel format (0x$(string(format, base=16)))")
        end
    else
        cam[FILTER_MODE] = FILTER_MODE_RAW
    end
    return nothing
end

getfiltermode(cam::Camera{MikrotronMC408xModel}) =
    (cam[FILTER_MODE] != FILTER_MODE_RAW)

end # module
