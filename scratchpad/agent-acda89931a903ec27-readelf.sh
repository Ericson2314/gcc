#!/bin/sh
# Supply `<triple>-readelf' for every target, from ONE readelf.
#
# `mtcheck.sh' GUARD 3c refuses by name without `$TDIR/$T-readelf'.  Building
# a full binutils per target to get it costs ~25 min each under tonight's
# load -- ~18 hours for 45 -- and it buys nothing, because READELF IS
# TARGET-AGNOSTIC BY CONSTRUCTION: BFD links every target's support into one
# binary and readelf reports the `e_machine' field the FILE carries.
#
# Measured, not assumed.  The x86_64-native readelf on a vax object built by
# the vax assembler:
#     Class: ELF32   Data: little endian   Machine: Digital VAX
#
# WHY THIS IS NOT THE "ONE NAME, SEVERAL AUTHORITIES" DEFECT.  That defect is
# one name meaning DIFFERENT THINGS to different consumers.  Here the name
# `<triple>-readelf' makes no per-target claim: readelf does not answer "what
# is this target", it reads what the object says.  The thing that MUST be per
# target is the ASSEMBLER, and that is genuinely per target -- 45 separate
# binaries, each verified by ARM 4.  (Incidental confirmation from tonight:
# the vax assembler rejects a PowerPC `mr 3,4' outright.)
#
# And ARM 4 itself needs no readelf at all -- it reads the ELF header with
# `od' -- so the per-assembler verification is independent of this file.
#
# The binary is COPIED, not symlinked.  Every symlink in the inherited tools
# dir is dangling because its store paths were GC'd, and a dangling
# `<triple>-as' is exactly what falls back to the host tool.
set -eu
OUT=${OUT:?tools bin dir}
SRC=${SRC:?path to a readelf binary}
LIST=${LIST:?triples}
[ -x "$SRC" ] || { echo "FATAL: $SRC is not executable"; exit 9; }
"$SRC" --version >/dev/null 2>&1 || { echo "FATAL: $SRC does not run"; exit 9; }
n=0
for t in $LIST; do
  cp "$SRC" "$OUT/$t-readelf"; n=$((n+1))
done
echo "readelf installed for $n targets"
