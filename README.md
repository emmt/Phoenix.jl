# Julia interface to ActiveSilicon Phoenix frame grabber

This module provides a Julia interface to ActiveSilicon Phoenix frame grabber.

## Table of contents

* [Usage](#usage)
* [Tricks](#tricks)
* [Installation](#installation)


## Usage

A typical example of using the `Phoenix` module to acquire and process
some frames is:

    using Phoenix
    cam = open(Phoenix.MikrotronMC408xModel)
    cfg = getconfiguration(cam)
    cfg.roi_x = ...
    cfg.roi_y = ...
    ...
    setconfiguration!(cam, cfg)
    bufs = start(cam, UInt16, 4)
    while true
        # Wait for next frame.
        index, number, overflows = waitframe(cam)
        buf = bufs[index] # get image buffer
        ... # process the image buffer
        releaseframe(cam)
        if number > 100
            break
        end
    end
    abort(cam)
    close(cam)

Step-by-step explanations are now given:

    using Phoenix

imports `Phoenix` module to directly access exported methods (and
constants);

    cam = open(Phoenix.MikrotronMC408xModel)

creates a new camera instance `cam` for the camera model
`MikrotronMC408xModel` and open its board connection;

    cfg = getconfiguration(cam)

retrieves the actual configuration of the camera as `cfg` (an instance of
`Phoenix.Configuration`);

    cfg.roi_x = ...
    cfg.roi_y = ...
    ...
    setconfiguration!(cam, cfg)

modifies the parameters and set the configuration to use with the camera;

    bufs = start(cam, UInt16, 4)

starts the acquisition with pixels of type `UInt16` and `4` virtual frame
buffers returned as `bufs`;

    while true
        # Wait for next frame.
        index, number, overflows = waitframe(cam)
        buf = bufs[index] # get image buffer
        ... # process the image buffer
        releaseframe(cam)
        if number > 100
            break
        end
    end

in the acquisition loop: waits for the next frame (and retrieves the index of
the current frame in the virtual buffers, the current frame number and the
number of overflows so far), carries out processing and releases the frame so
that it can be used to acquire another image;

    abort(cam)

aborts acquisition without waiting for the current frame to finish (another
possibility is to call `stop(cam)` which waits for the current frame);

    close(cam)

closes the camera (this is optional, closing is automatically done when the
camera is finalised by the garbage collector).


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
