# Architecture

The guiding idea: **the algorithms are the easy part, the data is the work.**
The Unicode annexes (UAX #9, #14, #29, the UCA, UTS #46) are precise enough to
transcribe almost mechanically once you can answer "what are the properties of
this code point?" quickly. So most of the engineering here is in turning the
Unicode Character Database into fast, compact, committed lookup tables.

## The pipeline

```
unicode.org data  ──fetch.sh──▶  tools/ucd/ (gitignored)
                                      │
                                 tools/gen.cst  (the generator, in Caustic)
                                      │
                                      ▼
                         src/ucd/tables/*.cst  (committed)
                                      │
                                 runtime modules  ──▶  your program
```

`tools/fetch.sh` downloads the UCD, the UCA `allkeys.txt`, the IDNA mapping
table, and the WHATWG encoding indexes. `tools/gen.cst` parses them and writes
the tables as Caustic source. Because the tables are committed, a consumer never
runs the generator or touches the network — they just `use` the library.

## How a table is stored

Caustic has no array literals, so a table can't be written as `[N]u16 = {…}`.
Instead each table is emitted as a **string-initialized global** — a `*u8`
pointing at a blob of bytes in `.rodata` — and read back through accessors that
reinterpret the bytes as little-endian `u16`/`u32`:

```caustic
let is *u8 as gc_data_0 with imut = "\x09\x00\x09\x00...";   // generated
// gc_data_at(i) returns the i-th u16 out of the blob
```

Blobs are chunked (a single string literal can't be arbitrarily large) and the
accessor picks the right chunk. This keeps everything read-only and zero-init —
there's no runtime decode step, the bytes *are* the table.

## The two-level code-point trie

A property lookup is `code point → value`. A flat array over all 1,114,112 code
points would be huge and mostly empty, so properties use a **two-level trie**
(the classic UTrie shape):

```
block = INDEX[cp >> 5]                 // which 32-cp block
value = DATA[(block << 5) | (cp & 31)] // the property in that block
```

`SHIFT = 5` → 32 code points per block. The generator deduplicates identical
blocks (most of the code space is unassigned and shares one block), so `DATA`
collapses from megabytes to tens of kilobytes. Lookup is two memory reads and a
couple of shifts — constant time, branch-light.

## Variable-length payloads

Some properties aren't a single number — a decomposition, a full case mapping,
a special-casing entry, a collation element list. Those use a **meta + pool**
scheme: the trie maps a code point to an index into a `*_meta` array of packed
`{offset, length, flags}` records, and the records point into a flat `*_pool`
of `u32` values. Index 0 means "no entry". The same shape serves decomposition,
case folding, special casing, IDNA mapping, and DUCET collation elements.

## Runtime conventions

- **Code points are the currency.** Internally everything is a run of `*i32`
  code points; `-1` is a valid sentinel. Byte-oriented `_u8` wrappers sit at the
  public edge (decode in, encode out), mirroring ICU's `UChar` boundary.
- **No generic `Result`.** The toolchain doesn't reliably build generic
  enums, so fallible functions return a non-negative count or `0 - UERR_*`
  (negative errno), and text-producing functions append to a caller-owned
  growable buffer (`*CpBuf` / `*ByteBuf`). IDNA additionally reports problems
  through an `err` out-parameter because it always produces a best-effort result.
- **Buffers** (`core/buf.cst`) are `{ptr, len, cap}` with a module-local bump
  allocator, cloned from the sibling `caustic-net` project's `bytes.cst`.

## Module layering

```
core ─▶ ucd ─▶ utf ─▶ width
                  ├─▶ normalize ─▶ case
                  │                  └─▶ (collate, idna depend on normalize)
                  ├─▶ segment ─▶ linebreak
                  ├─▶ bidi
                  ├─▶ collate
                  ├─▶ idna (Punycode + UTS #46, uses normalize + ucd)
                  └─▶ encodings
```

Dependencies only point downward. `src/caustic_unicode.cst` is a thin facade
that `use`s every module so callers can pull in the whole library at once.

## Constraints worth knowing

- **Little-endian, x86-64.** The blobs are LE; a big-endian target would need
  byte-swapping accessors.
- **Pinned to one Unicode version (16.0).** Re-pinning = re-run `fetch.sh` +
  `gen.cst`. The generator embeds the version in each table header.
- **Encodings have no single UCD conformance file** (the WHATWG suite is
  separate and browser-shaped), so that module is verified with curated vectors
  and exhaustive round-trips rather than a `*.txt` driver.
