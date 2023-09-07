import 
  std/sequtils,
  std/strutils,
  std/os,
  nimPNG

type
  ImageData = object
    pixels: seq[string]
    width: int
    height: int

type 
  PixMap = object
    width: int
    height: int
    pixels: seq[string]
    palette: seq[string]

proc readPng(file: string): ImageData =
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

proc png*(inMap: string, inPalette: string): PNGResult[seq[byte]] =
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
  result = encodePNG32(pixels, width, height)

proc pixmap*(file: string): PixMap =
  let image = readPng(file)
  result.pixels = newSeq[string](0)
  result.width = image.width
  result.height = image.height
  var count = 0
  for pixel in image.pixels:
    if not result.palette.contains(pixel) and pixel != "00000000":
      result.palette.add pixel
      count += 1
    if pixel == "00000000":
      result.pixels.add " "
    else:
      let index = result.palette.find(pixel)
      result.pixels.add index.toHex(1)

proc write*(png: PNG[seq[byte]], file: string) =
  savePNG32[seq[byte]](file, png.data, png.width, png.height)

proc write*(pixmap: PixMap, outMap: string, outPalette: string) =
  var map = ""
  let palette = pixmap.palette.join("\n")
  var c = 1
  for pixel in pixmap.pixels:
    map &= pixel
    if c mod pixmap.width == 0 and c != pixmap.pixels.len:
      map &= "\n"
    c += 1
  writeFile(outMap, map)
  writeFile(outPalette, palette)

when isMainModule:
  "example/test.png".pixmap.write("example/test.pxmap", "example/test.pxplt")
  png("example/test.pxmap", "example/test.pxplt").write("example/test.out.png")
