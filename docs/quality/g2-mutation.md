# G2 mutation testing

Status: **measured for every module, every survivor classified; G2 does not pass yet.**
`nim-muter-ledger check docs/quality/survivors.json` fails while test_owed (47) and spec_question
(40) survivors remain.

Measured 2026-11-22 with nim-muter 0.2.18, mutators AOR ROR LOR BLR SDL RVR LBR CVR, one mutant at
a time, in a copy of the repository without VCS, with the tests of `fc3d7db5`.

| Module | Tests run per mutant | Mutants (compile errors left out) | Killed | Timeouts | Survived |
|---|---|---|---|---|---|
| `licences.nim` | `tests/test_catalog.nim` | 4 | 4 | 0 | 0 |
| `triage.nim` | same | 38 | 35 | 1 | 2 |
| `links.nim` | same | 98 | 58 | 2 | 38 |
| `hillside.nim` | same | 36 | 29 | 1 | 6 |
| `model.nim` | same | 72 | 66 | 2 | 4 |
| `fpb.nim` | same | 151 | 129 | 4 | 18 |
| `build.nim` | same | 73 | 34 | 0 | 39 |
| `tools/rawstore.nim` | `tests/test_config.nim`, `tests/test_build_tool.nim` | 30 | 8 | 0 | 22 |
| `tools/catalog_build.nim` | `tests/test_build_tool.nim` | 31 | 11 | 0 | 20 |

`tools/catalog_fetch.nim` is left out: it is the only module that uses the network (FBC-07).

The 149 survivors: 51 equivalent, 8 unreached, 3 accepted, 47 test_owed, 40 spec_question.

## What earlier rounds found

The first measurement (tests of `7c3d8d14`) left 63 survivors in links, 28 in model and 7 in
triage, and showed that no test checked the scanner's values, the FNV-1a constants, the UTF-8
repair or the sort orders. FBC-11 and new text in FBC-01/02/03/05/06 now state these, with E tests.
Triage of the survivors also found three defects, now fixed: `merge` depended on argument order
when two mentions tied, an en dash separator was cut one byte short, and ids of ten or more digits
were silently shortened.

## Left to do before G2 passes

- test_owed (47): tests for behaviour the spec already states. Four (FBC-01: `-ja.md`, a line of
  only `#`, `* [abc]`) are written and wait for the next measurement. Most of the rest concern what
  `build.nim` writes (`sources.jsonl`, `triage.json`, `meta.json`), the hillside and fpb inputs
  that `rawstore.nim` reads, and edge cases of `links.nim`.
- spec_question (40), each with a recommended answer in `survivors.json`. They group into:
  1. the keys of `sources.jsonl` (empty optional keys omitted; reach, httpCode, finalUrl);
  2. which free-programming-books files are lists (only `.md` under books/, courses/, more/, casts/);
  3. which expansion links are kept (http(s) with text);
  4. the `meta.json` counts, `depthLimit` and `maxLinksPerExpansion`;
  5. catalog_build's exit codes (usage error 2; incomplete raw/ and commit mismatch 1, nothing
     written) and `--out`;
  6. the default of `hillsideCore`;
  7. the manifest round trip and the raw/ layout (category from `books-<category>.html`, a
     missing expansion file).
- Then measure again and run `nim-muter-ledger check docs/quality/survivors.json` until it exits 0.
