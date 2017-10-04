#
# types.jl -
#
# Defines camera models and methods specific to given camera models.  In
# particular, the addresses for registers required to be able to stream images
# from a CoaXPress camera.
#
#------------------------------------------------------------------------------
#
# This file is part of the `Phoenix.jl` package which is licensed under the MIT
# "Expat" License.
#
# Copyright (C) 2016, Éric Thiébaut & Jonathan Léger.
# Copyright (C) 2017, Éric Thiébaut.
#

# Generic camera model.
struct GenericCameraModel <: CameraModel; end

function _openhook(cam::Camera{GenericCameraModel})
    if false
        # Set default configuration (as in `default.pcf`).
        cam[PHX_BOARD_VARIANT]      = PHX_DIGITAL
        cam[PHX_CAM_TYPE]           = PHX_CAM_AREASCAN_ROI
        cam[PHX_CAM_SRC_DEPTH]      = 8
        cam[PHX_CAM_SRC_COL]        = PHX_CAM_SRC_MONO
        cam[PHX_CAM_ACTIVE_XOFFSET] = 0
        cam[PHX_CAM_ACTIVE_YOFFSET] = 0
        cam[PHX_CAM_ACTIVE_XLENGTH] = 640
        cam[PHX_CAM_ACTIVE_YLENGTH] = 480
        cam[PHX_CAM_HTAP_DIR]       = PHX_CAM_HTAP_LEFT
        cam[PHX_CAM_HTAP_TYPE]      = PHX_CAM_HTAP_LINEAR
        cam[PHX_CAM_HTAP_NUM]       = 1
        cam[PHX_CAM_VTAP_DIR]       = PHX_CAM_VTAP_TOP
        cam[PHX_CAM_VTAP_TYPE]      = PHX_CAM_VTAP_LINEAR
        cam[PHX_CAM_VTAP_NUM]       = 1
        cam[PHX_COMMS_DATA]         = PHX_COMMS_DATA_8
        cam[PHX_COMMS_STOP]         = PHX_COMMS_STOP_1
        cam[PHX_COMMS_PARITY]       = PHX_COMMS_PARITY_NONE
        cam[PHX_COMMS_SPEED]        = 9600
        cam[PHX_COMMS_FLOW]         = PHX_COMMS_FLOW_NONE
    end
    return PHX_OK
end


struct ActiveSiliconTestModel <: CameraModel; end

_starthook(cam::Camera{ActiveSiliconTestModel}) =
    write(cam, RegisterConstant{UInt32}(0x6000, 0))

_stophook(cam::Camera{ActiveSiliconTestModel}) =
    write(cam, RegisterConstant{UInt32}(0x6000, 1))


struct AdimecOpal2000cModel <: CameraModel; end

_starthook(cam::Camera{AdimecOpal2000cModel}) =
    write(cam, RegisterConstant{UInt32}(0x8204, 1))

_stophook(cam::Camera{AdimecOpal2000cModel}) =
    write(cam, RegisterConstant{UInt32}(0x8208, 1))


struct AdimecOpal2000mModel <: CameraModel; end

_starthook(cam::Camera{AdimecOpal2000mModel}) =
    write(cam, RegisterConstant{UInt32}(0x8204, 1))

_stophook(cam::Camera{AdimecOpal2000mModel}) =
    write(cam, RegisterConstant{UInt32}(0x8208, 1))


struct AdimecQuartz4A180Model <: CameraModel; end

_starthook(cam::Camera{AdimecQuartz4A180Model}) =
    write(cam, RegisterConstant{UInt32}(0x8204, 1))

_stophook(cam::Camera{AdimecQuartz4A180Model}) =
    write(cam, RegisterConstant{UInt32}(0x8208, 1))


struct E2vEliixa16kColorModel <: CameraModel; end

_starthook(cam::Camera{E2vEliixa16kColorModel}) =
    write(cam, RegisterConstant{UInt32}(0x700C, 0))

_stophook(cam::Camera{E2vEliixa16kColorModel}) =
    write(cam, RegisterConstant{UInt32}(0x7010, 0))


struct E2vEliixa16kMonoModel <: CameraModel; end

_starthook(cam::Camera{E2vEliixa16kMonoModel}) =
    write(cam, RegisterConstant{UInt32}(0x700C, 0))

_stophook(cam::Camera{E2vEliixa16kMonoModel}) =
    write(cam, RegisterConstant{UInt32}(0x7010, 0))


struct ImperxModel <: CameraModel; end

_starthook(cam::Camera{ImperxModel}) =
    write(cam, RegisterConstant{UInt32}(0x10000020, 1))

_stophook(cam::Camera{ImperxModel}) =
    write(cam, RegisterConstant{UInt32}(0x10000024, 1))


struct IoIndustries4M140Model <: CameraModel; end

_starthook(cam::Camera{IoIndustries4M140Model}) =
    write(cam, RegisterConstant{UInt32}(0x10000020, 1))

_stophook(cam::Camera{IoIndustries4M140Model}) =
    write(cam, RegisterConstant{UInt32}(0x10000024, 1))


struct ISVI_C25M_CXP_Model <: CameraModel; end

_starthook(cam::Camera{ISVI_C25M_CXP_Model}) =
    write(cam, RegisterConstant{UInt32}(0x6050, 1))

_stophook(cam::Camera{ISVI_C25M_CXP_Model}) =
    write(cam, RegisterConstant{UInt32}(0x6050, 0))


struct ISVI_M12M_CXP_Model <: CameraModel; end

_starthook(cam::Camera{ISVI_M12M_CXP_Model}) =
    write(cam, RegisterConstant{UInt32}(0x6050, 1))

_stophook(cam::Camera{ISVI_M12M_CXP_Model}) =
    write(cam, RegisterConstant{UInt32}(0x6050, 0))


struct ISVI_M25M_CXP_Model <: CameraModel; end

_starthook(cam::Camera{ISVI_M25M_CXP_Model}) =
    write(cam, RegisterConstant{UInt32}(0x6050, 1))

_stophook(cam::Camera{ISVI_M25M_CXP_Model}) =
    write(cam, RegisterConstant{UInt32}(0x6050, 0))


struct JAI_SP_5000M_Model <: CameraModel; end

_starthook(cam::Camera{JAI_SP_5000M_Model}) =
    write(cam, RegisterConstant{UInt32}(0x200B0, 1))

_stophook(cam::Camera{JAI_SP_5000M_Model}) =
    write(cam, RegisterConstant{UInt32}(0x200B4, 1))


# struct MikrotronMC408xModel <: CameraModel; end
#
# _starthook(cam::Camera{MikrotronMC408xModel}) =
#     write(cam, RegisterConstant{UInt32}(0x8204, 1))
#
# _stophook(cam::Camera{MikrotronMC408xModel}) =
#     write(cam, RegisterConstant{UInt32}(0x8208, 1))
include("MikrotronMC408x.jl")
import .MikrotronMC408x: MikrotronMC408xModel


struct OptronisCL4000Model <: CameraModel; end

_starthook(cam::Camera{OptronisCL4000Model}) =
    write(cam, RegisterConstant{UInt32}(0x601C, 1))

_stophook(cam::Camera{OptronisCL4000Model}) =
    write(cam, RegisterConstant{UInt32}(0x601C, 0))


struct OptronisCL25000Model <: CameraModel; end

_starthook(cam::Camera{OptronisCL25000Model}) =
    write(cam, RegisterConstant{UInt32}(0x601C, 1))

_stophook(cam::Camera{OptronisCL25000Model}) =
    write(cam, RegisterConstant{UInt32}(0x601C, 0))
