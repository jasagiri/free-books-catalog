## Sorting the catalog into core / adjacent / out (FBC-05). The rules come from the consumer
## (TriageRules); hand decisions go in its catalog/overrides.json and win over the rules.

import std/[strutils, unicode]
import ./model

type Relevance* = enum
  core = "core" ## read for concepts (algorithms, data structures, patterns, functional programming)
  adjacent = "adjacent" ## kept in the catalog, not read in this round
  outOfScope = "out" ## screencasts, playgrounds, cheat sheets

type TriageRules* = object
  ## The consumer's notion of relevance (its catalog/config.json, "triage").
  sectionKeywords*: seq[string] ## matched against every heading of a listing's section path
  titleKeywords*: seq[string] ## matched against the title, for entries under a general heading
  depth2TitleKeywords*: seq[string] ## also matched against the title of depth-2 entries
  outFiles*: seq[string] ## list files (or parts of their path) that are out of scope
  hillsideCore*: bool ## hillside depth-1 entries are core (a patterns-minded consumer)

func hasWord(low, w: string): bool {.raises: [].} =
  ## `w` occurs in `low` starting at a word boundary; a keyword of four bytes or fewer ("nim",
  ## "lean", "elm") must also end at one, so "animation" and "clean code" do not match.
  ## Non-ASCII keywords match anywhere (CJK has no spaces between words).
  if not w.allCharsInSet({'\0'..'\x7f'}):
    return w in low
  var i = low.find(w)
  while i >= 0:
    let startOk = i == 0 or low[i - 1] notin Letters
    let stop = i + w.len
    let endOk = w.len > 4 or stop >= low.len or low[stop] notin Letters
    if startOk and endOk: return true
    i = low.find(w, i + 1)

func containsAny(s: string; words: openArray[string]): bool {.raises: [].} =
  let low = unicode.toLower(s)
  for w in words:
    if hasWord(low, w): return true

func isOutListing(l: Listing; rules: TriageRules): bool {.raises: [].} =
  if l.origin != oFpb: return false
  for f in rules.outFiles:
    if f in l.file: return true

func classify*(s: Source; rules: TriageRules): Relevance {.raises: [].} =
  ## The most relevant class any of the source's listings earns. A listing given by the consumer
  ## itself (origin listed) is core: the consumer chose it.
  result = outOfScope
  for l in s.listings:
    var r: Relevance
    if l.origin == oListed or (l.origin == oHillside and l.depth == 1 and rules.hillsideCore):
      r = core
    elif l.depth == 2:
      r = if containsAny(s.title, rules.titleKeywords) or containsAny(s.title, rules.depth2TitleKeywords): core
          else: adjacent
    elif isOutListing(l, rules):
      r = outOfScope
    else:
      var hit = containsAny(s.title, rules.titleKeywords)
      for h in l.section:
        if containsAny(h, rules.sectionKeywords): hit = true
      r = if hit: core else: adjacent
    if ord(r) < ord(result): result = r
