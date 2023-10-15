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
  Point* = object
    x: int
    y: int

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
var FROM: Point = Point(x: -1, y: -1)
var TO: Point = Point(x: -1, y: -1)

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

proc parsePoint(s: string): Point =
  let coords = s.split(",")
  result.x = coords[0].parseInt
  result.y = coords[1].parseInt

proc isNil(p: Point): bool =
  return p.x < 0 or p.y < 0

proc validate(pfrom, pto: Point) =
  if (pfrom.x > pto.x):
    raise newException(ValueError, "'to' point x value ($#) is lower than 'from' point x value ($#)" %
        [$pfrom.x, $pto.x])
  if (pfrom.y > pto.y):
    raise newException(ValueError, "'to' point y value is lower than 'from' point y value" %
        [$pfrom.y, $pto.y])

proc extract[T](matrix: seq[seq[T]], pfrom: Point, pto: Point): seq[seq[T]] =
  let width = pto.x - pfrom.x
  let height = pto.y - pfrom.y
  result = newSeq[seq[T]](height)
  var row = -1
  var col = 0
  var mx = -1
  var my = 0
  for line in matrix:
    row += 1
    col = 0
    if row+1 >= pfrom.y and row+1 <= pto.y:
      my += 1
      result[row] = newSeq[T](width)
      mx = 0
    for cell in line:
      if col+1 >= pfrom.x and col+1 <= pto.x:
        result[mx][my] = cell
        mx += 1

proc createPixMap(mapFile: string, palFile: string): PixMap =
  result.palette = palFile.readFile.split("\n")
  result.text = mapFile.readFile
  let lines = result.text.split("\n")
  result.width = lines[0].len
  result.height = lines.len
  result.matrix = newSeq[seq[string]](result.height)
  var row = -1
  var col = 0
  for line in lines:
    row += 1
    col = 0
    result.matrix[row] = newSeq[string](result.width)
    for c in line:
      result.matrix[row][col] = $c
      col += 1

# Magnifies pixmap (text only)
proc magnify(pixmap: var PixMap) =
  pixmap.text = ""
  for mr in countup(0, pixmap.height-1):
    for xr in countup(1, OPT_MAGNIFICATION):
      for mc in countup(0, pixmap.width-1):
        for xc in countup(1, OPT_MAGNIFICATION):
          pixmap.text &= pixmap.matrix[mr][mc]
      pixmap.text &= "\n"
  # Remove last "\n"
  pixmap.text = pixmap.text[0 .. ^2]

proc png*(inMap: string, inPalette: string): PngData =
  var pixmap = createPixMap(inMap, inPalette)
  pixmap.magnify()
  let lines = pixmap.text.split("\n")
  result.height = lines.len
  result.width = lines[0].len
  var pixels: seq[byte] = newSeq[byte]()
  for line in lines:
    for cell in line:
      var val = ""
      if cell == ' ':
        val = "00000000"
      else:
        let i: int = fromHex[int]($cell)
        try:
          val = pixmap.palette[i]
        except CatchableError:
          echo "Attempting to parse '$#'" % [$cell]
          echo getCurrentExceptionMsg()
      pixels.add val[0..1].parseHexInt.byte
      pixels.add val[2..3].parseHexInt.byte
      pixels.add val[4..5].parseHexInt.byte
      pixels.add val[6..7].parseHexInt.byte
  result.pixels = pixels

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
  result.magnify()

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
  --from, -f               Point (row,col) in the pixmap or png from where to start extraction.
  --to, -t                 Point (row,col) in the pixmap ot png where to start extraction.
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
          of "from", "f":
            try:
              FROM = val.parsePoint()
            except CatchableError:
              error(10, "Invalid 'from' point.")
          of "to", "t":
            try:
              TO = val.parsePoint()
            except CatchableError:
              error(10, "Invalid 'to' point.")
          of "version", "v":
            echo pkgVersion
            quit(0)
          of "output", "o":
            OPT_OUTPUT = val
          of "magnify", "m":
            try:
              OPT_MAGNIFICATION = val.parseInt
              echo "Magnification: $#x" % [val]
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

  if FROM.isNil and TO.isNil:
    error(5, "--from and --to must be specified together and point to valid positive coordinates.")

  if not FROM.isNil:
    try:
      validate(FROM, TO)
    except CatchableError:
      error(6, getCurrentExceptionMsg())

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
