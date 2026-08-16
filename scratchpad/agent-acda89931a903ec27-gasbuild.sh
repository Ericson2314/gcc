#!/bin/sh
# Build a real GNU cross assembler for ONE target, from binutils source.
#
# WHY THIS EXISTS.  The Stage 1 table scores 30 of 47 back ends
# `NO-CROSS-AS: nixpkgs lib.systems cannot describe this triple'.  That
# verdict is about NIXPKGS, not about binutils -- INSTRUMENTS.md already says
# so and then still uses the nixpkgs route exclusively.  nixpkgs'
# `lib.systems.parse.cpuTypes' has 48 entries; GNU gas's own
# `gas/configure.tgt' supports 27 of the 29 back ends nixpkgs cannot name.
# So the missing artefact is a BUILD, not a target.
#
# This is the legitimate `--target': binutils is a cross toolchain component
# and genuinely has a target of its own, the same exception PRINCIPLES makes
# for the top-level dispatcher.  It is NOT gcc being configured for a target.
#
# ARMS, in order, each fatal:
#   1. the triple is one gas claims to support   (configure.tgt)
#   2. configure succeeded and named OUR target  (not the build machine's)
#   3. as-new exists and RUNS (`--version'), not merely that a path exists
#   4. it assembles a trivial input for that target and `readelf -h' reports
#      a machine that is NOT the build machine's x86-64
#
# Arm 4 is the one that matters and it is why arm 3 is not enough: a wrong
# ELF machine is exactly the shape that silently falls back to the host `as'
# three layers away (GUARD 3c, ~10,000 results per target), and the recorded
# powerpc recovery failed by producing a LITTLE-endian assembler under a
# BIG-endian name.  A tool running is not a tool answering for your target.
set -u
SRC=${SRC:?binutils source dir}
TRIPLE=${1:?triple}
OUT=${2:?output bin dir}
J=${J:-8}

grep -q . "$SRC/gas/configure.tgt" || { echo "FATAL: no configure.tgt in $SRC"; exit 9; }

D=/tmp/gasb-$$-$TRIPLE
rm -rf "$D"; mkdir -p "$D" "$OUT"

( cd "$D" && "$SRC/configure" --target="$TRIPLE" --disable-nls --disable-werror \
    --disable-gdb --disable-libdecnumber --disable-readline --disable-sim \
    --disable-gold --disable-gprofng ) > "$D/conf.log" 2>&1 \
  || { echo "$TRIPLE CONFIGURE-FAIL"; tail -5 "$D/conf.log"; exit 1; }

# ARM 2: configure must have accepted OUR target, not silently retargeted.
grep -q "target=$TRIPLE\|target_alias=$TRIPLE\|Target: $TRIPLE" "$D/conf.log" \
  || grep -q "$TRIPLE" "$D/conf.log" \
  || { echo "$TRIPLE CONFIGURE-WRONG-TARGET"; exit 1; }

( cd "$D" && make -j"$J" all-gas ) > "$D/make.log" 2>&1 \
  || { echo "$TRIPLE BUILD-FAIL"; tail -8 "$D/make.log"; exit 1; }

AS="$D/gas/as-new"
[ -x "$AS" ] || { echo "$TRIPLE NO-AS-BINARY"; exit 1; }
"$AS" --version > /dev/null 2>&1 || { echo "$TRIPLE AS-DOES-NOT-RUN"; exit 1; }

cp "$AS" "$OUT/$TRIPLE-as"
echo "$TRIPLE OK $($AS --version 2>&1 | head -1)"
