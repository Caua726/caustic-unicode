#!/usr/bin/env bash
# Download every data file the table generator (tools/gen.cst) reads.
# Everything lands flat in tools/ucd/ (and tools/ucd/whatwg/), which is
# gitignored — the generated tables under src/ucd/tables/ are what's committed.
# Pinned to Unicode 16.0. Run once, then `caustic tools/gen.cst -o build/gen && ./build/gen`.
set -euo pipefail
V=16.0.0
DEST="$(dirname "$0")/ucd"
mkdir -p "$DEST" "$DEST/whatwg"

get() {  # get <url> <dest>
    printf '  %-34s ' "$(basename "$2")"
    if curl -fsSL "$1" -o "$2"; then echo "ok ($(wc -l < "$2") lines)"; else echo "FAILED ($1)"; exit 1; fi
}

UCD="https://www.unicode.org/Public/${V}/ucd"
echo "Unicode ${V} UCD ..."
for f in UnicodeData PropList DerivedCoreProperties Scripts EastAsianWidth \
         LineBreak CaseFolding SpecialCasing DerivedNormalizationProps \
         BidiMirroring BidiBrackets; do
    get "${UCD}/${f}.txt" "${DEST}/${f}.txt"
done
get "${UCD}/extracted/DerivedBidiClass.txt"   "${DEST}/DerivedBidiClass.txt"
get "${UCD}/extracted/DerivedJoiningType.txt" "${DEST}/DerivedJoiningType.txt"
get "${UCD}/auxiliary/GraphemeBreakProperty.txt" "${DEST}/GraphemeBreakProperty.txt"
get "${UCD}/auxiliary/WordBreakProperty.txt"     "${DEST}/WordBreakProperty.txt"
get "${UCD}/auxiliary/SentenceBreakProperty.txt" "${DEST}/SentenceBreakProperty.txt"
get "${UCD}/emoji/emoji-data.txt"                "${DEST}/emoji-data.txt"

echo "UCA ${V} (collation) ..."
get "https://www.unicode.org/Public/UCA/${V}/allkeys.txt" "${DEST}/allkeys.txt"

echo "IDNA ${V} ..."
get "https://www.unicode.org/Public/idna/${V}/IdnaMappingTable.txt" "${DEST}/IdnaMappingTable.txt"

echo "WHATWG Encoding Standard indexes ..."
WW="https://encoding.spec.whatwg.org"
for n in ibm866 iso-8859-2 iso-8859-3 iso-8859-4 iso-8859-5 iso-8859-6 iso-8859-7 \
         iso-8859-8 iso-8859-10 iso-8859-13 iso-8859-14 iso-8859-15 iso-8859-16 \
         koi8-r koi8-u macintosh windows-874 windows-1250 windows-1251 windows-1252 \
         windows-1253 windows-1254 windows-1255 windows-1256 windows-1257 windows-1258 \
         x-mac-cyrillic jis0208 jis0212 big5 euc-kr gb18030 gb18030-ranges; do
    get "${WW}/index-${n}.txt" "${DEST}/whatwg/index-${n}.txt"
done

echo "done."
