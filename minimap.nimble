# Package
version       = "0.1.0"
author        = "Hendrik Albers"
description   = "nwn minimap generator"
license       = "MIT"
srcDir        = "src"
bin           = @["minimap"]

# Dependencies
requires "nim >= 1.2.6"
requires "neverwinter == 1.3.1"
requires "regex == 0.16.2"
requires "https://github.com/hendrikgit/nimtga#0.2.0"
