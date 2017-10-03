# Julia interface to ActiveSilicon Phoenix frame grabber

This module provides a Julia interface to ActiveSilicon Phoenix frame grabber.


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


## Usage

A typical example of using the `Phoenix` module to acquire and process
some frames is:

    using Phoenix
    cam = Phoenix.Camera(MikrotronMC408xModel)
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


Step-by-step explanations are now given:

    using Phoenix

imports `Phoenix` module to directly access exported methods (and
constants);

    cam = Phoenix.Camera(MikrotronMC408xModel)

creates a new camera instance `cam` for the camera model
`MikrotronMC408xModel`;

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
possibility is to call `stop(cam)` which waits for the current frame).
