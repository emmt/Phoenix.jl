- `wait` now returns an image and a timestamp or throws a `TimeoutError` in
  case of timeout.

- New methods for the MikrotronMC408x camera: `setinfofieldframecounter!` and
  `getinfofieldframecounter` for info field frame counter to count images
  (overwriting the 4 first pixels of the captured images),
  `setinfofieldtimestamp!` and `getinfofieldtimestamp` for info field time
  stamp to time stamp images (overwriting the 5th to 8th pixels of the captured
  images), `setinfofieldroi!` and `getinfofieldroi` for info field ROI
  (overwriting the 9th to 16th pixels of the captured images),
  `setfixedpatternnoisereduction!` and `getfixedpatternnoisereduction` to deal
  with fixed pattern noise reduction, `setfiltermode!` and `getfiltermode` to
  deal with the *filter mode*.  See *Custom Features* in the doc. of the camera
  for more explanations.  Note that the source offsets (given by
  `cam[PHX_ROI_SRC_XOFFSET]` and `cam[PHX_ROI_SRC_YOFFSET]`) must be both 0 and
  the width of the ROI (given by `cam[PHX_ROI_XLENGTH]`) large enough for the
  info field to be part of the images stored in the destination buffers.

- Implement sub-sampling.

- Possibility to skip corrupted initial image(s).

- Use `ScientificCameras` package and implement its API.

- Add an access parameter in parameter/register definition so that it is easy to
  figure out whether a parameter is readable or writable.

- Hack to set pixel depth of the MikrotronMC408x camera.
