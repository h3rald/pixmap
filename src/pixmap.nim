import 
  std/sequtils,
  std/strutils,
  std/parseopt,
  std/paths,
  std/os,
  nimPNG,
  pixmappkg/config

type
  PixMapData* = object
    pixels: seq[string]
    width: int
    height: int

type
  PngData* = object
    pixels: seq[byte]
    width: int
    height: int

type 
  PixMap* = object
    width: int
    height: int
    matrix: seq[seq[string]]
    text: string
    palette: seq[string]

var TARGET = ""
var OPT_OUTPUT = ""
var OPT_MAGNIFICATION = 1
var ARGS = newSeq[string]()

proc readPng(file: string): PixMapData =
  let png = loadPNG32(seq[byte], file).get
  let bytes = png.data.mapIt(it.ord.toHex(2)).toSeq()
  var c = 1
  var pixel = ""
  var pixels = newSeq[string](0)
  for b in bytes:
    pixel &= b
    if c mod 4 == 0:
      pixels.add pixel
      pixel = ""
    c += 1
  result.pixels = pixels
  result.height = png.height
  result.width = png.width

proc png*(inMap: string, inPalette: string): PngData =
  let pixmap = inMap.readFile
  let palette = inPalette.readFile.split("\n")
  let lines = pixmap.split("\n")
  let height = lines.len
  let width = lines[0].len
  var pixels: seq[byte] = newSeq[byte]()
  for line in lines:
    for cell in line:
      var val = ""
      if cell == ' ':
        val = "00000000"
      else:
        val = palette[($cell).parseInt]
      pixels.add val[0..1].parseHexInt.byte
      pixels.add val[2..3].parseHexInt.byte
      pixels.add val[4..5].parseHexInt.byte
      pixels.add val[6..7].parseHexInt.byte
  result.pixels = pixels
  result.width = width
  result.height = height

proc pixmap*(file: string): PixMap =
  let image = readPng(file)
  result.text = ""
  result.width = image.width
  result.height = image.height
  result.matrix = newSeq[seq[string]](result.height)
  var rows = -1
  var cols = 0
  var count = 0
  for pixel in image.pixels:
    if count mod image.width == 0 and count < image.pixels.len:
      # New row
      rows += 1
      cols = 0
      result.matrix[rows] = newSeq[string](result.width)
    else:
      cols += 1
    if not result.palette.contains(pixel) and pixel != "00000000":
      # Add new color to palette
      result.palette.add pixel
    if pixel == "00000000":
      # Transparent pixel
      result.matrix[rows][cols] = " "
    else:
      let index = result.palette.find(pixel)
      result.matrix[rows][cols] = index.toHex(1)
    count += 1
  for mr in countup(0, result.height-1):
    for xr in countup(1, OPT_MAGNIFICATION):
      for mc in countup(0, result.width-1):
        for xc in countup(1, OPT_MAGNIFICATION):
          result.text &= result.matrix[mr][mc]
      result.text &= "\n"
  # Remove last "\n"
  result.text = result.text[0 .. ^2]

proc write*(png: PngData, file: string) =
  discard savePNG32[seq[byte]](file, png.pixels, png.width, png.height)

proc write*(pixmap: PixMap, outMap: string, outPalette: string) =
  let palette = pixmap.palette.join("\n")
  writeFile(outMap, pixmap.text)
  writeFile(outPalette, palette)

#########################################################################################

let USAGE* = """$1 v$2 - $3
(c) 2023 $4

Usage:
  pixmap <source.pixmap> <palette.pixpal> [<options>] Transforms <source.pixmap> into a PNG image 
                          using <palette.pixpal> as color palette definition.
  pixmap <source.png> <palette.pixpal> [<options>] Transforms <source.png> into a pixel map 
                          saving its color palette to <palette.pixpal>.

Options:
  --help,    -h            Displays this message.
  --output,  -o            Specifies the name of the output file (by default, it is named after
                           the source file).
  --magnify, -m            Magnifies target by the specified (integer) factor (default: 1). 
  --version, -v            Displays the version of the application.
""" % [pkgTitle, pkgVersion, pkgDescription, pkgAuthor]

proc error(code: int, msg: string) =
  stderr.writeLine("(!) " & msg)
  quit(code)

proc info(msg: string) =
  echo msg

when isMainModule:

  for kind, key, val in getopt():
    case kind:
      of cmdArgument:
        ARGS.add key 
      of cmdLongOption, cmdShortOption:
        case key:
          of "help", "h":
            echo USAGE
            quit(0)
          of "version", "v":
            echo pkgVersion
            quit(0)
          of "output", "o":
            OPT_OUTPUT = val
          of "magnify", "m":
            try:
              OPT_MAGNIFICATION = val.parseInt
            except CatchableError:
              error(10, "Invalid magnification factor")
          else:
            discard
      else:
        discard
  
  if ARGS.len == 0:
    error(1, "No argument specified.")
  if ARGS.len == 1:
    error(2, "Palette file not specified.")
  if ARGS.len > 2:
    error(3, "Too many argyuments.")
  
  let SOURCE = ARGS[0].absolutePath
  let PALETTE = ARGS[1].absolutePath

  if not SOURCE.fileExists:
    error(4, "Source file '$#' does not exist." % [SOURCE])

  if SOURCE.endsWith(".png") or SOURCE.endsWith(".PNG"):
    TARGET = "pixmap"
  else:
    TARGET = "png"

  if OPT_OUTPUT == "":
    OPT_OUTPUT = Path(SOURCE).changeFileExt(TARGET).string

  info("Generating: $#" % [OPT_OUTPUT])
  if TARGET == "pixmap":
    pixmap(SOURCE).write(OPT_OUTPUT, PALETTE)
  elif TARGET == "png":
    if not PALETTE.fileExists:
      error(5, "Palette file '$#' does not exist." % [PALETTE])
    png(SOURCE, PALETTE).write(OPT_OUTPUT)
