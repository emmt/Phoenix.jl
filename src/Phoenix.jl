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
#include("mutex.jl")
include("base.jl")
include("utils.jl")
include("errors.jl")
#include("config.jl")
include("acquisition.jl")
include("models.jl")

end # module Phoenix
