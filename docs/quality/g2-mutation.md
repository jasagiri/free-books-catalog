# G2 mutation testing

Status: **passes.** `nim-muter-ledger check docs/quality/survivors.json` exits 0: every survivor
is classified, none test_owed or spec_question.

Measured 2026-11-24/25 with nim-muter 0.2.18, mutators AOR ROR LOR BLR SDL RVR LBR CVR, one mutant
at a time, in a copy of the repository without VCS. `links.nim` was measured with the tests of
`fd983443`; every other module with the tests of `7e52e2dd` (`fd983443` adds one check, to the
links tests only).

| Module | Tests run per mutant | Mutants (compile errors left out) | Killed | Timeouts | Survived |
|---|---|---|---|---|---|
| `licences.nim` | `tests/test_catalog.nim` | 4 | 4 | 0 | 0 |
| `triage.nim` | same | 38 | 35 | 1 | 2 |
| `links.nim` | same | 98 | 69 | 2 | 27 |
| `hillside.nim` | same | 36 | 29 | 1 | 6 |
| `model.nim` | same | 72 | 66 | 2 | 4 |
| `fpb.nim` | same | 151 | 133 | 4 | 14 |
| `build.nim` | same | 73 | 68 | 0 | 5 |
| `tools/rawstore.nim` | `tests/test_config.nim`, `tests/test_build_tool.nim` | 29 | 26 | 0 | 3 |
| `tools/catalog_build.nim` | `tests/test_build_tool.nim` | 31 | 30 | 0 | 1 |

`tools/catalog_fetch.nim` is left out: it is the only module that uses the network (FBC-07).

The 62 survivors: 50 equivalent, 9 unreached, 3 accepted. Each has its reason in `survivors.json`.

## What earlier rounds found

The first measurement (tests of `7c3d8d14`) left 63 survivors in links, 28 in model and 7 in
triage, and showed that no test checked the scanner's values, the FNV-1a constants, the UTF-8
repair or the sort orders. FBC-11 and new text in FBC-01/02/03/05/06 now state these, with E tests.
Triage of the survivors also found three defects, now fixed: `merge` depended on argument order
when two mentions tied, an en dash separator was cut one byte short, and ids of ten or more digits
were silently shortened.

The second measurement (tests of `fc3d7db5`) left 149 survivors, 47 test_owed and 40
spec_question. The questions were answered in FBC-12 (the outputs), FBC-13 (catalog_build's exit
codes and options), FBC-14 (the manifest and the raw/ layout) and new text in FBC-01, FBC-04 and
FBC-09, each with E tests. Writing FBC-14 found one defect, now fixed: an expansion named in the
manifest whose file was missing from raw/ was silently dropped; it is now an error.
