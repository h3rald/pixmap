# Package

version       = "0.1.0"
author        = "Fabio Cevasco"
description   = "A small utility to convert simple PNG images to textual pixel maps and vice-versa"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["pixmap"]


# Dependencies

requires "nim >= 2.0.0"
requires "nimPNG"
