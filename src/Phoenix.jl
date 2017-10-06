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

export
    PHXError,
    stop,
    abort,
    setconfig!,
    getconfig!,
    fixconfig!,
    getfullwidth,
    getfullheight,
    getfullsize

include("constants.jl")
include("CoaXPress.jl")
include("types.jl")
include("base.jl")
include("utils.jl")
include("errors.jl")
#include("config.jl")
#include("acquisition.jl")
include("models.jl")

end # module Phoenix
