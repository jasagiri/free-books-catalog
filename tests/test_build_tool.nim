## E tests for docs/specification.md FBC-10 (catalog_build with "commercialOnly") and FBC-13 (its options,
## exit codes and outputs), through the tool.

import std/[json, os, osproc, strutils, unittest]

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
    for f in ["meta.json", "sources.jsonl", "triage.json"]: removeFile(dir / f)
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
    check not fileExists(dir / "meta.json")
    check not fileExists(dir / "triage.json")

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

proc plainConfig(fpb: bool; commit: string): string =
  """{"userAgent": "x-catalog/0.1", "rawEnv": "FBC_TOOL_TEST_RAW", "rawDefault": "unused",
  "fpbCommit": """" & commit & """", "hillside": false, "fpb": """ & $fpb & """, "commercialOnly": false,
  "triage": {"sectionKeywords": [], "titleKeywords": [], "outFiles": []},
  "listed": [{"url": "https://ok.example/manual", "title": "Manual", "section": ["Manuals"]}]}"""

proc manifest(commit, fetchedAt: string): string =
  """{"fpbCommit": """" & commit & """", "fetchedAt": """" & fetchedAt & """"}"""

suite "FBC-13 catalog_build":
  let dir = getTempDir() / "fbc-build-cli-" & $getCurrentProcessId()
  removeDir(dir)
  createDir(dir)
  let tool = dir / "catalog_build"
  let built = execCmdEx("nim c --hints:off -o:" & quoteShell(tool) & " " &
    quoteShell(root / "tools" / "catalog_build.nim"))
  if built.exitCode != 0: echo built.output

  proc fresh(name: string): string =
    ## An empty directory for one test.
    result = dir / name
    removeDir(result)
    createDir(result)

  proc run(args: string): tuple[output: string, exitCode: int] =
    execCmdEx(quoteShell(tool) & " " & args)

  proc written(d: string): seq[string] =
    for f in ["meta.json", "sources.jsonl", "triage.json"]:
      if fileExists(d / f): result.add f

  # SPEC: FBC-13
  test "FBC-13 Given an unknown option or a stray argument, when run, then it exits 2 naming it":
    check built.exitCode == 0
    let a = run("--bogus:1")
    check a.exitCode == 2
    check "--bogus" in a.output
    let b = run("stray")
    check b.exitCode == 2
    check "stray" in b.output

  # SPEC: FBC-13
  test "FBC-13 Given fpb on and a raw/ without fpb/, when run, then it exits 1 and writes nothing":
    let d = fresh("nofpb")
    createDir(d / "raw")
    writeFile(d / "config.json", plainConfig(true, "aaa"))
    let r = run("--config:" & quoteShell(d / "config.json") & " --raw:" & quoteShell(d / "raw"))
    check r.exitCode == 1
    check "fpb" in r.output
    check written(d).len == 0

  # SPEC: FBC-13
  test "FBC-13 Given fpb on and a manifest commit that differs from the pin, when run, then it exits 1 naming both and writes nothing; with fpb off it builds":
    let d = fresh("commit")
    createDir(d / "raw" / "fpb")
    writeFile(d / "raw" / "manifest.json", manifest("bbb", "t"))
    writeFile(d / "config.json", plainConfig(true, "aaa"))
    let args = "--config:" & quoteShell(d / "config.json") & " --raw:" & quoteShell(d / "raw")
    let r = run(args)
    check r.exitCode == 1
    check "aaa" in r.output and "bbb" in r.output
    check written(d).len == 0
    writeFile(d / "config.json", plainConfig(false, "aaa"))
    check run(args).exitCode == 0
    check written(d) == @["meta.json", "sources.jsonl", "triage.json"]

  # SPEC: FBC-13
  test "FBC-13 Given the raw/ location from the environment and from --raw, when run, then --raw wins and without it the environment's raw/ is read":
    let d = fresh("rawloc")
    for (sub, stamp) in [("env", "from-env"), ("flag", "from-flag")]:
      createDir(d / sub)
      writeFile(d / sub / "manifest.json", manifest("", stamp))
    writeFile(d / "config.json", plainConfig(false, ""))
    putEnv("FBC_TOOL_TEST_RAW", d / "env")
    check run("--config:" & quoteShell(d / "config.json")).exitCode == 0
    check parseJson(readFile(d / "meta.json"))["fetchedAt"].getStr == "from-env"
    check run("--config:" & quoteShell(d / "config.json") & " --raw:" & quoteShell(d / "flag")).exitCode == 0
    check parseJson(readFile(d / "meta.json"))["fetchedAt"].getStr == "from-flag"
    delEnv("FBC_TOOL_TEST_RAW")

  # SPEC: FBC-13
  test "FBC-13 Given --out naming a directory that does not exist, when run, then it is created and holds the three outputs":
    let d = fresh("out")
    createDir(d / "raw")
    writeFile(d / "config.json", plainConfig(false, ""))
    let target = d / "made" / "here"
    let r = run("--config:" & quoteShell(d / "config.json") & " --raw:" & quoteShell(d / "raw") &
      " --out:" & quoteShell(target))
    check r.exitCode == 0
    check written(target) == @["meta.json", "sources.jsonl", "triage.json"]
    check written(d).len == 0
