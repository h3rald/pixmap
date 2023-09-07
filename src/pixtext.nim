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

proc getImageData(file: string): ImageData =
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

proc pixmap(image: ImageData): PixMap =
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

proc writePixFiles(pixmap: PixMap, file: string) =
  var map = ""
  let palette = pixmap.palette.join("\n")
  let outMap = file
  let outPalette = file.changeFileExt("pxplt")
  var c = 1
  for pixel in pixmap.pixels:
    map &= pixel
    if c mod pixmap.width == 0 and c != pixmap.pixels.len:
      map &= "\n"
    c += 1
  writeFile(outMap, map)
  writeFile(outPalette, palette)

when isMainModule:
  let image = getImageData("example/test.png")
  writePixFiles(image.pixmap, "example/test.pxmap")
