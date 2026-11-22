# Development tasks (`nim <task>`).
#
#   nim test     every tests/test_*.nim
#   nim tools    bin/catalog_fetch (needs -d:ssl) and bin/catalog_build
#   nim specCoverage   G1 table → docs/quality/g1-spec-coverage.md (needs ../nim-spec-coverage)
#
# Consumers build the tools from this directory with their own output path, for example
#   nim c -d:release -o:bin/catalog_build ../free-books-catalog/tools/catalog_build.nim

import std/[algorithm, os, strutils]

task test, "all tests":
  var files: seq[string]
  for f in listFiles("tests"):
    let name = f.extractFilename
    if name.startsWith("test_") and name.endsWith(".nim"): files.add f
  files.sort()
  for t in files:
    echo "== " & t
    exec "nim c -r --hints:off " & t

task tools, "build the two tools into bin/":
  mkDir("bin")
  exec "nim c --hints:off -d:ssl -d:release -o:bin/catalog_fetch tools/catalog_fetch.nim"
  exec "nim c --hints:off -d:release -o:bin/catalog_build tools/catalog_build.nim"

task specCoverage, "G1 table":
  exec "../nim-spec-coverage/bin/tools/spec_coverage . --spec-table docs/specification.md" &
    " > docs/quality/g1-spec-coverage.md"
