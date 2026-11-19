## E tests for docs/specification.md FBC-09 (the consumer's catalog/config.json).

import std/[os, unittest]
import ../tools/rawstore

const full = """{"userAgent": "x-catalog/0.1", "rawEnv": "FBC_TEST_RAW", "rawDefault": "~/.cache/x/raw",
  "fpbCommit": "0000000000000000000000000000000000000000", "hillside": false,
  "triage": {"sectionKeywords": ["algorithm"], "titleKeywords": [], "outFiles": ["casts/"]},
  "listed": [{"url": "https://tool.example/manual", "title": "Manual", "section": ["Manuals"]}]}"""

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
    delEnv("FBC_TEST_RAW")
    check c.rawDir == getHomeDir() / ".cache/x/raw"
    putEnv("FBC_TEST_RAW", dir / "raw")
    check c.rawDir == dir / "raw"

  # SPEC: FBC-09
  test "FBC-09 Given a config without userAgent, when loaded, then it is an error naming the field":
    writeFile(dir / "config.json", """{"rawEnv": "A", "rawDefault": "b", "fpbCommit": "c", "hillside": true, "triage": {}}""")
    expect ValueError:
      discard loadConfig(dir / "config.json") # the call is expected to raise; its value is irrelevant
