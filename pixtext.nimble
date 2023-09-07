# Package

version       = "0.1.0"
author        = "Cevasco, Fabio"
description   = "A small utility to convert simple PNG images to textual pixel maps and vice-versa"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["pixtext"]


# Dependencies

requires "nim >= 2.0.0"
requires "nimPNG"
