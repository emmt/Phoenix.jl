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
    RegisterValue, RegisterString, RegisterConstant,
    RegisterEnum, RegisterAddress

#
# CoaXPress camera constants for a Mikrotron MC408x camera.  These values have
# been extracted from the XML configuration file of the camera.
#
# FIXME: The XML file says that register HsUpConnection is at address 0x4030,
#         while CoaXPress standard says that it is at address 0x403C.
#

const ACQUISITION_MODE  = RegisterValue{UInt32}(0x8200)
const ACQUISITION_START = RegisterConstant{UInt32}(0x8204, 1)
const ACQUISITION_STOP  = RegisterConstant{UInt32}(0x8208, 1)

const ACQUISITION_BURST_FRAME_COUNT = RegisterValue{UInt32}(0x8914)
const TRIGGER_SELECTOR              = RegisterValue{UInt32}(0x8900)
const TRIGGER_MODE                  = RegisterValue{UInt32}(0x8904)
const TRIGGER_SOURCE                = RegisterValue{UInt32}(0x8908)
const TRIGGER_ACTIVATION            = RegisterValue{UInt32}(0x890C)
const TRIGGER_COUNT                 = RegisterValue{Void}(0x891C)
const TRIGGER_DEBOUNCER             = RegisterValue{Void}(0x8918)
const TRIGGER_SOFTWARE              = RegisterValue{Void}(0x8910)
const TEST_IMAGE_SELECTOR           = RegisterValue{Void}(0x9000)
const EXPOSURE_MODE                 = RegisterValue{UInt32}(0x8944)

const EXPOSURE_TIME_MAX             = RegisterValue{UInt32}(0x8818)
const ACQUISITION_FRAME_RATE        = RegisterValue{UInt32}(0x8814)
# const ACQUISITION_FRAME_RATE_MIN = 16
const ACQUISITION_FRAME_RATE_MAX    = RegisterValue{UInt32}(0x881C)
const SEQUENCER_CONFIGURATION_MODE  = RegisterValue{UInt32}(0x8874)
const SEQUENCER_MODE                = RegisterValue{UInt32}(0x8870)
const SEQUENCER_SET_SELECTOR        = RegisterValue{Void}(0x8878)
const SEQUENCER_SET_SAVE            = RegisterValue{Void}(0x887C)
const SEQUENCER_SET_NEXT            = RegisterValue{Void}(0x8888)
const USER_SET_SELECTOR             = RegisterValue{Void}(0x8820)
const USER_SET_LOAD                 = RegisterValue{Void}(0x8824)
const USER_SET_SAVE                 = RegisterValue{Void}(0x8828)
const USER_SET_DEFAULT_SELECTOR     = RegisterValue{Void}(0x882C)
const DEVICE_RESET                  = RegisterValue{Void}(0x8300)

# Image Format Control.
const HORIZONTAL_INCREMENT          = 16
const VERTICAL_INCREMENT            =  2
const REGION_SELECTOR               = RegisterEnum(0x8180)
const REGION_MODE                   = RegisterEnum(0x8184)
const REGION_DESTINATION            = RegisterEnum(0x8188) # always 0x0, i.e. "Stream1"
const WIDTH                         = RegisterValue{UInt32}(0x8118)
const HEIGHT                        = RegisterValue{UInt32}(0x811c)
const OFFSET_X                      = RegisterValue{UInt32}(0x8800)
const OFFSET_Y                      = RegisterValue{UInt32}(0x8804)
const DECIMATION_HORIZONTAL         = RegisterValue{UInt32}(0x8190)
const DECIMATION_VERTICAL           = RegisterValue{UInt32}(0x818c)
const SENSOR_HEIGHT                 = RegisterValue{UInt32}(0x880c)
const SENSOR_WIDTH                  = RegisterValue{UInt32}(0x8808)
# WidthMax = (((SENSOR_WIDTH - OFFSET_X)/16)*16)
# HeightMax = (((SENSOR_HEIGHT - OFFSET_Y)/2)*2)
const TAP_GEOMETRY = RegisterEnum(0x8160) # always 0x0, i.e. "Geometry_1X_1Y"
const PIXEL_FORMAT = RegisterValue{UInt32}(0x8144)
const IMAGE1_STREAM_ID = RegisterValue{UInt32}(0x8164)
# DeviceScanType = always 0x0, i.e. "Areascan"

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

const CONNECTION_CONFIG               = RegisterValue{UInt32}(0x4014)
const GAIN                            = RegisterValue{UInt32}(0x8850)
const BLACK_LEVEL                     = RegisterValue{UInt32}(0x8854)
const GAMMA                           = RegisterValue{Float32}(0x8858)
const LINE_INVERTER                   = RegisterValue{Void}(0x8A20)
const TX_LOGICAL_CONNECTION_RESET     = RegisterValue{Void}(0x9010)
const PRST_ENABLE                     = RegisterValue{Void}(0x9200)
const PULSE_DRAIN_ENABLE              = RegisterValue{Void}(0x9204)
const CUSTOM_SENSOR_CLK_ENABLE        = RegisterValue{Void}(0x9300)
const CUSTOM_SENSOR_CLK               = RegisterValue{Void}(0x9304)
const DEVICE_INFORMATION              = RegisterValue{Void}(0x8A04)
const DEVICE_INFORMATION_SELECTOR     = RegisterValue{Void}(0x8A00)
const ANALOG_REGISTER_SET_SELECTOR    = RegisterValue{Void}(0x20000)
const ANALOG_REGISTER_SELECTOR        = RegisterValue{Void}(0x20004)
const ANALOG_VALUE                    = RegisterValue{Void}(0x20008)
const INFO_FIELD_FRAME_COUNTER_ENABLE = RegisterValue{Void}(0x9310)
const INFO_FIELD_TIME_STAMP_ENABLE    = RegisterValue{Void}(0x9314)
const INFO_FIELD_ROI_ENABLE           = RegisterValue{Void}(0x9318)
const FIXED_PATTERN_NOISE_REDUCTION   = RegisterValue{Void}(0x8A10)
const FILTER_MODE                     = RegisterValue{Void}(0x10014)
const PIXEL_TYPE_F                    = RegisterValue{Void}(0x51004)
const DIN1_CONNECTOR_TYPE             = RegisterValue{Void}(0x8A30)
const IS_IMPLEMENTED_MULTI_ROI        = RegisterValue{Void}(0x50004)
const IS_IMPLEMENTED_SEQUENCER        = RegisterValue{Void}(0x50008)
const CAMERA_TYPE_HEX                 = RegisterValue{Void}(0x51000)
const CAMERA_STATUS                   = RegisterValue{Void}(0x10002200)
const IS_STOPPED                      = RegisterValue{Void}(0x10002204)


# Singleton to uniquely identify this camera model.
struct MikrotronMC408xModel <: CameraModel; end

Phoenix._starthook(cam::Camera{MikrotronMC408xModel}) =
    write(cam, ACQUISITION_START)

Phoenix._stophook(cam::Camera{MikrotronMC408xModel}) =
    write(cam, ACQUISITION_STOP)

end # module
