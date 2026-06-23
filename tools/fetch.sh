#!/usr/bin/env bash
# Download the Unicode Character Database inputs the table generator needs.
# Files land in tools/ucd/ (gitignored — reproducible via this script).
# Pinned to Unicode 16.0. Run once before tools/gen.cst.
set -euo pipefail
V=16.0.0
BASE="https://www.unicode.org/Public/${V}/ucd"
DEST="$(dirname "$0")/ucd"
mkdir -p "$DEST"

files=(
    UnicodeData.txt
    PropList.txt
    DerivedCoreProperties.txt
    Scripts.txt
    ScriptExtensions.txt
    EastAsianWidth.txt
    LineBreak.txt
    CaseFolding.txt
    SpecialCasing.txt
    DerivedNormalizationProps.txt
    CompositionExclusions.txt
    BidiMirroring.txt
    BidiBrackets.txt
    extracted/DerivedBidiClass.txt
    auxiliary/GraphemeBreakProperty.txt
    auxiliary/WordBreakProperty.txt
    auxiliary/SentenceBreakProperty.txt
    emoji/emoji-data.txt
)

echo "Fetching Unicode ${V} UCD into ${DEST}/ ..."
for f in "${files[@]}"; do
    out="${DEST}/$(basename "$f")"
    printf '  %-32s ' "$(basename "$f")"
    if curl -fsSL "${BASE}/${f}" -o "$out"; then
        echo "ok ($(wc -l < "$out") lines)"
    else
        echo "FAILED (${BASE}/${f})"
        exit 1
    fi
done
echo "done."
