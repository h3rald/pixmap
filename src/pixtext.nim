

import 
#  pixtextpkg/libattopng,
  pixtextpkg/lodepng

#{.compile: "pixtextpkg/vendor/libattopng.c".}
{.compile: "./pixtextpkg/vendor/lodepng.cpp".}


proc readPng(file: string): seq[uint8] =
  var data: ptr ptr uint8 = cast[ptr ptr uint8](alloc(sizeof(ptr ptr uint8)))
  var width: ptr cuint
  var height: ptr cuint
  let error = lodepng_decode32_file(data, width, height, file)
  if (error > 0):
    echo lodepng_error_text(error)
  result = cast[seq[uint8]](data)

when isMainModule:
  echo readPng("test.png")
