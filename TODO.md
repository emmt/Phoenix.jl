- Fix value(s) returned by `wait`; suggestion:  `img, ts = wait(cam, tm)` where
  `img` is the next image to process, `ts` is a timestamp (in seconds) and `tm`
  a timeout (in seconds).  In that case, add methods to query the number of missed
  frames.

- Suggestion: called as `read(cam)`, the read method should return a single
  image (not a vector with a single image).

- The `read` and `wait` methods can return images with various element types.
  This break *type invariance*, but it is easy to cope with that by having all
  processing done by methods (not inlined code).  This should be explained in
  the documentation with an example like computing the mean image of a running
  sequence.  Another possibility is to have filters (*e.g.* to apply
  preprocessing like bias and gain correction) which automatically convert the
  captured image to a given type (*e.g.* floating-point).

- Define a `TimeoutException <: Exception` to be thrown in case of timeout.
  When no exception occurs, `try ... catch ... end` takes less than 20ns (on
  average); when an exception occurs, it takes 25µs (on average); in any case
  the garbage collector is not triggered.

- For the MikrotronMC408x camera: disable *Pixel Pulse Reset*, read camera
  temperature, set the sensor clock rate. Set TriggerMode to off, use
  ExposureTimeMax and AcquisitionFrameRateMax registers to figure out the
  max. allowed values.  Use ConnectionConfig to set the connection speed.

- Fix hack in read() to avoid loosing one frame.

- Use Phoenix frame grabber counters.

- Cache settings (see benchmarking).

- Use maximal transmission speed.

- **DONE** Deal with corrupted first image.  Add an option to skip images in
  `read` if `skip > 0`, start at a given index (`PHX_ACQ_BUFFER_START`) and
  read `num + skip` images (`PHX_ACQ_NUM_IMAGES`) into `num` buffers with
  `PHX_ACQ_BLOCKING` and `PHX_ACQ_CONTINUOUS` both set to `PHX_DISABLE`

- **OBSOLETE** Use Julia package
  [`ColorTypes`](https://github.com/JuliaGraphics/ColorTypes.jl)

- **FIXED** Last image not taken.

- **DONE** Support subsampling or rebinning of pixels.

- **DONE** Automatically determine structure layout in `gencode.c`.

- **DONE** Simplify parameter definition:

  ````
  # The following does not work because union of values is not possible
  # (only union of types is allowed).
  const ReadAccess = 1
  const WriteAccess = 2
  const ReadWriteAccess = (ReadAccess | WriteAccess)
  const Readable = Union{ReadAccess,ReadWriteAccess}
  const Writable = Union{WriteAccess,ReadWriteAccess}

  # This should work (may be the derived types can be also abstract).
  abstract type AccessMode end
  struct Inaccessible <: AccessMode; end
  struct Unreachable <: AccessMode; end
  struct ReadOnly <: AccessMode; end
  struct WriteOnly <: AccessMode; end
  struct ReadWrite <: AccessMode; end
  const Readable = Union{ReadOnly,ReadWrite}
  const Writable = Union{WriteOnly,ReadWrite}

  readable(::Type{T}) where {T <: AccessMode} = false
  readable(::Type{T}) where {T <: Readable} = true
  writable(::Type{T}) where {T <: AccessMode} = false
  writable(::Type{T}) where {T <: Writable} = true

  # Other possibility.
  readable(::Type{WriteOnly}) = false
  readable(::Type{T}) where {T <: Readable} = true
  writable(::Type{ReadOnly}) = false
  writable(::Type{T}) where {T <: Writable} = true

  struct Param{T,A}
      key::UInt32
  end
  ````

with `T` the type of the parameter value and `A` one of the access mode.
