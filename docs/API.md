# API reference

Conventions used throughout:

- **Code points** are `i32`; a *run* is `(cps as *i32, n as i64)`.
- **Text output** is appended to a caller-owned growable buffer
  (`buf.CpBuf` for code points, `buf.ByteBuf` for bytes). These functions
  return the number of items appended, or `0 - UERR_*` on failure.
- **`_u8` variants** take/return UTF-8 bytes instead of code-point runs.
- Property getters are total: they return a default for out-of-range input,
  never an error.

Each module is a file under `src/`; import the ones you need, or import
`src/caustic_unicode.cst` for everything.

---

## core/errno.cst

Negative-errno constants (`with imut`): `UERR_INVALID`, `UERR_NOSPACE`,
`UERR_TRUNC`, `UERR_RANGE`, `UERR_OVERLONG`, `UERR_UNMAPPED`, `UERR_DISALLOWED`,
`UERR_PUNYCODE`, … and `U_REPLACEMENT` (U+FFFD).

```
fn is_err(ret as i64) as i64        // 1 if ret is a negative error code
fn err_name(ret as i64) as *u8
```

## core/buf.cst

```
fn cpbuf_new(cap as i64) as CpBuf            fn bytebuf_new(cap as i64) as ByteBuf
fn cpbuf_push(b as *CpBuf, cp as i32) as i64 fn bytebuf_push(b as *ByteBuf, byte as u8) as i64
fn cpbuf_append(b, src as *i32, n as i64)    fn bytebuf_append(b, src as *u8, n as i64)
fn cpbuf_reset(b as *CpBuf) as void          fn bytebuf_reset(b as *ByteBuf) as void
fn cpbuf_free(b as *CpBuf) as void           fn bytebuf_free(b as *ByteBuf) as void
```

Both structs expose `.ptr`, `.len`, `.cap`.

## ucd/props.cst

```
fn general_category(cp as i32) as i64   // GC_* constants
fn combining_class(cp as i32) as i64
fn script(cp as i32) as i64             // SC_* constants
fn east_asian_width(cp as i32) as i64   // EAW_* constants
fn line_break(cp as i32) as i64         // LB_* constants
fn grapheme_break(cp as i32) as i64     // GCB_* constants
fn word_break(cp as i32) as i64         // WB_*
fn sentence_break(cp as i32) as i64     // SB_*
fn bidi_class(cp as i32) as i64         // BIDI_* constants
fn is_letter(cp) / is_digit(cp) / is_cased(cp) / is_case_ignorable(cp) / is_soft_dotted(cp) as i64
```

## utf/utf8.cst, utf16.cst, utf32.cst

```
// utf8
fn decode1(src as *u8, n as i64, i as i64, out as *i32) as i64    // bytes consumed, or 0 - UERR_*
fn encode1(cp as i32, dst as *u8) as i64                          // bytes written (dst >= 4)
fn validate(src as *u8, n as i64) as i64
fn count(src as *u8, n as i64) as i64
fn cp_to_byte_index(src, n, cp_index as i64) as i64
fn byte_to_cp_index(src, n, byte_off as i64) as i64
fn to_cps(src as *u8, n as i64, out as *buf.CpBuf) as i64
fn from_cps(cps as *i32, n as i64, out as *buf.ByteBuf) as i64
fn iter(src as *u8, n as i64) as Utf8Iter   fn iter_next(it as *Utf8Iter) as i64

// utf16: decode1/encode1 (*u16), validate, to_cps, from_cps(...,out as *u16, cap)
// utf32: validate
```

## width/width.cst

```
fn cp_width(cp as i32) as i64                       // 0, 1, or 2
fn cp_width_amb(cp as i32, ambiguous_wide as i64) as i64
fn cp_run_width(cps as *i32, n as i64) as i64       // grapheme-cluster aware
fn string_width(src as *u8, n as i64) as i64        // UTF-8 in
```

## normalize/normalize.cst

```
fn nfd(cps, n, out as *buf.CpBuf) as i64     fn nfc(cps, n, out) as i64
fn nfkd(cps, n, out) as i64                  fn nfkc(cps, n, out) as i64
fn is_nfd(cps, n) as i64                     fn is_nfc(cps, n) as i64
fn nfd_u8 / nfc_u8 / nfkd_u8 / nfkc_u8(src as *u8, n, out as *buf.ByteBuf) as i64
```

## case/case.cst

```
fn to_lower_simple(cp) / to_upper_simple(cp) / to_title_simple(cp) / fold_simple(cp) as i32
fn to_lower(cps, n, locale as i64, out as *buf.CpBuf) as i64
fn to_upper(cps, n, locale, out) as i64      fn to_title(cps, n, locale, out) as i64
fn fold_full(cps, n, out as *buf.CpBuf) as i64
fn eq_fold(a, an, b, bn) as i64              // 1 if equal under full case folding
fn to_lower_u8 / to_upper_u8(src as *u8, n, locale, out as *buf.ByteBuf) as i64
```

`locale`: `LOC_ROOT`, `LOC_TR`, `LOC_AZ`, `LOC_LT`.

## segment/{grapheme,word,sentence}.cst

Same shape for each of grapheme / word / sentence:

```
fn grapheme_iter(cps, n) as GraphemeIter
fn grapheme_next(it as *GraphemeIter) as i64          // next boundary index, or 0 - UERR_* at end
fn grapheme_is_boundary(cps, n, i as i64) as i64
fn grapheme_count(cps, n) as i64
fn grapheme_boundaries(cps, n, out as *i64, cap as i64) as i64
```

(`word_*`, `sentence_*` mirror this; word/sentence omit `_boundaries`.)

## linebreak/linebreak.cst

```
fn line_break_at(cps, n, i as i64) as i64        // LB_PROHIBITED / LB_ALLOWED / LB_MANDATORY
fn line_break_fill(cps, n, brk as *u8) as i64    // fill brk[i] for every position at once
```

## bidi/bidi.cst

```
fn resolve_levels(cps, n, base as i64, lev as *u8) as i64   // returns paragraph level
fn reorder(lev as *u8, n as i64, vis as *i64) as i64        // visual order of the indices
fn mirror(cp as i32) as i32                                 // L4 mirrored glyph
```

`base`: `0` LTR, `1` RTL, `2` auto.

## collate/collate.cst

```
fn sort_key(cps, n, mode as i64, key as *buf.CpBuf) as i64
fn compare(a, an, b, bn, mode as i64) as i64               // -1 / 0 / 1
```

`mode`: `VAR_NON_IGNORABLE` or `VAR_SHIFTED` (variable-weighting).

## idna/punycode.cst, idna/uts46.cst

```
fn punycode_encode(cps, n, out as *buf.ByteBuf) as i64
fn punycode_decode(src as *u8, n, out as *buf.CpBuf) as i64

fn to_ascii(src as *u8, n, flags as i64, out as *buf.ByteBuf, err as *i64) as i64
fn to_unicode(src as *u8, n, flags as i64, out as *buf.ByteBuf, err as *i64) as i64
fn idna_status(cp as i32) as i64
```

`flags` is a bitmask: `UTS46_TRANSITIONAL`, `UTS46_USE_STD3`,
`UTS46_CHECK_HYPHENS`, `UTS46_CHECK_BIDI`, `UTS46_CHECK_JOINERS`. `*err` is set
to `1` if the input has any IDNA error; the output is still produced best-effort.

## encodings/encodings.cst

```
// single-byte (windows-125x, ISO-8859-*, KOI8, IBM866, macintosh, …)
fn sb_decode(enc as i32, src as *u8, n, out as *buf.CpBuf) as i64   // ENC_* selects the table
fn sb_encode(enc as i32, cps, n, out as *buf.ByteBuf) as i64

// multi-byte
fn big5_decode / euckr_decode / sjis_decode / gb18030_decode / eucjp_decode(src, n, out as *buf.CpBuf) as i64
fn big5_encode / euckr_encode / sjis_encode / gb18030_encode / eucjp_encode(cps, n, out as *buf.ByteBuf) as i64
```

Decoders map unmappable bytes to U+FFFD; encoders return `0 - UERR_UNMAPPED` for
a code point with no representation in the target encoding. `ENC_*` constants for
the single-byte codecs live in `src/ucd/tables/sbcs.cst`.
