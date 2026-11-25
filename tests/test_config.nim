## E tests for docs/specification.md FBC-09 (the consumer's catalog/config.json) and FBC-14 (raw/ and
## its manifest).

import std/[os, strutils, tables, unittest]
import free_books_catalog/[build, model]
import ../tools/rawstore

const full = """{"userAgent": "x-catalog/0.1", "rawEnv": "FBC_TEST_RAW", "rawDefault": "~/.cache/x/raw",
  "fpbCommit": "0000000000000000000000000000000000000000", "hillside": false, "fpb": true, "commercialOnly": true,
  "triage": {"sectionKeywords": ["algorithm"], "titleKeywords": [], "outFiles": ["casts/"]},
  "listed": [{"url": "https://tool.example/manual", "title": "Manual", "section": ["Manuals"], "licenses": ["ISC"]}]}"""

suite "FBC-09 config":
  let dir = getTempDir() / "fbc-config"
  removeDir(dir)
  createDir(dir)

  # SPEC: FBC-09
  test "FBC-09 Given a complete config, when loaded, then every field is read and the raw dir follows the environment":
    writeFile(dir / "config.json", full)
    let c = loadConfig(dir / "config.json")
    check c.dir == dir
    check c.userAgent == "x-catalog/0.1"
    check not c.hillside
    check c.rules.sectionKeywords == @["algorithm"]
    check c.listed.len == 1
    check c.fpb
    check c.listed[0].licenses == @["ISC"]
    check c.commercialOnly
    delEnv("FBC_TEST_RAW")
    check c.rawDir == getHomeDir() / ".cache/x/raw"
    putEnv("FBC_TEST_RAW", dir / "raw")
    check c.rawDir == dir / "raw"

  # SPEC: FBC-09
  test "FBC-09 Given a config without userAgent, when loaded, then it is an error naming the field":
    writeFile(dir / "config.json", """{"rawEnv": "A", "rawDefault": "b", "fpbCommit": "c", "hillside": true, "triage": {}}""")
    expect ValueError:
      discard loadConfig(dir / "config.json") # the call is expected to raise; its value is irrelevant

  # SPEC: FBC-09
  test "FBC-09 Given a config without the fpb switch, when loaded, then it is an error naming the field":
    writeFile(dir / "config.json", full.replace(" \"fpb\": true,", ""))
    try:
      discard loadConfig(dir / "config.json") # the call is expected to raise; its value is irrelevant
      check false
    except ValueError as e:
      check "fpb" in e.msg

  # SPEC: FBC-09
  test "FBC-09 Given the fpb switch off and a listed source without licences, when loaded, then fpb is off and the licences are empty":
    writeFile(dir / "config.json", full.replace("\"fpb\": true", "\"fpb\": false").replace(", \"licenses\": [\"ISC\"]", ""))
    let c = loadConfig(dir / "config.json")
    check not c.fpb
    check c.listed[0].licenses.len == 0

  # SPEC: FBC-09
  test "FBC-09 Given a config without the commercialOnly switch, when loaded, then it is an error naming the field":
    writeFile(dir / "config.json", full.replace(" \"commercialOnly\": true,", ""))
    try:
      discard loadConfig(dir / "config.json") # the call is expected to raise; its value is irrelevant
      check false
    except ValueError as e:
      check "commercialOnly" in e.msg

  # SPEC: FBC-09
  test "FBC-09 Given triage rules with and without hillsideCore, when loaded, then it is read when present and false when absent":
    writeFile(dir / "config.json", full)
    check not loadConfig(dir / "config.json").rules.hillsideCore
    writeFile(dir / "config.json", full.replace("\"outFiles\": [\"casts/\"]", "\"outFiles\": [\"casts/\"], \"hillsideCore\": true"))
    check loadConfig(dir / "config.json").rules.hillsideCore

suite "FBC-14 raw/ and the manifest":
  let raw = getTempDir() / "fbc-raw-" & $getCurrentProcessId()
  removeDir(raw)
  createDir(raw)

  # SPEC: FBC-14
  test "FBC-14 Given a manifest with every field, when saved and loaded, then it reads back unchanged":
    var m = Manifest(fpbCommit: "c0ffee", fetchedAt: "2026-01-02T03:04:05Z")
    m.weblinks[7] = "http://c2.com/ppr/"
    m.weblinks[12] = "https://t.example/"
    m.reach["a"] = Reachability(status: rOk, code: 200)
    m.reach["b"] = Reachability(status: rRedirected, code: 301, final: "https://b.example/new")
    m.reach["c"] = Reachability(status: rUnchecked)
    m.expansions = @[("id1", "https://base.example/", true, "expand/id1.md"), ("id2", "https://b2.example/", false, "")]
    saveManifest(raw, m)
    let back = loadManifest(raw)
    check back.fpbCommit == m.fpbCommit
    check back.fetchedAt == m.fetchedAt
    check back.weblinks == m.weblinks
    check back.reach == m.reach
    check back.expansions == m.expansions

  # SPEC: FBC-14
  test "FBC-14 Given a raw/ with list files, other files, hillside pages and expansions, when read with both switches on, then only the stated files are read, in sorted order, and a failed expansion is skipped":
    for (path, text) in [("fpb/courses/c-en.md", "C"), ("fpb/books/a-en.md", "A"), ("fpb/README.md", "R"),
                         ("fpb/other/x.md", "X"), ("fpb/books/n.txt", "N"),
                         ("hillside/catalog-20.html", "P20"), ("hillside/catalog-0.html", "P0"),
                         ("hillside/books-design-patterns.html", "DP"), ("hillside/other.html", "O"),
                         ("expand/x.md", "[L](https://l.example)")]:
      createDir((raw / path).parentDir)
      writeFile(raw / path, text)
    saveManifest(raw, Manifest(fpbCommit: "c", fetchedAt: "t",
      expansions: @[("x", "https://x.example/", true, "expand/x.md"), ("y", "https://y.example/", false, "")]))
    let inputs = readInputs(raw, CatalogConfig(dir: raw, fpb: true, hillside: true))
    check inputs.fpbFiles == @[("books/a-en.md", "A"), ("courses/c-en.md", "C")]
    check inputs.catalogPages == @["P0", "P20"]
    check inputs.bookPages == @[("design-patterns", "DP")]
    check inputs.expansions == @[Expansion(listId: "x", base: "https://x.example/", markdown: true,
      body: "[L](https://l.example)")]
    let off = readInputs(raw, CatalogConfig(dir: raw, fpb: false, hillside: false))
    check off.fpbFiles.len == 0
    check off.catalogPages.len == 0
    check off.bookPages.len == 0

  # SPEC: FBC-14
  test "FBC-14 Given a manifest naming an expansion file that is missing, when read, then it is an error naming the file":
    saveManifest(raw, Manifest(fpbCommit: "c", fetchedAt: "t",
      expansions: @[("z", "https://z.example/", true, "expand/gone.md")]))
    try:
      discard readInputs(raw, CatalogConfig(dir: raw)) # the call is expected to raise; its value is irrelevant
      check false
    except IOError as e:
      check "expand/gone.md" in e.msg
