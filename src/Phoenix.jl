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
# Copyright (C) 2017-2019, Éric Thiébaut (https://github.com/emmt/Phoenix.jl).
# Copyright (C) 2016, Éric Thiébaut & Jonathan Léger.
#

module Phoenix

export
    PHXError

# Import `ScientificCameras` methods in such a way (i.e. with `importall`) that
# they can be extended in this module and re-export them to make things easier
# for the end-user.
# FIXME: see https://github.com/NTimmons/ImportAll.jl
using ScientificCameras
for sym in names(ScientificCameras)
    if sym != :ScientificCameras
        @eval begin
            import ScientificCameras: $sym
            export $sym
        end
    end
end
import ScientificCameras: TimeoutError, ScientificCamera, ROI
using ScientificCameras.PixelFormats

using Printf, Libdl

# Re-export the public interface of the ScientificCameras module.
ScientificCameras.@exportpublicinterface

# Import methods for overloading them.
import Base: convert

isfile(joinpath(@__DIR__, "..", "deps", "deps.jl")) ||
    error("Phoenix package not properly installed.  Please run Pkg.build(\"Phoenix\")")
include(joinpath("..", "deps", "deps.jl"))
include("CoaXPress.jl")
include("types.jl")
include("base.jl")
include("utils.jl")
include("errors.jl")
include("acquisition.jl")

const _DEVEL_SYMBOLS = (:AccessMode,
                        :Unreachable,
                        :ReadOnly,
                        :WriteOnly,
                        :ReadWrite,
                        :Readable,
                        :Writable,
                        :Handle,
                        :FnTypes,
                        :PhxFn,
                        :CamConfigLoad,
                        :ActionParam,
                        :Action,
                        :ComParam,
                        :ParamCompatibility,
                        :ParamValue,
                        :IOMethod,
                        :BoardInfo,
                        :PcieInfo,
                        :CxpInfo,
                        :Acq,
                        :BufferParam,
                        :Timeouts,
                        :Status,
                        :LutCtrl,
                        :ControlPort,
                        :ImageBuff,
                        :UserBuff,
                        :TimeStamp,
                        :Colour,
                        :LutInfo,
                        :Param,
                        :Register,
                        :RegisterValue,
                        :RegisterEnum,
                        :RegisterAddress,
                        :RegisterCommand,
                        :RegisterString,
                        :checkstatus,
                        :getparam,
                        :_getparam,
                        :resolve,
                        :setparam!,
                        :_setparam!,
                        :flushcache,
                        :saveconfig,
                        :readstream,
                        :_readstream,
                        :_readregister,
                        :_readcontrol,
                        :_writeregister,
                        :_writecontrol,
                        :CAPTURE_FORMATS,
                        :capture_format,
                        :capture_format_bits,
                        :best_capture_format,
                        :cstring,
                        :is_coaxpress,
                        :assert_coaxpress,
                        :getvendorname,
                        :getmodelname,
                        :getdevicemanufacturer,
                        :getdeviceversion,
                        :getdeviceserialnumber,
                        :getdeviceuserid,
                        :subsampling_parameter,
                        :gettimeofday,
                        :TimeVal,
                        :TimeSpec,
                        :AcquisitionContext,
                        :CameraModel,
                        :Camera,
                        :isforever,
                        :geterrormessage,
                        :geterrorsymbol,
                        :printerror,
                        :exec,
                        :_openhook,
                        :_starthook,
                        :_stophook)

include("models.jl")

end # module Phoenix
