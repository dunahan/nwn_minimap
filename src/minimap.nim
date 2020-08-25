import os, tables, sequtils, strutils
import neverwinter/[erf, gff, key, resfile, resman]
import regex
import magickwand

type
  Tile = tuple
    id, orientation: int

proc readTileTable(tileset: string): Table[int, string] =
  var currentTileNr = 0
  for l in tileset.splitLines:
    if l.match(re"\[TILE\d+\]"):
      currentTileNr = l[5 .. ^2].parseInt
    elif l.startsWith("ImageMap2D="):
      result[currentTileNr] = l[11 .. ^1].toLowerAscii

proc generateMap(rm: ResMan, tiles: seq[Tile], width, height: int, tt: Table[int, string], tileset, filename: string) =
  var map = newWand()
  var row = newWand()
  for h in 0 ..< height:
    row.setFormat("TGA") # otherwise tga blobs can not be recognized
    for w in 0 ..< width:
      let t = tiles[h * width + w]
      if t.id in tt:
        let tgaName = tt[t.id]
        if tgaName.len > 0:
          let tgaResRef = newResRef(tgaName, "tga".getResType)
          if rm.contains(tgaResRef):
            let tga = rm.demand(tgaResRef).readAll
            try:
              row.readImageBlob(tga)
            except:
              echo "Error: " & filename & ": " & tileset & ": could not read tga: " & tgaName
              echo "The tga file might be empty if it is from the nwserver key/bif."
              row.readImage("canvas:red")
            row.rotateImage(t.orientation * 90)
          else:
            echo "Warning: " & filename & ": " & tileset & ": tga not found: " & tgaName
            row.readImage("canvas:red")
        else:
          echo "Warning: " & filename & ": " & tileset & ": No tga (ImageMap2D entry) found for tile: " & $t.id
          row.readImage("canvas:red")
      else:
        echo "Warning: " & filename & ": " & tileset & ": tile not found: " & $t.id
        row.readImage("canvas:red")
      if row.width < 16:
        row.resizeImage(16, 16)
    row.resetIterator
    row = row.appendImages
    map.addImage(row)
    row.clearWand
  map.resetIterator
  map = map.appendImages(true)
  try:
    map.writeImage(filename & ".tga")
    echo "File written: " & filename & ".tga"
  except:
    echo "Error: Could not write image: " & filename & ".tga"

proc main() =
  if paramCount() == 0:
    echo """As parameters please provide paths to files of type are, hak, mod or key.
Add nwn_base.key and your tilest haks or the output maps won't be complete (showing red tiles)."""

  let rm = newResMan()
  # load key/bif first, then mod, hak, single are files
  for p in commandLineParams().filterIt it.endsWith(".key"):
    let dir = p.splitFile.dir
    rm.add p.openFileStream.readKeyTable(label = p, proc (fn: string): Stream =
      joinPath(dir, fn.splitPath.tail).openFileStream
    )
  for p in commandLineParams().filterIt it.endsWith(".mod"):
    rm.add p.openFileStream.readErf(p)
  for p in commandLineParams().filterIt it.endsWith(".hak"):
    rm.add p.openFileStream.readErf(p)
  for p in commandLineParams().filterIt it.endsWith(".are"):
    rm.add newResFile(p)

  for c in rm.contents:
    if $c.resType == "are":
      let
        are = rm.demand(c).readAll.newStringStream.readGffRoot
        width = are["Width", GffInt].int
        height = are["Height", GffInt].int
        tileset = $are["Tileset", GffResRef]
        tilesetResRef = newResRef(tileset, "set".getResType)
      if not rm.contains(tilesetResRef):
        echo "Warning: " & $c & ": Tileset not found: " & tileset
        continue
      let tt = rm.demand(tilesetResRef).readAll.readTileTable
      let tiles = are["Tile_List", GffList]
        .mapIt (it.get("Tile_ID", GffInt).int, it.get("Tile_Orientation", GffInt).int)
      generateMap(rm, tiles, width, height, tt, tileset, c.resRef)

genesis()
main()
terminus()
