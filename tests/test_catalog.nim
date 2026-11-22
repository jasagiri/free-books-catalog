## E tests for docs/specification.md FBC-01…FBC-08, FBC-10 and FBC-11.

import std/[json, os, strutils, tables, unittest]
import propcheck
import free_books_catalog/[build, fpb, hillside, licences, links, model, triage]

const root = currentSourcePath().parentDir.parentDir

let rules = TriageRules(
  sectionKeywords: @["algorithm", "data structure", "haskell", "nim", "lean", "アルゴリズム"],
  titleKeywords: @["algorithm"], depth2TitleKeywords: @["pattern"],
  outFiles: @["casts/", "free-programming-playgrounds"], hillsideCore: true)

suite "NCK-C catalog":
  # SPEC: FBC-01
  test "FBC-01 Given a list line with authors, formats, licence and archive mark, when parsed, then every field is read":
    let line = "* [Purely Functional Things](https://example.org/pf.pdf) - A. Author, B. Author (PDF, EPUB) *( :card_file_box: archived)* (CC BY-SA)"
    let (ok, s) = parseEntry(line)
    check ok
    check s.title == "Purely Functional Things"
    check s.url == "https://example.org/pf.pdf"
    check s.authors == "A. Author, B. Author"
    check s.formats == @["PDF", "EPUB"]
    check s.licenses == @["CC BY-SA"]
    check s.archived

  # SPEC: FBC-01
  test "FBC-01 Given a list file, when parsed, then entries carry the heading path and language, and index links are not entries":
    let text = "## BY SUBJECT\n\n### Index\n\n* [Algorithms](#algorithms)\n\n### Algorithms\n\n" &
      "* [Book \\[2nd\\]](https://a.example/b_(x)) - Someone\n#### Graphs\n* [G](http://g.example)\n"
    let xs = parseList("books/free-programming-books-ja.md", text)
    check xs.len == 2
    check xs[0].title == "Book [2nd]"
    check xs[0].url == "https://a.example/b_(x)"
    check xs[0].lang == "ja"
    check xs[0].listings[0].section == @["BY SUBJECT", "Algorithms"]
    check xs[1].listings[0].section == @["BY SUBJECT", "Algorithms", "Graphs"]
    check langOfFile("free-programming-books-subjects.md") == "en"
    check langOfFile("free-courses-pt_BR.md") == "pt_BR"

  # SPEC: FBC-02
  test "FBC-02 Given URLs differing only in case of host, fragment or trailing slash, when identified, then they share one id":
    check sourceIdOf("https://Example.org/a/") == sourceIdOf("https://example.org/a#top")
    check sourceIdOf("http://example.org/a") != sourceIdOf("https://example.org/a")
    check ($sourceIdOf("https://example.org")).len == 16

  # SPEC: FBC-02
  test "FBC-02 Given any URL, when normalized twice, then the result equals normalizing once":
    let gen = stringOf("abcXYZ/#.:?=", 0, 20).map(proc(s: string): string = "https://Host.Example/" & s)
    let outcome = check(gen, proc(u: string): bool {.raises: [CatchableError].} =
      normalizeUrl(normalizeUrl(u)) == normalizeUrl(u))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: FBC-02
  test "FBC-02 Given two listings of one URL, when merged in either order, then the result is the same and keeps both":
    let a = parseList("books/x-en.md", "### A\n* [T1](https://e.org/x)\n")[0]
    let b = parseList("courses/y-en.md", "### B\n* [T2](https://e.org/x/) (PDF)\n")[0]
    let ab = dedupe([a, b])
    let ba = dedupe([b, a])
    check ab.len == 1
    check ab == ba
    check ab[0].listings.len == 2
    check ab[0].title == "T1" # from the earlier listing, books/ before courses/
    check ab[0].formats == @["PDF"]
    check dedupe(ab) == ab

  # SPEC: FBC-02
  test "FBC-02 Given known strings, when identified, then the id is FNV-1a 64 in lower-case hex; strings without scheme or host are only trimmed":
    check $sourceIdOf("a") == "af63dc4c8601ec8c"
    check $sourceIdOf("foobar") == "85944171f73967e8"
    check $sourceIdOf("https://Example.org/a/") == "4130e41a1ced2904"
    check normalizeUrl("  not a url  ") == "not a url"
    check normalizeUrl("urn:isbn:123/") == "urn:isbn:123/"
    check normalizeUrl("//Host.example/a/") == "//Host.example/a/"

  # SPEC: FBC-02
  test "FBC-02 Given two mentions with different formats, archive marks and one without listings, when merged, then formats are united and sorted, archived wins and the title comes from the listed one":
    let l = Listing(origin: oFpb, file: "books/a.md", section: @["S"], depth: 1)
    let a = Source(id: sourceIdOf("https://m.example"), title: "A", formats: @["PDF"], archived: true, listings: @[l])
    let b = Source(id: a.id, title: "B", formats: @["EPUB"])
    for m in [merge(a, b), merge(b, a)]:
      check m.formats == @["EPUB", "PDF"]
      check m.archived
      check m.title == "A"
      check m.listings == @[l]

  # SPEC: FBC-02
  test "FBC-02 Given two mentions of one URL with the same first listing but different titles and URL spellings, when merged or deduplicated in either order, then the result is the same":
    let l = Listing(origin: oFpb, file: "books/a.md", section: @["S"], depth: 1)
    let a = Source(id: sourceIdOf("https://t.example/x"), url: "https://t.example/x", title: "Alpha", authors: "P", listings: @[l])
    let b = Source(id: a.id, url: "https://T.example/x/", title: "Beta", authors: "Q", listings: @[l])
    check merge(a, b) == merge(b, a)
    check dedupe([a, b]) == dedupe([b, a])
    let c = Source(id: a.id, url: a.url, title: "Gamma")
    let d = Source(id: a.id, url: a.url, title: "Delta")
    check merge(c, d) == merge(d, c)

  # SPEC: FBC-03
  test "FBC-03 Given a catalog page, when parsed, then web links and the next page are found":
    let html = """<li><a href="/patterns/patterns-catalog?task=weblink.go&amp;id=7" class="category">Portland Pattern Repository</a></li>
      <li><a href="/patterns/patterns-catalog?task=weblink.go&amp;id=12">System Reengineering Patterns</a></li>
      <a href="/patterns/patterns-catalog?start=20">Next</a>"""
    let page = parseCatalogPage(html)
    check page.links.len == 2
    check page.links[0] == WebLink(linkId: 7, title: "Portland Pattern Repository")
    check page.nextStart == 20
    check parseCatalogPage("<p>last page</p>").nextStart == -1

  # SPEC: FBC-03
  test "FBC-03 Given a redirect target for a web link, when assembled, then the source has the target URL; a book category yields book pages":
    var inputs = BuildInputs(fpbCommit: "x", fetchedAt: "t", rules: rules)
    inputs.catalogPages = @["""<a href="/patterns/patterns-catalog?task=weblink.go&amp;id=7">PPR</a>"""]
    inputs.weblinkTargets[7] = "http://c2.com/ppr/index.html"
    inputs.bookPages = @[("design-patterns", """<td class="list-title"><a href="/patterns/books/design-patterns/277-service-design-patterns"> Service Design Patterns </a></td>""")]
    let o = assemble(inputs)
    check o.sources.len == 2
    var urls: seq[string]
    for s in o.sources: urls.add s.url
    check "http://c2.com/ppr/index.html" in urls
    check "https://hillside.net/patterns/books/design-patterns/277-service-design-patterns" in urls

  # SPEC: FBC-04
  test "FBC-04 Given meta-lists on GitHub and elsewhere, when checked, then only the GitHub one is followed and the other has a reason":
    let xs = parseList("books/free-programming-books-subjects.md",
      "### 0 - Meta-Lists\n* [L](https://github.com/o/r)\n* [S](https://www.site.example)\n### Algorithms\n* [B](https://github.com/o/b)\n")
    check expandable(xs[0])
    check not expandable(xs[1])
    check notFollowedReason(xs[1]).len > 0
    check not expandable(xs[2])
    check githubReadmeUrl("https://github.com/o/r") == "https://raw.githubusercontent.com/o/r/HEAD/README.md"

  # SPEC: FBC-04
  test "FBC-04 Given an expanded list, when assembled, then its links are depth-2 listings naming the list, capped per list":
    var inputs = BuildInputs(fpbCommit: "x", fetchedAt: "t", rules: rules)
    inputs.fpbFiles = @[("books/free-programming-books-subjects.md", "### 0 - Meta-Lists\n* [Pattern List](https://github.com/o/r)\n")]
    let listId = $sourceIdOf("https://github.com/o/r")
    var md = ""
    for i in 0 ..< MaxLinksPerExpansion + 10: md.add "* [Pattern " & $i & "](https://p.example/" & $i & ")\n"
    inputs.expansions = @[Expansion(listId: listId, base: "https://github.com/o/r", markdown: true, body: md)]
    let o = assemble(inputs)
    check o.sources.len == 1 + MaxLinksPerExpansion
    var depth2 = 0
    for s in o.sources:
      for l in s.listings:
        if l.depth == 2:
          inc depth2
          check l.via == listId
    check depth2 == MaxLinksPerExpansion

  # SPEC: FBC-05
  test "FBC-05 Given headings and titles, when classified, then keywords decide and short keywords match whole words only":
    let core1 = parseList("books/x-en.md", "### Algorithms & Data Structures\n* [Q](https://q.example)\n")[0]
    let nimS = parseList("books/x-en.md", "### Nim\n* [N](https://n.example)\n")[0]
    let anim = parseList("books/x-en.md", "### Animation\n* [A](https://a.example)\n")[0]
    let clean = parseList("books/x-en.md", "### Clean Code\n* [C](https://c.example)\n")[0]
    let ja = parseList("books/x-ja.md", "### アルゴリズム\n* [J](https://j.example)\n")[0]
    let screencast = parseList("casts/free-podcasts-screencasts-en.md", "### Algorithms\n* [P](https://p.example)\n")[0]
    check classify(core1, rules) == core
    check classify(nimS, rules) == core
    check classify(anim, rules) == adjacent
    check classify(clean, rules) == adjacent
    check classify(ja, rules) == core
    check classify(screencast, rules) == outOfScope

  # SPEC: FBC-05
  test "FBC-05 Given an override, when assembled, then the hand decision wins":
    var inputs = BuildInputs(fpbCommit: "x", fetchedAt: "t", rules: rules)
    inputs.fpbFiles = @[("books/x-en.md", "### Animation\n* [A](https://a.example)\n")]
    let id = $sourceIdOf("https://a.example")
    check assemble(inputs).relevance[id] == adjacent
    inputs.overrides[id] = core
    check assemble(inputs).relevance[id] == core

  # SPEC: FBC-06
  test "FBC-06 Given invalid UTF-8 bytes and unsorted listings, when cleaned and deduplicated, then each bad byte is U+FFFD and listings, formats and licences are in their stated order":
    check validUtf8("ok") == "ok"
    check validUtf8("a\xffb\xfe") == "a\u{FFFD}b\u{FFFD}"
    check validUtf8("\xffa") == "\u{FFFD}a"
    check validUtf8("caf\xc3\xa9") == "caf\xc3\xa9"
    let A = Listing(origin: oFpb, file: "a", section: @["x"], depth: 1)
    let B = Listing(origin: oFpb, file: "a", section: @["y"], depth: 1)
    let C = Listing(origin: oFpb, file: "b", section: @["a"], depth: 1)
    let D = Listing(origin: oHillside, file: "a", depth: 1)
    let E = Listing(origin: oFpb, file: "a", depth: 2, via: "1")
    let F = Listing(origin: oFpb, file: "a", depth: 2, via: "2")
    let s = Source(id: sourceIdOf("https://d.example"), formats: @["PDF", "EPUB"],
      licenses: @["MIT", "CC-BY-4.0"], listings: @[F, D, C, E, B, A])
    let d = dedupe([s])
    check d.len == 1
    check d[0].listings == @[A, B, C, D, E, F]
    check d[0].formats == @["EPUB", "PDF"]
    check d[0].licenses == @["CC-BY-4.0", "MIT"]

  # SPEC: FBC-06
  test "FBC-06 Given the same inputs in another order, when assembled twice, then the bytes are identical and every line is valid JSON":
    var a = BuildInputs(fpbCommit: "x", fetchedAt: "t", rules: rules)
    a.fpbFiles = @[("books/a-en.md", "### Algorithms\n* [A](https://a.example) (PDF)\n* [B](https://b.example)\n"),
                   ("courses/b-en.md", "### Haskell\n* [A again](https://a.example/)\n* [Bad \xFF title](https://c.example)\n")]
    var b = a
    b.fpbFiles = @[a.fpbFiles[1], a.fpbFiles[0]]
    let oa = assemble(a)
    let ob = assemble(b)
    check oa.sourcesJsonl == ob.sourcesJsonl
    check oa.metaJson == ob.metaJson
    check oa.triageJson == ob.triageJson
    check assemble(a).sourcesJsonl == oa.sourcesJsonl
    for line in oa.sourcesJsonl.strip.splitLines:
      check validUtf8(line) == line
      check parseJson(line).hasKey("id")

  # SPEC: FBC-07
  test "FBC-07 Given every module under src/, when its imports are read, then none is a networking module":
    for f in walkDirRec(root / "src"):
      if not f.endsWith(".nim"): continue
      for line in readFile(f).splitLines:
        let t = line.strip
        if t.startsWith("import ") or t.startsWith("from "):
          for banned in ["httpclient", "asynchttpserver", "net", "asyncnet", "nativesockets"]:
            check banned notin t.multiReplace(("[", " "), ("]", " "), (",", " ")).splitWhitespace

  # SPEC: FBC-08
  test "FBC-08 Given a source named by the consumer, when assembled, then it is a core depth-1 source of origin listed":
    var inputs = BuildInputs(fpbCommit: "x", fetchedAt: "t", rules: rules)
    inputs.listed = @[ListedSource(url: "https://tool.example/manual", title: "Tool manual", section: @["Manuals"])]
    let o = assemble(inputs)
    check o.sources.len == 1
    check o.sources[0].listings[0].origin == oListed
    check o.relevance[$o.sources[0].id] == core

  # SPEC: FBC-08
  test "FBC-08 Given a listed source with licences in the config, when assembled, then the source states them":
    var inputs = BuildInputs(fetchedAt: "t", rules: rules)
    inputs.listed = @[ListedSource(url: "https://tool.example/manual", title: "Tool manual",
      section: @["Manuals"], licenses: @["MIT", "GPL-2.0-or-later"])]
    let o = assemble(inputs)
    check o.sources[0].licenses == @["GPL-2.0-or-later", "MIT"]
    check "\"licenses\":[\"GPL-2.0-or-later\",\"MIT\"]" in o.sourcesJsonl
    inputs.listed[0].licenses = @[]
    check "licenses" notin assemble(inputs).sourcesJsonl

  # SPEC: FBC-10
  test "FBC-10 Given listed sources, when their licences are checked, then only a missing licence or one off the list is reported, naming the source and the licence":
    var inputs = BuildInputs(fetchedAt: "t", rules: rules)
    inputs.listed = @[
      ListedSource(url: "https://ok.example/a", title: "A", licenses: @["MIT", "CC-BY-SA-4.0"]),
      ListedSource(url: "https://ok.example/b", title: "B", licenses: @["GFDL-1.3-no-invariants-or-later"])]
    check licenceErrors(assemble(inputs).sources).len == 0
    inputs.listed.add ListedSource(url: "https://nc.example/c", title: "C", licenses: @["MIT", "CC-BY-NC-4.0"])
    inputs.listed.add ListedSource(url: "https://none.example/d", title: "D")
    let errs = licenceErrors(assemble(inputs).sources)
    check errs.len == 2
    var nc, none = false
    for e in errs:
      if "nc.example/c" in e and "CC-BY-NC-4.0" in e and "MIT" notin e: nc = true
      if "none.example/d" in e and "no licence" in e: none = true
    check nc and none
    for bad in ["CC-BY-ND-4.0", "CC-BY-NC-SA-4.0", "cc-by-4.0", ""]:
      inputs.listed = @[ListedSource(url: "https://x.example/e", title: "E", licenses: @[bad])]
      check licenceErrors(assemble(inputs).sources).len == 1

  # SPEC: FBC-05
  test "FBC-05 Given keywords inside a heading, at the four-byte limit and on depth-2 titles, when classified, then word boundaries and the depth-2 title keywords decide":
    proc fpbSource(title, heading: string): Source =
      Source(title: title, listings: @[Listing(origin: oFpb, depth: 1, file: "books/x-en.md", section: @[heading])])
    proc depth2(title: string): Source =
      Source(title: title, listings: @[Listing(origin: oFpb, depth: 2, file: "books/x-en.md")])
    check classify(fpbSource("Q", "Advanced Algorithms"), rules) == core
    check classify(fpbSource("Q", "Leaning Tower"), rules) == adjacent
    var r = rules
    r.sectionKeywords = @["graph"]
    check classify(fpbSource("Q", "Graphics"), r) == core
    check classify(depth2("Pattern Language"), rules) == core
    check classify(depth2("Algorithm Notes"), rules) == core
    check classify(depth2("Cooking"), rules) == adjacent

  # SPEC: FBC-05
  test "FBC-05 Given hillsideCore off, when a hillside entry is classified, then it is not core by origin alone":
    var r = rules
    r.hillsideCore = false
    let s = Source(title: "Something", listings: @[Listing(origin: oHillside, depth: 1)])
    check classify(s, r) == adjacent
    check classify(s, rules) == core

suite "FBC-11 links":
  # SPEC: FBC-11
  test "FBC-11 Given HTML anchors in several attribute forms, when scanned, then each non-empty href is resolved and its text cleaned, in page order":
    let html = """<abbr>no</abbr><A CLASS="c" HREF="/x?a=1&amp;b=2">  Hello <b>bold</b>&amp;  more </a>""" &
      """<a data-href="/wrong" href='rel/p'>R</a><a href=https://abs.example/q>Q</a>""" &
      """<a href=/u target=x>U</a><a href="">E</a><a name="n">N</a><a href="/broken>B</a>""" &
      """<a href="/last">L</a> trailing <a"""
    let xs = htmlAnchors(html, "https://h.example/dir/page")
    check xs == @[
      Anchor(href: "https://h.example/x?a=1&b=2", text: "Hello bold& more"),
      Anchor(href: "https://h.example/dir/rel/p", text: "R"),
      Anchor(href: "https://abs.example/q", text: "Q"),
      Anchor(href: "https://h.example/u", text: "U"),
      Anchor(href: "https://h.example/last", text: "L")]
    check htmlAnchors("""<a href="/z">no end""", "https://h.example/").len == 0
    check htmlAnchors("""<a href="/z" """, "https://h.example/").len == 0

  # SPEC: FBC-11
  test "FBC-11 Given Markdown links, when scanned, then one-line links with a URL are found in order, resolved, with the title dropped":
    let md = "[Zero](z) See [ Text one ](rel/a \"title\") and [Two](https://t.example/b).\n" &
      "[broken\nline](https://n.example) [Empty]() [Three](c) [open](never"
    check markdownAnchors(md, "https://m.example/d/") == @[
      Anchor(href: "https://m.example/d/z", text: "Zero"),
      Anchor(href: "https://m.example/d/rel/a", text: "Text one"),
      Anchor(href: "https://t.example/b", text: "Two"),
      Anchor(href: "https://m.example/d/c", text: "Three")]
    check markdownAnchors("[R](rel/p)", "") == @[Anchor(href: "rel/p", text: "R")]
    check markdownAnchors("no links [here", "https://m.example/").len == 0
