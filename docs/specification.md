# Specification

Every ID has a test tagged `# SPEC: <ID>`.

| ID | Statement |
|---|---|
| FBC-01 | A free-programming-books list line `* [title](url) - authors (formats) (licence)` becomes one source with its title, URL, authors, formats, stated licences, archived flag, the heading path above it and the list's language; lines that are not entries (index links, headings, prose) become nothing. |
| FBC-02 | A source's ID is FNV-1a 64 over the normalized URL (lower-case scheme and host, no fragment, no trailing slashes); normalization is idempotent; sources with one ID merge into one, keeping every listing, and merging is order-independent. |
| FBC-03 | Each Hillside catalog page yields its web links (id and title) and the start of the next page; each Hillside book category yields its book pages; a web link whose redirect is known is catalogued under its target URL. |
| FBC-04 | Only hillside web links and GitHub-hosted free-programming-books meta-lists are followed to depth 2; their links become depth-2 listings that name the list they came from, at most 2000 per list; every other meta-list is recorded in meta.json with the reason it was not followed. |
| FBC-05 | Every source has exactly one relevance under the consumer's rules: core when a heading of one of its listings or its title matches a keyword (short keywords only as whole words), hillside depth-1 entries core when the rules say so, listings in out-of-scope files out, otherwise adjacent; a hand decision in overrides.json wins. |
| FBC-06 | Building twice from the same inputs gives byte-identical meta.json, sources.jsonl and triage.json, whatever the order the inputs were read in; every line of sources.jsonl is valid UTF-8 JSON. |
| FBC-07 | No module under src/ imports a networking module; only tools/catalog_fetch.nim does. |
| FBC-08 | A source the consumer names in its config ("listed") is a depth-1 source of origin `listed` and is core, and states the licences the config gives it (none when it gives none). |
| FBC-09 | The consumer's config.json is read in full (user agent, cache location and its environment override, pinned commit, hillside switch, free-programming-books switch `fpb`, triage rules, listed sources with their licences); a missing required field is an error that names it. With `fpb` off, nothing is fetched from or read out of free-programming-books, and the pinned commit is not checked. |
