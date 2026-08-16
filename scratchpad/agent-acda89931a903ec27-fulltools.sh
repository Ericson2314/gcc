#!/bin/sh
# Build the FULL per-target binutils (gas + binutils + ld), not just `as'.
#
# WHY A SECOND PASS EXISTS.  `agent-acda89931a903ec27-gasbuild.sh' builds
# `all-gas' only, which is all a `scan-assembler' test needs.  But
# `mtcheck.sh' GUARD 3c assembles a real function and then reads the machine
# back with `$TDIR/$T-readelf' -- and refuses by name if it is absent.  That
# guard is right and must not be relaxed: it is the arm that catches the host
# assembler, worth ~10,000 results per target.
#
# The tempting shortcut is to drop the host `readelf' in under a target name,
# since readelf reads every architecture.  That is exactly the "one name,
# several authorities" defect the guard exists to detect, so it is refused
# here: each target gets its own readelf or it does not get scored.
#
# Skips a target that already has BOTH `as' and `readelf', so it is
# re-runnable and does not redo finished work.
set -u
SRC=${SRC:?binutils source}
OUT=${OUT:?output bin dir}
J=${J:-2}
LIST=${LIST:?newline/space separated triples}
mkdir -p "$OUT"

nok=0; nfail=0; nskip=0
for t in $LIST; do
  if [ -x "$OUT/$t-as" ] && [ -x "$OUT/$t-readelf" ]; then
    echo "$t ALREADY-FULL"; nskip=$((nskip+1)); continue
  fi
  D=/tmp/ft-$t-$$
  rm -rf "$D"; mkdir -p "$D"
  if ! ( cd "$D" && "$SRC/configure" --target="$t" --disable-nls \
           --disable-werror --disable-gdb --disable-sim --disable-gold \
           --disable-gprofng --disable-readline --disable-libdecnumber \
         ) > "$D/conf.log" 2>&1; then
    echo "$t CONFIGURE-FAIL"; nfail=$((nfail+1)); rm -rf "$D"; continue
  fi
  if ! ( cd "$D" && make -j"$J" all-gas all-binutils all-ld ) \
         > "$D/make.log" 2>&1; then
    echo "$t BUILD-FAIL $(tail -3 "$D/make.log" | head -1)"
    nfail=$((nfail+1)); rm -rf "$D"; continue
  fi
  # copy under gcc's triple name
  [ -x "$D/gas/as-new" ]         && cp "$D/gas/as-new"        "$OUT/$t-as"
  [ -x "$D/ld/ld-new" ]          && cp "$D/ld/ld-new"         "$OUT/$t-ld"
  for u in readelf objdump nm ar ranlib strip objcopy size strings; do
    [ -x "$D/binutils/$u" ]      && cp "$D/binutils/$u"       "$OUT/$t-$u"
  done
  # `ar'/`ranlib'/`strip' are built under different names in some trees
  [ -x "$D/binutils/ar" ]        || { [ -x "$D/binutils/ar-new" ] && cp "$D/binutils/ar-new" "$OUT/$t-ar"; }
  if [ -x "$OUT/$t-as" ] && [ -x "$OUT/$t-readelf" ]; then
    echo "$t OK"; nok=$((nok+1))
  else
    echo "$t INCOMPLETE (as=$([ -x "$OUT/$t-as" ] && echo y || echo n) readelf=$([ -x "$OUT/$t-readelf" ] && echo y || echo n))"
    nfail=$((nfail+1))
  fi
  rm -rf "$D"
done
echo "=== full-tools OK=$nok FAIL=$nfail SKIP=$nskip"
echo "=== as=$(ls "$OUT" | grep -c -- '-as$') readelf=$(ls "$OUT" | grep -c -- '-readelf$')"
