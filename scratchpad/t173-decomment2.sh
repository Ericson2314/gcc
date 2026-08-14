#!/bin/sh
# #173 -- the five three-line variants of the same rationale comment, which
# t173-decomment.sh's two-line pattern does not match.  Same ruling, same
# reason; the text is in scratchpad/T173-BASE-HEADER.md.
set -e
cd "$(dirname "$0")/.."
for f in gcc/config/arc/driver-arc.cc gcc/config/avr/driver-avr.cc \
	 gcc/config/loongarch/loongarch-def.cc \
	 gcc/config/loongarch/loongarch-opts.cc \
	 gcc/config/msp430/driver-msp430.cc; do
  [ -f "$f" ] || { echo "FATAL: no such file $f"; exit 9; }
  grep -q 'Compiled once per configured back end' "$f" \
    || { echo "FATAL: $f does not carry the comment"; exit 9; }
  awk '
    /^\/\* Compiled once per configured back end/ { skip = 1 }
    skip == 1 { if ($0 ~ /\*\/[ \t]*$/) skip = 0; next }
    { print }
  ' "$f" > "$f.t173" && mv "$f.t173" "$f"
done
echo "de-commented 5 file(s)"
