##
##  @file libattopng.h
##  @brief A minimal C library to write uncompressed PNG files.
##
##  libattopng is a minimal C library to create uncompressed PNG images.
##  It is cross-platform compatible, has no dependencies and a very small footprint.
##  The library supports palette, grayscale as well as raw RGB images all with and without transparency.
##
##  @author Michael Schwarz
##  @date 29 Jan 2017
##

##
##  @brief PNG type.
##
##  The type of PNG image. It determines how the pixels are stored.
##

type
  libattopng_type_t* = enum
    PNG_GRAYSCALE = 0,          ## < 256 shades of gray, 8bit per pixel
    PNG_RGB = 2,                ## < 24bit RGB values
    PNG_PALETTE = 3,            ## < Up to 256 RGBA palette colors, 8bit per pixel
    PNG_GRAYSCALE_ALPHA = 4,    ## < 256 shades of gray plus alpha channel, 16bit per pixel
    PNG_RGBA = 6                ## < 24bit RGB values plus 8bit alpha channel


##
##  @brief Reference to a PNG image
##
##  This struct holds the internal state of the PNG. The members should never be used directly.
##

type
  uint32_t* = uint32
  uint16_t* = uint16
  libattopng_t* {.bycopy.} = object
    `type`*: libattopng_type_t
    ## < File type
    capacity*: csize_t
    ## < Reserved memory for raw data
    data*: cstring
    ## < Raw pixel data, format depends on type
    palette*: ptr uint32_t
    ## < Palette for image
    palette_length*: csize_t
    ## < Entries for palette, 0 if unused
    width*: csize_t
    ## < Image width
    height*: csize_t
    ## < Image height
    `out`*: cstring
    ## < Buffer to store final PNG
    out_pos*: csize_t
    ## < Current size of output buffer
    out_capacity*: csize_t
    ## < Capacity of output buffer
    crc*: uint32_t
    ## < Currecnt CRC32 checksum
    s1*: uint16_t
    ## < Helper variables for Adler checksum
    s2*: uint16_t
    ## < Helper variables for Adler checksum
    bpp*: csize_t
    ## < Bytes per pixel
    stream_x*: csize_t
    ## < Current x coordinate for pixel streaming
    stream_y*: csize_t
    ## < Current y coordinate for pixel streaming

{.push importc, cdecl.}
##
##  @function libattopng_new
##
##  @brief Create a new, empty PNG image to be used with all other functions.
##
##  @param width The width of the image in  pixels
##  @param height The height of the image in pixels
##  @param type The type of image. Possible values are
##                   - PNG_GRAYSCALE (8bit grayscale),
##                   - PNG_GRAYSCALE_ALPHA (8bit grayscale with 8bit alpha),
##                   - PNG_PALETTE (palette with up to 256 entries, each 32bit RGBA)
##                   - PNG_RGB (24bit RGB values)
##                   - PNG_RGBA (32bit RGB values with alpha)
##  @return reference to a PNG image to be used with all other functions or NULL on error.
##           Possible errors are:
##               - Out of memory
##               - Width and height combined exceed the maximum integer size
##  @note It's the callers responsibility to free the data structure.
##        See @ref libattopng_destroy
##

proc libattopng_new*(width: csize_t; height: csize_t; `type`: libattopng_type_t): ptr libattopng_t
##
##  @function libattopng_destroy
##
##  @brief Destroys the reference to a PNG image and free all associated memory.
##
##  @param png Reference to the image
##
##

proc libattopng_destroy*(png: ptr libattopng_t)
##
##  @function libattopng_set_palette
##
##  @brief Sets the image's palette if the image type is \ref PNG_PALETTE.
##
##  @param png      Reference to the image
##  @param palette  Color palette, each entry contains a 32bit RGBA value
##  @param length   Number of palette entries
##  @return 0 on success, 1 if the palette contained more than 256 entries
##

proc libattopng_set_palette*(png: ptr libattopng_t; palette: ptr uint32_t;
                            length: csize_t): cint
##
##  @function libattopng_set_pixel
##
##  @brief Sets the pixel's color at the specified position
##
##  @param png    Reference to the image
##  @param x      X coordinate
##  @param y      Y coordinate
##  @param color The pixel value, depending on the type this is
##               - the 8bit palette index (\ref PNG_PALETTE)
##               - the 8bit gray value (\ref PNG_GRAYSCALE)
##               - a 16bit value where the lower 8bit are the gray value and
##                 the upper 8bit are the opacity (\ref PNG_GRAYSCALE_ALPHA)
##               - a 24bit RGB value (\ref PNG_RGB)
##               - a 32bit RGBA value (\ref PNG_RGBA)
##  @note If the coordinates are not within the bounds of the image,
##        the functions does nothing.
##

proc libattopng_set_pixel*(png: ptr libattopng_t; x: csize_t; y: csize_t;
                          color: uint32_t)
##
##  @function libattopng_get_pixel
##
##  @brief Returns the pixel's color at the specified position
##
##  @param png   Reference to the image
##  @param x     X coordinate
##  @param y     Y coordinate
##  @return      The pixel value, depending on the type this is
##               - the 8bit palette index (\ref PNG_PALETTE)
##               - the 8bit gray value (\ref PNG_GRAYSCALE)
##               - a 16bit value where the lower 8bit are the gray value and
##                 the upper 8bit are the opacity (\ref PNG_GRAYSCALE_ALPHA)
##               - a 24bit RGB value (\ref PNG_RGB)
##               - a 32bit RGBA value (\ref PNG_RGBA)
##               - 0 if the coordinates are out of bounds
##

proc libattopng_get_pixel*(png: ptr libattopng_t; x: csize_t; y: csize_t): uint32_t
##
##  @function libattopng_start_stream
##
##  @brief Set the start position for a batch of pixels
##
##  @param png  Reference to the image
##  @param x    X coordinate
##  @param y    Y coordinate
##
##  @see libattopng_put_pixel
##

proc libattopng_start_stream*(png: ptr libattopng_t; x: csize_t; y: csize_t)
##
##  @function libattopng_put_pixel
##
##  @brief Sets the pixel of the current pixel within a stream and advances to the next pixel
##
##  @param png   Reference to the image
##  @param color The pixel value, depending on the type this is
##               - the 8bit palette index (\ref PNG_PALETTE)
##               - the 8bit gray value (\ref PNG_GRAYSCALE)
##               - a 16bit value where the lower 8bit are the gray value and
##                 the upper 8bit are the opacity (\ref PNG_GRAYSCALE_ALPHA)
##               - a 24bit RGB value (\ref PNG_RGB)
##               - a 32bit RGBA value (\ref PNG_RGBA)
##

proc libattopng_put_pixel*(png: ptr libattopng_t; color: uint32_t)
##
##  @function libattopng_get_data
##
##  @brief Returns the image as PNG data stream
##
##  @param png  Reference to the image
##  @param len  The length of the data stream is written to this output parameter
##  @return A reference to the PNG output stream
##  @note The data stream is free'd when calling \ref libattopng_destroy and
##        must not be free'd be the caller
##

proc libattopng_get_data*(png: ptr libattopng_t; len: ptr csize_t): cstring
##
##  @function libattopng_save
##
##  @brief Saves the image as a PNG file
##
##  @param png      Reference to the image
##  @param filename Name of the file
##  @return 0 on success, 1 on error
##

proc libattopng_save*(png: ptr libattopng_t; filename: cstring): cint

{.pop.}
