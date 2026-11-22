# G2 mutation testing

Status: **partly measured, survivors not yet classified.** This package does not pass G2 yet:
there is no `survivors.json`, and four modules have not been measured.

First measured 2026-11-22 with nim-muter 0.2.18, mutators AOR ROR LOR BLR SDL RVR LBR CVR, one
mutant at a time, in a copy of the repository without VCS (nim-muter then copies every file except
the built-in directory names).

## First measurement (tests as of `7c3d8d14`)

| Module | Tests run per mutant | Mutants (compile errors left out) | Killed | Timeouts | Survived |
|---|---|---|---|---|---|
| `licences.nim` | `tests/test_catalog.nim` | 4 | 4 | 0 | 0 |
| `triage.nim` | same | 38 | 30 | 1 | 7 |
| `links.nim` | same | 98 | 35 | 0 | 63 |
| `model.nim` | same | 65 | 35 | 2 | 28 |
| `hillside.nim` | same | not measured here: the run stopped when the disk filled (measured later, below) | | | |
| `fpb.nim` | same | not measured: stopped at 22 of 154 | | | |
| `build.nim` | same | not measured | | | |
| `tools/rawstore.nim` | `tests/test_config.nim`, `tests/test_build_tool.nim` | not measured | | | |
| `tools/catalog_build.nim` | `tests/test_build_tool.nim` | not measured | | | |

`tools/catalog_fetch.nim` is left out: it is the only module that uses the network (FBC-07).

## What the survivors showed, and what was added

- `links.nim`: no test checked the values the scanner returns. FBC-11 now states the scanner's
  contract (attribute forms, one-line Markdown links, resolution against the base, cleaned text,
  page order), and two E tests check it.
- `triage.nim`: keywords in the middle of a heading, the four-byte limit of whole-word keywords, and
  the depth-2 title keywords were unchecked. One FBC-05 test now covers them.
- `model.nim`: the FNV-1a constants, `validUtf8`, the scheme/host guard of `normalizeUrl`, `merge`
  (formats, archived, a side without listings) and the sort orders in `dedupe` were unchecked.
  FBC-02 and FBC-06 now state these parts, and three E tests check them with known values.

After the new tests, `links.nim` was measured again: 98 mutants (compile errors left out), 58 killed, 2 timeouts, 38
survived. For `triage.nim` (5 mutants) and `model.nim` (16 mutants), the targeted survivors were
applied by hand, and each one fails the new tests. Those two modules have not been measured again
with nim-muter.

`hillside.nim` was measured with the tests of `4bfcb235` (FBC-11 included): 35 mutants (compile
errors left out), 17 killed, 0 timeouts, 18 survived, none classified yet. Most move a boundary
when the catalog page is parsed (`start == 0`, `i - start < 9`, `at >= 0`), or change the
rule that keeps a book link only when its text is not empty and it is seen for the first time.

## Left to do before G2 passes

1. Classify the `hillside` survivors; measure `fpb`, `build`, `rawstore` and `catalog_build`, and measure `triage` and
   `model` again.
2. Load every report into `docs/quality/survivors.json` with `nim-muter-ledger sync`, classify each
   survivor, and run `nim-muter-ledger check docs/quality/survivors.json` until it exits 0.
3. (Done.) Two mentions of one URL with the same first listing but different titles used to
   merge to the title of the first argument, against FBC-06; `merge` now picks the mention by a
   total order (first listing, then URL spelling, title, authors, lang), and an FBC-02 test checks
   both argument orders.

Most of the 38 links survivors move a boundary of `find` (`< 0` to `<= 0`, `0` to `1`) where the
match cannot be at position 0, or change a slice end that the next step does not read. These look
equivalent, but none has been classified yet.
