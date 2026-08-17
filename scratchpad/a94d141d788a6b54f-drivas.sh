#!/bin/sh
# a94d141d788a6b54f-drivas.sh -- ASSEMBLE THROUGH THE DRIVER, so the target's
# own ASM_SPEC is applied.
#
# THE DEFECT THIS EXISTS FOR.  `a76a331dcb554f700-corpus.sh' assembles by
# invoking `<triple>-as' directly with NO FLAGS.  For most targets that is
# right.  For any target whose ASM_SPEC carries something the assembler needs
# in order to PARSE what the compiler emits, it manufactures a failure that
# belongs to the harness and reads as a compiler defect.  Measured:
#
#   bpf, corpus as-invoked-directly     1 of 7
#   bpf, same .s, as -mdialect=pseudoc  7 of 7
#
# `config/bpf/bpf.h:28' passes `-mdialect=pseudoc' by default, that line is
# present and correct in bpf's per-target `specs' file, and the driver applies
# it.  The board figure "bpf assembles 1 of 7" was therefore never a statement
# about the compiler.
#
# HOW: put a symlink named plainly `as' in a directory and hand it to the
# driver with `-B'.  The driver then runs THAT assembler with the ASM_SPEC for
# the selected target -- which is the path a real user takes, so this arm tests
# the specs plumbing as well as the assembly.  A symlink, never a COPY: the
# cross assemblers link against libopcodes/libbfd in their own nix store
# output, and copying them out is what left 8 of a previous board's 45
# assemblers unable to execute at all.
#
# usage: B=<builddir> AS=<path to cross as> drivas.sh <triple> <file.c>...
set -u
B=${B:?set B to the build dir}
AS=${AS:?set AS to the cross assembler}
T=${1:?triple}
shift
[ $# -ge 1 ] || { echo "FATAL: name at least one input"; exit 9; }

"$AS" --version >/dev/null 2>&1 \
  || { echo "FATAL: $AS does not EXECUTE -- a broken assembler and bad assembly give the same rc"; exit 9; }

V=$(ls "$B/lib/gcc" | head -1)
CFG="$B/lib/gcc/$V/$T/specs-config"
[ -f "$CFG" ] || { echo "FATAL: no specs-config for $T at $CFG"; exit 9; }

d=/tmp/drivas-$T
rm -rf "$d"; mkdir -p "$d"
ln -s "$AS" "$d/as"

n=0; ok=0
for f in "$@"; do
  n=$((n + 1))
  # THE -B ORDER IS LOAD-BEARING and getting it wrong is silent-ish: with
  # `-B$B/gcc/' first the driver found the HOST assembler out of PATH and said
  # `as: unrecognized option -EL', i.e. it reported a bpf flag as bad while
  # running an x86 assembler.  Our own directory goes FIRST.
  if "$B/gcc/xgcc" -B"$d/" -B"$B/gcc/" "-ftarget-config=$CFG" \
       ${OPT:--O2} -c -o "$d/$(basename "$f" .c).o" "$f" > "$d/$(basename "$f" .c).err" 2>&1; then
    ok=$((ok + 1))
    echo "OK   $(basename "$f")"
  else
    echo "BAD  $(basename "$f")   $(sed -n 2p "$d/$(basename "$f" .c).err")"
  fi
done
echo "drivas $T: $ok/$n  (through the driver, ASM_SPEC applied)"
[ "$n" -gt 0 ] || exit 9
