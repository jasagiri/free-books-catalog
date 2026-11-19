# ADR-FBC-0001: One catalog builder for repositories that cite free sources

**ADR ID**: ADR-FBC-0001
**Status**: accepted
**Date**: 2026-11-19
**Author**: jasagiri (drafted by Claude Opus 5.5)

## Context

nim-cs-knowledge built a catalog of free programming books (free-programming-books and the
Hillside patterns catalog, followed to depth 2) to cite the sources of its concepts. A second
repository, modern-cli-knowledge, needs the same catalog with other keywords, without Hillside, and
with sources it names itself (the official manuals of command-line tools). Two copies of the
crawler would drift: a fix to URL normalization in one would not reach the other.

## Requirements

- One implementation of parsing, identifying, merging, classifying and fetching.
- No knowledge of any consumer in the package: keywords, start points, cache location and user
  agent come from the consumer.
- The consumer's output does not change when it moves from its own copy to this package (checked
  byte for byte for nim-cs-knowledge).
- Network only in one tool; everything else pure and deterministic.

## Options

1. **Keep a copy per consumer.** No coupling; every fix made twice.
2. **One package with the consumer's choices as constants passed by code.** Each consumer writes a
   small Nim program around the library. Flexible; each consumer now owns a build tool.
3. **One package with ready-made tools reading a consumer config file** (`catalog/config.json`).

## Trade-offs

Option 3 keeps consumers free of Nim code for the catalog: a JSON file decides keywords, start
points and politeness identity, and the outputs land next to it. The config must be complete (no
silent defaults), which costs a few lines per consumer and prevents two consumers sharing a cache
or user agent by accident.

## Decision

Option 3. Crawl policy, as nim-cs-knowledge's ADR-NCK-0001 first stated it:

- Depth 1: every list file of free-programming-books at the pinned commit; every page of the
  Hillside catalog and its eight book categories when the config enables Hillside; every source the
  config lists.
- Depth 2 only for lists that are one page of links: Hillside web links and GitHub-hosted
  free-programming-books meta-lists (their README). Other meta-lists are recorded with the reason.
- One request at a time per host with a delay, robots.txt honoured for "*", the consumer's user
  agent, every failure recorded as a state.
- Facts only (title, URL, section, stated licence, reachability). Consumers that publish must
  attribute free-programming-books (CC BY 4.0).

## Not decided here

- Start points other than free-programming-books, Hillside and a consumer's own list.

## Rejected alternatives

Options 1 and 2 above.
