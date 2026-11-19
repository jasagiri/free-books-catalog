## catalog_build [--config:<catalog/config.json>] [--raw:<dir>] [--out:<dir>]
##
## raw/ → meta.json, sources.jsonl, triage.json next to the config (or in --out). No network, no clock:
## running it twice on the same raw/ gives the same bytes (FBC-06). Exit 0 on success, 1 when
## raw/ is incomplete, 2 on a usage error.

import std/[os, parseopt]
import free_books_catalog/build
import ./rawstore

proc main(): int =
  var configPath = "catalog" / "config.json"
  var raw = ""
  var outDir = ""
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "config": configPath = val
      of "raw": raw = val
      of "out": outDir = val
      else:
        stderr.writeLine "catalog_build: unknown option --" & key
        return 2
    of cmdArgument:
      stderr.writeLine "catalog_build: unexpected argument " & key
      return 2
    of cmdEnd: discard # getopt never yields cmdEnd inside the loop
  let config = loadConfig(configPath)
  if raw.len == 0: raw = config.rawDir
  if outDir.len == 0: outDir = config.dir
  if not dirExists(raw / "fpb"):
    stderr.writeLine "catalog_build: " & raw & "/fpb is missing; run catalog_fetch fpb first"
    return 1
  let inputs = readInputs(raw, config)
  if inputs.fpbCommit != config.fpbCommit:
    stderr.writeLine "catalog_build: " & raw & "/manifest.json has fpb commit '" & inputs.fpbCommit &
      "', the config pins '" & config.fpbCommit & "'; run catalog_fetch fpb"
    return 1
  let output = assemble(inputs)
  createDir(outDir)
  writeFile(outDir / "meta.json", output.metaJson)
  writeFile(outDir / "sources.jsonl", output.sourcesJsonl)
  writeFile(outDir / "triage.json", output.triageJson)
  echo "catalog_build: ", output.sources.len, " sources → ", outDir
  0

when isMainModule:
  quit main()
