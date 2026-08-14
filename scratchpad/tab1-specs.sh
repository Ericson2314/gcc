#!/bin/sh
# The two target-specs probes this task needs: mips64 against its OWN real
# cross assembler, ia64 against the build machine's `as' as an explicit
# fallback.
#
# THE ia64 CONFIG'S ANSWERS ARE x86_64's AND ARE NOT TRUSTED FOR ANYTHING.
# There is no ia64 assembler anywhere in this nixpkgs (measured previously:
# zero of 27157 attributes).  What the fallback supplies is a well-formed
# config file, so that "cc1 refuses to start without -ftarget-config=" cannot
# be mistaken for a result about the back end.  The question asked here is
# only: does cc1 corrupt memory while compiling for this back end?  -- and the
# corruption is in the compiler, not in the assembler's capability list.
#
# usage: tab1-specs.sh <builddir> <toolroot>
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}; ROOT=${2:-/tmp/tools-a76e99}
case "$D" in
  */b-agent-ab1fcb485731b7a4d*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
HOSTBIN=$ROOT/x86_64-pc-linux-gnu
MIPSBIN=$ROOT/mips64-unknown-elf
[ -x "$MIPSBIN/as" ] || { echo "FATAL: no mips64 as at $MIPSBIN"; exit 9; }
[ -x "$HOSTBIN/as" ] || { echo "FATAL: no host as at $HOSTBIN"; exit 9; }
OUT=$D/tab1-specs; mkdir -p "$OUT"

sh "$S/eb-shell.sh" "cd $D && ASAN_OPTIONS=detect_leaks=0 \
   make configure-target-specs-mips64-unknown-elf \
   TOOLS_DIR_FOR_mips64-unknown-elf=$MIPSBIN" > "$OUT/mips64.out" 2>&1
echo "mips64 rc=$?"

sh "$S/eb-shell.sh" "cd $D && ASAN_OPTIONS=detect_leaks=0 \
   make configure-target-specs-ia64-unknown-elf \
   TOOLS_DIR_FOR_ia64-unknown-elf=$HOSTBIN \
   TARGET_SPECS_FLAGS_FOR_ia64-unknown-elf='--with-as=$HOSTBIN/as \
     --with-ld=$HOSTBIN/ld --with-nm=$HOSTBIN/nm \
     --with-objdump=$HOSTBIN/objdump --with-readelf=$HOSTBIN/readelf'" \
   > "$OUT/ia64.out" 2>&1
echo "ia64 rc=$?"

# CHECK THE ARTEFACT, NOT THE EXIT STATUS: a previous run of this machinery
# left specs-<target> truncated at 39 lines and every `test -s' guard passed.
for t in mips64-unknown-elf ia64-unknown-elf; do
  f=$(ls "$D"/lib/gcc/*/"$t"/specs-config 2>/dev/null | head -1)
  if [ -n "$f" ]; then
    echo "  $t: wc -l $(wc -l < "$f")  grep -c . $(grep -c . "$f")  md5 $(md5sum < "$f" | cut -c1-12)  $f"
  else
    echo "  $t: ABSENT -- no specs-config"
  fi
done
