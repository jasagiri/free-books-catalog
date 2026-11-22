# free-books-catalog

Builds a deterministic catalog of free programming sources for a repository that cites them: every
entry of [free-programming-books](https://github.com/EbookFoundation/free-programming-books) at a
pinned commit, optionally the [Hillside patterns catalog](https://hillside.net/patterns/patterns-catalog),
and any sources the repository lists itself (official manuals, for example), followed to depth 2
where a source is itself one page of links. Each source gets an ID, a relevance (core / adjacent /
out) under the repository's own keywords, and a reachability state.

The library (`src/free_books_catalog/`) is pure; the network is used only by `tools/catalog_fetch.nim`.
Same fetched pages, same bytes out (FBC-06). Policy and reasons: `docs/adr/ADR-FBC-0001-catalog-of-free-sources.md`.

## Using it from a repository

Put a `catalog/config.json` in the repository:

```json
{
  "userAgent": "my-knowledge-catalog/0.1 (catalog of free programming books; one request per host at a time)",
  "rawEnv": "MY_CATALOG_RAW",
  "rawDefault": "~/.cache/my-knowledge/raw",
  "fpbCommit": "<full 40-character SHA of free-programming-books>",
  "hillside": false,
  "fpb": true,
  "commercialOnly": false,
  "triage": {
    "sectionKeywords": ["bash", "shell", "unix"],
    "titleKeywords": ["command line"],
    "depth2TitleKeywords": [],
    "outFiles": ["casts/"],
    "hillsideCore": false
  },
  "listed": [
    {"url": "https://example.org/manual", "title": "Tool manual", "section": ["Manuals"],
     "licenses": ["MIT"]}
  ]
}
```

`"fpb": false` leaves free-programming-books out: the catalog then holds only the listed sources
(and Hillside, when on), for a consumer that must know the licence of every source it lists.
`licenses` is optional; it is copied into the source as stated. `"commercialOnly": true` makes
`catalog_build` refuse to write a catalog in which a source states no licence or one that is not on
`commercialLicenses` (`src/free_books_catalog/licences.nim`: licences that allow any use, commercial
included; non-commercial and no-derivatives licences are not on it).

Then, from the repository root:

```sh
nim c -d:ssl -d:release -o:bin/catalog_fetch ../free-books-catalog/tools/catalog_fetch.nim
nim c -d:release -o:bin/catalog_build ../free-books-catalog/tools/catalog_build.nim
bin/catalog_fetch fpb          # then: hillside (if enabled), expand, reach
bin/catalog_build              # catalog/meta.json, sources.jsonl, triage.json
```

`catalog/overrides.json` (`{"<source id>": "core" | "adjacent" | "out"}`) records hand decisions; they
win over the rules. The fetched pages stay in the cache directory, never in the repository.

If you publish a catalog built with this package, attribute free-programming-books (CC BY 4.0).

## Development

```sh
nim test     # FBC-01…FBC-11 (needs ../nim-propcheck)
nim tools
```
