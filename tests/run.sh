#!/usr/bin/env bash
# Build + run each caustic-unicode test, checking exit codes.
# A test passes iff its binary exits 0. Run from anywhere.
set -u
cd "$(dirname "$0")/.."
mkdir -p build
fail=0

run_case() {
    local name="$1" src="$2"
    printf '[build] %-16s ' "$name"
    if ! caustic "$src" -o "build/$name" > "build/$name.log" 2>&1; then
        echo "COMPILE FAIL"
        tail -8 "build/$name.log" | sed 's/^/    /'
        fail=1
        return
    fi
    "build/$name"
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "PASS"
    else
        echo "FAIL (exit $rc)"
        fail=1
    fi
}

# Also compile-check the whole library facade (no main needed).
printf '[check] %-16s ' "facade"
if caustic -c caustic_unicode.cst > build/facade.log 2>&1; then
    echo "OK"
else
    echo "COMPILE FAIL"; tail -8 build/facade.log | sed 's/^/    /'; fail=1
fi

run_case test_buf   tests/test_buf.cst
run_case test_ucd   tests/test_ucd.cst
run_case test_utf   tests/test_utf.cst
run_case test_width tests/test_width.cst

if [ "$fail" -eq 0 ]; then echo "all green"; else echo "FAILURES"; fi
exit $fail
