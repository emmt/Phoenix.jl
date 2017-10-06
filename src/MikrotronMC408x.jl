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

using Phoenix
import Phoenix: Camera, CameraModel,
    Readable, Writable, ReadOnly, ReadWrite, WriteOnly, Unreachable,
    RegisterValue, RegisterString, RegisterCommand,
    RegisterEnum, RegisterAddress, Interval,
    subsampling_parameter, getconfig!, setconfig!,
    getfullwidth,
    getfullheight,
    restrict,
    assert_coaxpress,
    is_coaxpress,
    _check,
    _getparam, getparam,
    _setparam!, setparam!,
    _openhook,
    _starthook,
    _stophook

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
# const ACQUISITION_FRAME_RATE_MIN = 16 # FIXME: seems to be 2?
const ACQUISITION_FRAME_RATE_MAX    = RegisterValue{UInt32,ReadOnly}(0x881C)
const SEQUENCER_CONFIGURATION_MODE  = RegisterValue{UInt32,Unreachable}(0x8874)
const SEQUENCER_MODE                = RegisterValue{UInt32,Unreachable}(0x8870)
const SEQUENCER_SET_SELECTOR        = RegisterValue{Void,Unreachable}(0x8878)
const SEQUENCER_SET_SAVE            = RegisterValue{Void,Unreachable}(0x887C)
const SEQUENCER_SET_NEXT            = RegisterValue{Void,Unreachable}(0x8888)
const USER_SET_SELECTOR             = RegisterEnum{ReadWrite}(0x8820)
const USER_SET_LOAD                 = RegisterCommand{UInt32}(0x8824, 1) # FIXME:
const USER_SET_SAVE                 = RegisterCommand{UInt32}(0x8828, 1) # FIXME:
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
#const GAIN_INTERVAL                  = Interval(UInt32, 50, 1000)
const BLACK_LEVEL                     = RegisterValue{UInt32,ReadWrite}(0x8854)
#const BLACK_LEVEL_INTERVAL           = Interval(UInt32, 0, 500)
const GAMMA                           = RegisterValue{Float32,ReadWrite}(0x8858)
#const GAMMA_INTERVAL                 = Interval(Float32, 0.1, 3.0, 0.1)
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
function _openhook(cam::Camera{MikrotronMC408xModel})

    # Sanity checks.
    assert_coaxpress(cam)
    vendorname = cam[CXP_DEVICE_VENDOR_NAME]
    if vendorname != "Mikrotron GmbH"
        error("bad device vendor name (got \"$vendorname\", expecting \"Mikrotron GmbH\")")
    end
    modelname = cam[CXP_DEVICE_MODEL_NAME]
    if modelname != "MC4086"
        error("bad device model name (got \"$modelname\", expecting \"MC4086\")")
    end

    # Get size of current ROI and pixel format.
    width  = cam[WIDTH]
    height = cam[HEIGHT]
    depth = getdepth(cam)

    # FIXME: We do not support subsampling yet.
    xsub = Int(cam[DECIMATION_HORIZONTAL])
    if xsub != 1
        warn("horizontal subsampling is not yet supported")
        xsub = 1
        cam[DECIMATION_HORIZONTAL] = xsub
    end
    ysub = Int(cam[DECIMATION_VERTICAL])
    if ysub != 1
        warn("vertical subsampling is not yet supported")
        ysub = 1
        cam[DECIMATION_VERTICAL] = ysub
    end

    # The following settings are the same as the contents of the configuration
    # file "Mikrotron_MC4080_CXP.pcf".
    cam[PHX_BOARD_VARIANT]      = PHX_DIGITAL
    cam[PHX_CAM_TYPE]           = PHX_CAM_AREASCAN_ROI
    cam[PHX_DATASTREAM_VALID]   = PHX_DATASTREAM_ALWAYS
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

    # Format of the image sent by the camera (the subsampling by the camera is
    # taken into account in the computed width and height).
    cam[PHX_CAM_SRC_DEPTH]      = depth
    cam[PHX_CAM_ACTIVE_XOFFSET] = cam[OFFSET_X]
    cam[PHX_CAM_ACTIVE_YOFFSET] = cam[OFFSET_Y]
    cam[PHX_CAM_ACTIVE_XLENGTH] = width
    cam[PHX_CAM_ACTIVE_YLENGTH] = height
    cam[PHX_CAM_XBINNING]       = xsub
    cam[PHX_CAM_YBINNING]       = ysub

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
    cam[PHX_ROI_SRC_XOFFSET] = 0
    cam[PHX_ROI_SRC_YOFFSET] = 0
    cam[PHX_ROI_XLENGTH]     = width
    cam[PHX_ROI_YLENGTH]     = height

    # Setup destination buffer parameters.  The value of `PHX_BUF_DST_XLENGTH`
    # is the number of bytes per line of the destination buffer (it must be
    # larger of equal the width of the ROI times the number of bits per pixel
    # rounded up to a number of bytes), the value of `PHX_BUF_DST_YLENGTH` is
    # the number of lines in the destination buffer (it must be larger or equal
    # `PHX_ROI_DST_YOFFSET` plus `PHX_ROI_YLENGTH`.
    cam[PHX_ROI_DST_XOFFSET] = 0
    cam[PHX_ROI_DST_YOFFSET] = 0
    cam[PHX_BUF_DST_XLENGTH] = (depth ≤ 8 ? width : 2*width)
    cam[PHX_BUF_DST_YLENGTH] = height
    cam[PHX_BIT_SHIFT]       = 0 # FIXME: PHX_BIT_SHIFT_ALIGN_LSB not defined
    cam[PHX_DST_FORMAT]      = (depth ≤ 8 ? PHX_DST_FORMAT_Y8 :
                                PHX_DST_FORMAT_Y16)

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

_starthook(cam::Camera{MikrotronMC408xModel}) =
    send(cam, ACQUISITION_START)

_stophook(cam::Camera{MikrotronMC408xModel}) =
    send(cam, ACQUISITION_STOP)


"""
    getdepth(pixelformat)

yields the number of bits for the given pixel format of the MikrotronMC408x
camera.

"""
getdepth(pixelformat::Integer) =
    (pixelformat == PIXEL_FORMAT_MONO8 ||
     pixelformat == PIXEL_FORMAT_BAYERGR8) ? 8 :
     (pixelformat == PIXEL_FORMAT_MONO10 ||
      pixelformat == PIXEL_FORMAT_BAYERGR10) ? 10 :
      error("unknown pixel format")

getdepth(cam::Camera{MikrotronMC408xModel}) =
    getdepth(cam[PIXEL_FORMAT])

getfullwidth(cam::Camera{MikrotronMC408xModel}) =
    Int(cam[SENSOR_WIDTH])

getfullheight(cam::Camera{MikrotronMC408xModel}) =
    Int(cam[SENSOR_HEIGHT])

# This overloading of the method is to treat specifically certain problematic
# parameters such as the pixel format.
function setparam!(cam::Camera{MikrotronMC408xModel},
                   reg::RegisterValue{T,A}, val) where {T,A<:Writable}
    info("hacked version!")
    status = _setparam!(cam, reg, val)
    if (status != PHX_OK && reg.addr == PIXEL_FORMAT.addr
        && (val == PIXEL_FORMAT_MONO8 || val == PIXEL_FORMAT_MONO10 ||
            val == PIXEL_FORMAT_BAYERGR8 || val == PIXEL_FORMAT_BAYERGR10))
        info("hack triggered")
        # For some reasons, setting the pixel format returns an error (with
        # code `PHX_ERROR_MALLOC_FAILED`) which, in practice can be ignored as,
        # after a while, getting the pixel format yields the correct value.  A
        # number of queries of the pixel format are necessary (usually, the
        # first one yields an error, the second one yields a 0x07d0 pixel
        # format which corresponds to nothing, the third one yields the correct
        # value).
        #
        # To cope with this issue, we set pixel format ignoring errors and
        # repeatedly query the pixel format until it succeeds.  To avoid
        # alarming the user, printing of error messages is disabled during this
        # process.
        for i in 1:5
            if _getparam(cam, reg) == (PHX_OK, val)
                return nothing
            end
        end
        error("failed to change pixel format to 0x", hex(val))
    end
    _check(status)
end

end # module
