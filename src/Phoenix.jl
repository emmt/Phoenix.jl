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

import Base: read, write, open, close

export PHXError, stop, abort

# Cope with changing version...
if Base.VERSION < v"0.5"
    include("compat.jl")
end

# Get definitions of basic types and constants for Phoenix frame grabber
# and for CoaXPress cameras.
include("constants.jl")
include("CoaXPress.jl")
include("types.jl")

include("base.jl")
include("errors.jl")
#include("config.jl")
#include("acquisition.jl")

# Load various camera models.
include("models.jl")

end # module Phoenix
