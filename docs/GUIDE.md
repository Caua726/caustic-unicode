# Guide

Task-oriented recipes. Every snippet here is exercised by a runnable program in
[`examples/`](../examples); the full signature list is in [API.md](API.md).

## Two idioms you'll see everywhere

**Text is a run of code points.** The library works on `*i32` code points, not
bytes. You decode bytes in at the start and encode them out at the end:

```caustic
use "caustic-unicode/src/utf/utf8.cst" as utf8;
use "caustic-unicode/src/core/buf.cst" as buf;

let is buf.CpBuf as cps = buf.cpbuf_new(64);
utf8.to_cps("héllo", 6, &cps);        // bytes -> cps.ptr[0..cps.len]
// ... work on cps ...
let is buf.ByteBuf as bytes = buf.bytebuf_new(64);
utf8.from_cps(cps.ptr, cps.len, &bytes);   // cps -> UTF-8
```

**Output goes into a buffer you own.** Functions that produce text append to a
`CpBuf` (code points) or `ByteBuf` (bytes) and return the count, or
`0 - UERR_*` on failure. Reuse a buffer across calls with `cpbuf_reset`. Many
operations also offer a `_u8` variant that takes and returns UTF-8 directly.

---

## Normalize text

Two strings can look identical but differ byte-for-byte — `é` as one code point
versus `e` + a combining accent. Normalize to **NFC** before storing or
comparing:

```caustic
use "caustic-unicode/src/normalize/normalize.cst" as nz;

let is buf.CpBuf as out = buf.cpbuf_new(64);
nz.nfc(cps.ptr, cps.len, &out);       // canonical composed form
// nfd / nfkc / nfkd are the same shape; nfc_u8 etc. take/return UTF-8.
// is_nfc(cps, n) returns 1 if the run is already NFC (cheap quick-check).
```

Use NFC for almost everything; NFKC additionally folds compatibility variants
(e.g. ﬁ → fi, ① → 1) when you want aggressive matching.

## Compare strings case-insensitively

Don't lowercase and compare — that's wrong for ß, Greek sigma, and others. Use
full case folding:

```caustic
use "caustic-unicode/src/case/case.cst" as cs;

if (cs.eq_fold(a, an, b, bn) == 1) { /* equal ignoring case */ }
```

For actual case conversion with language rules, `to_lower` / `to_upper` /
`to_title` take a `locale` (`LOC_ROOT`, `LOC_TR`, `LOC_AZ`, `LOC_LT`) so Turkish
`I`/`İ` behave correctly.

## Count and iterate "characters"

A user-perceived character (a *grapheme cluster*) can be several code points —
a base plus accents, a flag, an emoji with skin tone. To count or walk them:

```caustic
use "caustic-unicode/src/segment/grapheme.cst" as seg;

let is i64 as n = seg.grapheme_count(cps.ptr, cps.len);   // 'e'+accent -> 1

let is seg.GraphemeIter as it = seg.grapheme_iter(cps.ptr, cps.len);
let is i64 as end with mut = seg.grapheme_next(&it);
while (end >= 0) {
    // the cluster is cps[prev_end .. end]
    end = seg.grapheme_next(&it);
}
```

`word_*` and `sentence_*` mirror this for word and sentence boundaries
(UAX #29).

## Measure display width

For terminals and fixed-width layout, a character can occupy 0, 1, or 2 columns
(CJK and many emoji are wide). `string_width` is grapheme-aware:

```caustic
use "caustic-unicode/src/width/width.cst" as width;

let is i64 as cols = width.string_width("hello 世界", 12);   // -> 10
```

## Wrap text at allowed break points

`linebreak` tells you where a line *may* or *must* break (UAX #14) — it does not
itself wrap, so you can combine it with `width` for your own budget:

```caustic
use "caustic-unicode/src/linebreak/linebreak.cst" as lb;

let is buf.ByteBuf as brk = buf.bytebuf_new(64);   // one byte per position
lb.line_break_fill(cps.ptr, cps.len, brk.ptr);
// brk[i] == LB_ALLOWED or LB_MANDATORY marks a break opportunity before cps[i].
```

## Sort strings sensibly

Code-point order puts `Z` before `a` and scatters accented letters. The Unicode
Collation Algorithm gives language-neutral order:

```caustic
use "caustic-unicode/src/collate/collate.cst" as collate;

let is i64 as c = collate.compare(a, an, b, bn, collate.VAR_NON_IGNORABLE);
// c is -1, 0, or 1 — plug it straight into a sort.
```

For sorting many strings, compute each key once with `sort_key` and compare the
keys.

## Lay out bidirectional text

For Arabic, Hebrew, or mixed text you need the bidi algorithm (UAX #9) to find
embedding levels and the visual order:

```caustic
use "caustic-unicode/src/bidi/bidi.cst" as bidi;

let is buf.ByteBuf as levels = buf.bytebuf_new(64);
let is i64 as para = bidi.resolve_levels(cps.ptr, cps.len, 2, levels.ptr);  // base 2 = auto
// para is the paragraph level (1 = RTL). Then:
let is buf.CpBuf as vis = buf.cpbuf_new(64);   // (via an i64 index array)
// bidi.reorder(levels.ptr, n, idx) gives the left-to-right visual index order;
// bidi.mirror(cp) returns the mirrored glyph for brackets in RTL runs.
```

## Domain names (IDNA / Punycode)

Convert a Unicode domain to the ASCII form DNS uses, and back:

```caustic
use "caustic-unicode/src/idna/uts46.cst" as idna;

let is buf.ByteBuf as a = buf.bytebuf_new(64);
let is i64 as err with mut = 0;
idna.to_ascii("münchen.de", 11, 0, &a, &err);     // -> "xn--mnchen-3ya.de"
idna.to_unicode("xn--mnchen-3ya.de", 17, 0, &a, &err);  // -> "münchen.de"
```

`err` is set to 1 if the input violates an IDNA rule (the output is still
produced best-effort). The `flags` argument toggles the UTS #46 checks
(`UTS46_CHECK_BIDI`, `UTS46_USE_STD3`, …) — pass `0` for the lenient default or
`UTS46_TRANSITIONAL` for the legacy mapping.

## Read legacy-encoded data

To bring Shift_JIS, GBK, Big5, EUC, or a Windows code page into Unicode:

```caustic
use "caustic-unicode/src/encodings/encodings.cst" as enc;

let is buf.CpBuf as out = buf.cpbuf_new(64);
enc.sjis_decode(bytes, n, &out);              // Shift_JIS -> code points

// single-byte code pages share one entry; pick the table with an ENC_* id:
use "caustic-unicode/src/ucd/tables/sbcs.cst" as sb;
enc.sb_decode(sb.ENC_WINDOWS_1252, bytes, n, &out);
```

Decoders substitute U+FFFD for bytes that don't map; the matching `*_encode`
functions return `0 - UERR_UNMAPPED` for a code point the target can't represent.

## Look up a character property

```caustic
use "caustic-unicode/src/ucd/props.cst" as props;

props.general_category('A')          // -> props.GC_LU
props.combining_class(0x0301)        // -> 230
props.east_asian_width(0x4E00)       // -> props.EAW_W
props.is_letter(cp) / is_digit(cp) / is_cased(cp)
```

All property getters are total — out-of-range input returns the property's
default, never an error.
