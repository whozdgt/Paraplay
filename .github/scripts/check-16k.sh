#!/usr/bin/env bash
# Checks that every 64-bit native library under a folder can load on phones with 16 KB memory pages
# (Google Play requires this for apps that target Android 15 or newer). Exits 1 if one can't.
# Usage: check-16k.sh <folder with the unzipped lib/ or base/lib/>
set -u
dir="$1"
readelf="$(ls "$ANDROID_NDK_ROOT"/toolchains/llvm/prebuilt/*/bin/llvm-readelf 2>/dev/null | head -1)"
[ -x "$readelf" ] || { echo "llvm-readelf not found in the NDK"; exit 1; }
bad=0; n=0
while IFS= read -r so; do
  n=$((n + 1))
  # the smallest alignment of the LOAD segments; 0x4000 (16 KB) or more is fine
  min=0
  for a in $("$readelf" -lW "$so" | awk '$1 == "LOAD" { print $NF }'); do
    v=$((a))                                   # "0x4000" -> 16384
    if [ "$min" -eq 0 ] || [ "$v" -lt "$min" ]; then min=$v; fi
  done
  if [ "$min" -lt 16384 ]; then
    printf '  UNALIGNED  %-40s (%d)\n' "$(basename "$so")" "$min"; bad=$((bad + 1))
  fi
done < <(find "$dir" -path '*arm64-v8a*' -name '*.so')
echo "16 KB page check: $n libraries, $bad not aligned"
[ "$n" -gt 0 ] || { echo "no libraries found"; exit 1; }
[ "$bad" -eq 0 ]
