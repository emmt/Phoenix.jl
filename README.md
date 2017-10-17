# Julia interface to ActiveSilicon Phoenix frame grabber

This module provides a Julia interface to ActiveSilicon Phoenix frame grabber.

## Table of contents

* [Usage](#usage)
* [Tricks](#tricks)
* [Installation](#installation)


## Usage

The [`Phoenix`]((https://github.com/emmt/Phoenix.jl) package complies with the
[`ScientificCameras`](https://github.com/emmt/ScientificCameras.jl) interface.
This interface is detailled there but some short examples are provided in what
follows.

The simplest example of sequential acqisition of `n` images is:

    using Phoenix
    cam = open(Phoenix.MikrotronMC408xModel)
    imgs = read(cam, n)
    close(cam) # optional

The simplest example of continuous acquisition (using 4 image buffers) and
processing is:

    using Phoenix
    cam = open(Phoenix.MikrotronMC408xModel)
    bufs = start(cam, 4)
    for number in 1:100
        index = wait(cam) # wait for next frame
        buf = bufs[index] # get image buffer
        ... # process the image buffer
        release(cam)
    end
    abort(cam)
    close(cam) # optional

Note that:

    using Phoenix

imports `Phoenix` module to directly access exported methods notably all public
methods from the package
[`ScientificCameras`](https://github.com/emmt/ScientificCameras.jl) which does
not need to be imported.  Importing the `Phoenix` module also defines some
constants prefixed by `PHX_` or `CXP_`.


### Additions to the standard interface

Some additional options are available for some methods compared to the
interface specified in the
[`ScientificCameras`](https://github.com/emmt/ScientificCameras.jl) package:

- In the `read` method, keyword `skip` can be used to specify the number of
  initial image buffers to skip (*e.g.* to get rid of *dirty* images).

- In the `wait` method, keyword `drop` indicates whether to get rid of the
  oldest image buffers when there are more than one pending image buffers;


## Tricks

To figure out the type of connected camera, you may use the
`Phoenix.GenericCameraModel` model and the `summary` method:

    summary(open(Phoenix.GenericCameraModel))

Note that you may specify the configuration file, board number, *etc.* as
keywords to the `open` method above.


To figure out which camera models are implemented, you exploit introspection
and do:

    subtypes(Phoenix.CameraModel)


## Installation

To be able to use this module, you must have installed ActiveSilicon Phoenix
libraries and the module [`IPC.jl`](https://github.com/emmt/IPC.jl).

`Phoenix.jl` is not yet an [official Julia package](https://pkg.julialang.org/)
so you have to clone the repository to install the module:

    Pkg.clone("https://github.com/emmt/Phoenix.jl.git")
    Pkg.build("Phoenix")

Later, it is sufficient to do:

    Pkg.update("Phoenix")
    Pkg.build("Phoenix")

to pull the latest version.  If you have `Phoenix.jl` repository not managed at
all by Julia's package manager, updating is a matter of:

    cd "$PHOENIX/deps"
    git pull
    make

assuming `$PHOENIX` is the path to the top level directory of the `Phoenix.jl`
repository.

Note that the build process assumes that ActiveSilicon libraries have been
installed in the usual directory `/usr/local/activesilicon`.  If this is not
the case, to update the code and build the dependencies, you'll have to do
something like:

    cd "$PHOENIX/deps"
    git pull
    make PHX_DIR="$INSTALLDIR"

where `$INSTALLDIR` is the path where ActiveSilicon libraries have been
installed.
