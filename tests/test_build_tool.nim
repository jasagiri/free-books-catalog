## E tests for docs/specification.md FBC-10 through the tool: catalog_build with "commercialOnly".

import std/[os, osproc, strutils, unittest]

const root = currentSourcePath().parentDir.parentDir

proc config(licences: string): string =
  """{"userAgent": "x-catalog/0.1", "rawEnv": "FBC_TOOL_TEST_RAW", "rawDefault": "unused",
  "fpbCommit": "", "hillside": false, "fpb": false, "commercialOnly": true,
  "triage": {"sectionKeywords": [], "titleKeywords": [], "outFiles": []},
  "listed": [{"url": "https://ok.example/manual", "title": "Manual", "section": ["Manuals"], "licenses": ["MIT"]},
             {"url": "https://other.example/book", "title": "Book", "section": ["Books"]""" &
    licences & "}]}"

suite "FBC-10 catalog_build":
  let dir = getTempDir() / "fbc-build-tool-" & $getCurrentProcessId()
  removeDir(dir)
  createDir(dir / "raw")
  let tool = dir / "catalog_build"
  let built = execCmdEx("nim c --hints:off -o:" & quoteShell(tool) & " " &
    quoteShell(root / "tools" / "catalog_build.nim"))
  if built.exitCode != 0: echo built.output

  proc run(licences: string): tuple[output: string, exitCode: int] =
    removeFile(dir / "sources.jsonl")
    writeFile(dir / "config.json", config(licences))
    execCmdEx(quoteShell(tool) & " --config:" & quoteShell(dir / "config.json") & " --raw:" &
      quoteShell(dir / "raw"))

  # SPEC: FBC-10
  test "FBC-10 Given commercialOnly and a source under a non-commercial licence, when built, then it exits 1, names the source and writes nothing":
    check built.exitCode == 0
    let r = run(""", "licenses": ["CC-BY-NC-SA-4.0"]""")
    check r.exitCode == 1
    check "other.example/book" in r.output
    check "CC-BY-NC-SA-4.0" in r.output
    check not fileExists(dir / "sources.jsonl")

  # SPEC: FBC-10
  test "FBC-10 Given commercialOnly and a source stating no licence, when built, then it exits 1 and writes nothing":
    let r = run("")
    check r.exitCode == 1
    check "no licence" in r.output
    check not fileExists(dir / "sources.jsonl")

  # SPEC: FBC-10
  test "FBC-10 Given commercialOnly and every source under an allowed licence, when built, then it writes the catalog":
    let r = run(""", "licenses": ["CC-BY-4.0"]""")
    check r.exitCode == 0
    check fileExists(dir / "sources.jsonl")
    check readFile(dir / "sources.jsonl").strip.splitLines.len == 2
