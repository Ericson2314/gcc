#!/bin/sh
# #49 -- BOTH-SIDED verification of the mkconfig.sh prologue change.
#
# Regenerates tm-rs6000.h with the PATCHED mkconfig.sh, using the exact
# environment the 48-back-end build used (lifted from that build's own log,
# not reconstructed by hand), preprocesses the real chain, and reads back the
# three symbols the guards select.
#
# Both sides are required (PRINCIPLES section 4): showing rs6000 now gets
# rs6000's answer proves nothing unless i386 still gets i386's.  The i386 arm
# is the control and MUST be byte-identical -- tm-i386.h tests neither macro,
# so a change there would mean the prologue leaked into a base that never
# asked.
#
# usage: t49-verify.sh <builddir> <patched-gcc-srcdir>
set -eu
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
NEW=$(cd "${2:?patched gcc srcdir}" && pwd)
case "$B" in
  */b-ad1798a2b26398cc6*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
G="$B/gcc"
OLD=$(grep -m1 -o '/tmp/snap-[a-z0-9]*' "$B/config.log")/gcc
echo "old (immutable snapshot, as built): $OLD"
echo "new (patched worktree):             $NEW"
# The change must actually BE in the new tree -- "the generator ran" is not
# evidence the generator did anything (PRINCIPLES section 4).
grep -q 'HAVE_LD_LARGE_TOC' "$NEW/mkconfig.sh" \
  || { echo "FATAL: $NEW/mkconfig.sh does not mention HAVE_LD_LARGE_TOC; nothing to verify"; exit 9; }
grep -q 'HAVE_LD_LARGE_TOC' "$OLD/mkconfig.sh" \
  && { echo "FATAL: the OLD tree already has it; the two sides are not distinct"; exit 9; }
echo "arm 0 ok: the patch is present in NEW and absent from OLD"
echo

W=$B/t49-verify; rm -rf "$W"; mkdir -p "$W"

gen () { # gen <tag> <mkconfig-dir> <base> <HEADERS> <DEFINES>
  tag=$1; mk=$2; base=$3; hdrs=$4; defs=$5
  ( cd "$W" && TARGET_CPU_DEFAULT="" HEADERS="$hdrs" DEFINES="$defs" \
      INSN_BASE="$base" sh "$mk/mkconfig.sh" "tm-$base.h" >/dev/null 2>&1 )
  mv "$W/tm-$base.h" "$W/$tag-tm-$base.h"
}

RS_H="options-rs6000.h insn-constants-rs6000.h config/vxworks-dummy.h config/rs6000/biarch64.h config/rs6000/rs6000.h config/elfos.h config/gnu-user.h config/linux.h config/freebsd-spec.h config/rs6000/sysv4.h config/rs6000/default64.h config/rs6000/linux64.h config/glibc-stdint.h config/rs6000/option-defaults.h config/initfini-array.h defaults.h"
RS_D=" LIBC_GLIBC=1 LIBC_UCLIBC=2 LIBC_BIONIC=3 LIBC_MUSL=4 DEFAULT_LIBC=LIBC_GLIBC ANDROID_DEFAULT=0 TARGET_DEFAULT_LONG_DOUBLE_128=1 HEAP_TRAMPOLINES_INIT=0 TARGET_HAS_IFUNC=1"

gen before "$OLD" rs6000 "$RS_H" "$RS_D"
gen after  "$NEW" rs6000 "$RS_H" "$RS_D"

read_syms () { # read_syms <tag>
  tag=$1
  cp "$W/$tag-tm-rs6000.h" "$G/t49-$tag-tm-rs6000.h"
  sh "$S/eb-shell.sh" "cd $G && echo '#include \"t49-$tag-tm-rs6000.h\"' | cpp -dM -DIN_GCC -I. -I$OLD -x c++ - > $W/$tag.dm 2> $W/$tag.cpperr"
  n=$(grep -c . "$W/$tag.dm" || true)
  [ "$n" -gt 1000 ] || { echo "FATAL: $tag preprocessed to $n lines; refusing to score an empty read"; exit 9; }
  echo "--- $tag  ($n macros)"
  grep -E '^#define (TARGET_CMODEL|SET_CMODEL|DOT_SYMBOLS|HAVE_LD_LARGE_TOC|HAVE_LD_NO_DOT_SYMS)\b' "$W/$tag.dm" | sort
}

read_syms before
echo
read_syms after
echo
echo "== i386 CONTROL: the prologue must not change a base that never tests these"
I_H="options-i386.h insn-constants-i386.h config/vxworks-dummy.h config/i386/biarch64.h config/i386/i386.h config/i386/unix.h config/i386/att.h config/elfos.h config/gnu-user.h config/glibc-stdint.h config/i386/x86-64.h config/i386/gnu-user-common.h config/i386/gnu-user64.h config/linux.h config/linux-android.h config/i386/linux-common.h config/i386/linux64.h config/initfini-array.h defaults.h"
I_D="LIBC_GLIBC=1 LIBC_UCLIBC=2 LIBC_BIONIC=3 LIBC_MUSL=4 DEFAULT_LIBC=LIBC_GLIBC ANDROID_DEFAULT=0 HEAP_TRAMPOLINES_INIT=0 TARGET_HAS_IFUNC=1"
gen before "$OLD" i386 "$I_H" "$I_D"
gen after  "$NEW" i386 "$I_H" "$I_D"
if diff -q "$W/before-tm-i386.h" "$W/after-tm-i386.h" >/dev/null; then
  echo "   tm-i386.h IDENTICAL before/after -- but see below, that is TOO strong a pass"
else
  echo "   tm-i386.h DIFFERS:"; diff "$W/before-tm-i386.h" "$W/after-tm-i386.h" | head -20
fi
echo
echo "   (the prologue is emitted into EVERY tm-*.h, so the two new #ifndef"
echo "    blocks appear in tm-i386.h too.  What must be unchanged is the"
echo "    MEANING for i386: i386 tests neither macro, so no i386 symbol moves.)"
sh "$S/eb-shell.sh" "cd $G && for t in before after; do cp $W/\$t-tm-i386.h t49-\$t-tm-i386.h; echo '#include \"t49-'\$t'-tm-i386.h\"' | cpp -dM -DIN_GCC -I. -I$OLD -x c++ - | grep -vE 'HAVE_LD_(LARGE_TOC|NO_DOT_SYMS)' | sort > $W/i386-\$t.dm; done"
if diff -q "$W/i386-before.dm" "$W/i386-after.dm" >/dev/null; then
  echo "   i386 MACRO SET IDENTICAL apart from the two new names: control holds"
else
  echo "   i386 CONTROL FAILED -- something other than the two names moved:"
  diff "$W/i386-before.dm" "$W/i386-after.dm" | head -20
fi
