# caustic-unicode

Biblioteca Unicode nível ICU, escrita em **Caustic puro**, zero-dependência.
Implementa **Unicode 16.0**.

Cobre: propriedades de caractere (UCD), UTF-8/16/32, normalização (NFC/NFD/NFKC/NFKD),
case (lower/upper/title/fold + tailoring), segmentação (grafema/palavra/sentença — UAX #29),
quebra de linha (UAX #14), bidi (UAX #9), collation (UCA), IDNA2008 + Punycode + UTS #46,
East Asian Width e os encodings legados do WHATWG Encoding Standard.

## Arquitetura

O coração é **dados, não algoritmos**. Um gerador offline (`tools/`, em Caustic) parseia o
Unicode Character Database e cospe tabelas `.cst`; um **trie de code point de 2 níveis** mapeia
`cp → propriedade` em O(1). As tabelas viram globais `*u8 with imut` (bytes em `\xNN`)
reinterpretados como `u16`/`u32` little-endian — a linguagem não tem array-literal.

```
core/   primitivos (errno, types, buf)
ucd/    trie + lookups de propriedade (tables/ é gerado)
utf/    utf8/16/32   width/  normalize/  case/  segment/
linebreak/  bidi/  collate/  idna/  encodings/
tools/  gerador de tabelas + fetch.sh
tests/  test_*.cst + conformance/ (vetores oficiais do Unicode)
```

## Build & teste

```bash
bash tools/fetch.sh                 # baixa o UCD 16.0 para tools/ucd/ (uma vez)
caustic tools/gen.cst -o build/gen && ./build/gen   # gera ucd/tables/*.cst
caustic -c caustic_unicode.cst      # compile-check da lib inteira
bash tests/run.sh                   # roda os testes (exit 0 = tudo verde)
```

## Uso

```cst
use "caustic-unicode/caustic_unicode.cst" as u;
// u.version()  ->  "16.0"
// u.buf.cpbuf_new(16);  ...
```
