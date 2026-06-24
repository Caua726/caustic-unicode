# caustic-unicode

**A Unicode and internationalization library for [Caustic](https://github.com/Caua726/Caustic).**

Pure Caustic, no dependencies, Unicode **16.0**. It covers the parts of text
handling that are easy to get wrong: normalization, case, segmentation, line
breaking, bidirectional reordering, collation, IDNA, and the legacy character
encodings you still meet on the web. Every algorithm is checked against
Unicode's own conformance test files — about **580,000 lines** of them.

```caustic
use "caustic-unicode/src/width/width.cst" as width;
use "caustic-unicode/src/idna/uts46.cst"  as idna;
use "caustic-unicode/src/core/buf.cst"    as buf;

fn main() as i32 {
    // Terminal columns, not bytes or code points (CJK and wide emoji count as 2):
    let is i64 as cols = width.string_width("hello 世界", 12);     // -> 10

    // A Unicode domain in its on-the-wire ASCII (Punycode) form:
    let is buf.ByteBuf as ascii = buf.bytebuf_new(64);
    let is i64 as err with mut = 0;
    idna.to_ascii("münchen.de", 11, 0, &ascii, &err);            // -> "xn--mnchen-3ya.de"
    return 0;
}
```

## What's in it

| Module | What it does | Conformance |
| --- | --- | --- |
| `ucd` | Character properties (category, script, combining class, bidi class, East Asian width, break properties, …) | curated |
| `utf` | UTF-8 / UTF-16 / UTF-32 encode, decode, validate, convert | curated |
| `normalize` | NFC, NFD, NFKC, NFKD (+ quick-check) | `NormalizationTest` — all 20,026 lines |
| `case` | lower / upper / title / case-fold, with Turkish/Azeri/Lithuanian tailoring | curated |
| `segment` | grapheme cluster, word, and sentence boundaries (UAX #29) | `Grapheme`/`Word`/`Sentence` `BreakTest` — all lines |
| `linebreak` | line break opportunities (UAX #14) | `LineBreakTest` — all 16,700 lines |
| `bidi` | the bidirectional algorithm — levels, isolates, brackets, reordering (UAX #9) | `BidiCharacterTest` — all 96,464 lines |
| `collate` | language-neutral sorting via the Unicode Collation Algorithm (DUCET) | `CollationTest` — all 434,165 lines |
| `idna` | domain names: UTS #46 to-ASCII / to-Unicode and Punycode (RFC 3492) | `IdnaTestV2` — all 6,506 lines |
| `width` | display width of a string, grapheme-cluster aware | curated |
| `encodings` | WHATWG legacy codecs — windows-125x, ISO-8859-\*, Shift_JIS, EUC-JP/KR, Big5, GB18030, … | curated + round-trip |

The umbrella module `src/caustic_unicode.cst` re-exports all of these, so you can
`use` the whole library at once or pull in a single module. A runnable tour is
in [`examples/demo.cst`](examples/demo.cst).

## How it works, briefly

The hard part of Unicode isn't the algorithms — those are well specified — it's
the **data**. An offline generator (`tools/gen.cst`, itself written in Caustic)
parses the Unicode Character Database and emits the lookup tables as `.cst`
source; a **two-level code-point trie** then resolves `code point → property` in
constant time at runtime. The generated tables live under `src/ucd/tables/` and
are committed, so consuming the library needs no network access and no
generator run. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the details.

## Using it

The internal currency is a **run of code points** (`*i32`); byte-oriented
wrappers sit at the edges. Functions that produce text take a growable output
buffer (`*CpBuf` / `*ByteBuf`) and return a count, or `0 - UERR_*` on error —
there are no generic `Result` types.

- **[docs/GUIDE.md](docs/GUIDE.md)** — task-oriented recipes ("how do I normalize / sort / wrap / transcode?").
- **[docs/API.md](docs/API.md)** — every public function, by module.
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — how the tables and generator work inside.

## Build & test

```bash
caustic -c src/caustic_unicode.cst                  # type-check the whole library
caustic tests/run.cst -o build/run && ./build/run   # build & run every test + conformance suite
```

`tests/run.cst` is the test runner — also written in Caustic. It compiles and
runs every unit test and conformance suite and exits non-zero if any fail. The
vectors in `tests/vectors/` are committed, so the suite runs offline.

## Regenerating the tables

You only need this to re-pin to a newer Unicode version; the tables are already
committed.

```bash
caustic tools/fetch.cst -o build/fetch && ./build/fetch   # download UCD/UCA/IDNA/WHATWG data into tools/ucd/ (gitignored)
caustic tools/gen.cst   -o build/gen   && ./build/gen     # rewrite src/ucd/tables/*.cst
```

(`tools/fetch.cst` drives `curl` through `std/process` — the Unicode/WHATWG
servers are HTTPS-only and the Caustic stdlib has no TLS.)

## Layout

```
src/        the library
  core/       errno, types, growable buffers
  ucd/        property lookups + the generated tables/
  utf/  width/  normalize/  case/  segment/
  linebreak/  bidi/  collate/  idna/  encodings/
  caustic_unicode.cst   umbrella facade
tools/      gen.cst (table generator) + fetch.cst (data downloader)
tests/      run.cst (test runner), test_*.cst, conformance/conf_*.cst, vectors/
docs/       ARCHITECTURE.md, API.md, GUIDE.md
examples/   demo.cst
```

Everything here is Caustic — the library, the table generator, the data
downloader, and the test runner. There are no shell scripts and no build steps
in another language; the only external tool is `curl`, which `fetch.cst` shells
out to because the data servers are HTTPS-only.

## Status

All twelve modules are complete and the full suite is green. Pinned to Unicode
16.0. Targets x86-64 (the tables assume little-endian).

## License

Code: MIT. The bundled Unicode data files are under the
[Unicode License](https://www.unicode.org/license.txt).
