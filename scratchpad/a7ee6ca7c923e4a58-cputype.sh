#!/bin/sh
# triple -> cpu_type, by asking config.gcc itself rather than by guessing from
# the triple's first component.  Those disagree: `stormy16' is the DIRECTORY
# and `xstormy16' the cpu_type, `nds32be-elf' is cpu_type `nds32',
# `mmix-knuth-mmixware' is `mmix', `x86_64-pc-linux-gnu' is `i386'.  A census
# keyed on the triple would mis-name at least four of the 47.
#
# config.gcc is a shell fragment, not a program: it is sourced with $target
# set, exactly as gcc/configure does it, and $cpu_type read back out.  A triple
# config.gcc REFUSES prints UNSUPPORTED by name -- which is a different finding
# from "no assembler" and must not be collapsed into it.
set -u
SRC=${SRC:?set SRC to a gcc srcdir}
LIST=${1:?triple list}
[ -s "$LIST" ] || { echo "FATAL: $LIST empty/missing"; exit 9; }
[ -f "$SRC/gcc/config.gcc" ] || { echo "FATAL: no $SRC/gcc/config.gcc"; exit 9; }

n=0
for t in $(grep -v '^#' "$LIST" | grep .); do
  canon=$(sh "$SRC/config.sub" "$t" 2>/dev/null)
  [ -n "$canon" ] || { printf '%-26s %-12s BAD-TRIPLE\n' "$t" "-"; continue; }
  ct=$(
    cd "$SRC/gcc" || exit
    target=$canon; target_cpu=${canon%%-*}
    cpu_type=; srcdir=.; enable_languages=c
    # config.gcc exits nonzero / calls `exit 1' on an unsupported target; the
    # subshell contains that.
    . ./config.gcc > /dev/null 2>&1
    echo "$cpu_type"
  )
  if [ -z "$ct" ]; then
    printf '%-26s %-12s UNSUPPORTED-BY-config.gcc\n' "$t" "-"
  else
    printf '%-26s %-12s %s\n' "$t" "$ct" "$canon"
    n=$((n+1))
  fi
done
echo "-- resolved $n"
