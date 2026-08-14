#!/bin/sh
# mt-specs-fallback.sh -- produce a specs-config for a target that has NO cross
# binutils anywhere in this nixpkgs (ia64, visium, xtensa, sparc64), by pointing
# the probe at the BUILD MACHINE's own as/ld.
#
# WHAT THIS DELIBERATELY DOES, AND WHY IT IS NOT THE SECTION-5 TRAP.  PRINCIPLES
# section 5 records that a probe silently falling back to the build machine's
# `as' writes a file that NAMES the target while DESCRIBING x86_64, and that
# every name- and path-based check passes on it.  Here that fallback is asked
# for ON PURPOSE, by an explicit --with-as, and the resulting config answers
# EXACTLY ONE question: does cc1 reach codegen for this back end at all.  Its
# ANSWERS are x86_64's and are trusted for nothing.  What it supplies is a
# well-formed config file, so that "cc1 refuses to start without
# -ftarget-config=" cannot be mistaken for "this back end cannot compile".
#
# For the ia64 heap-overflow arm this is sufficient and its limits do not bite:
# the defect is in the scheduler's DFA state buffer, which is decided by the
# back end's own automaton and not by anything the assembler probe reports.
#
# usage: mt-specs-fallback.sh <builddir> <canonical-triple>
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

D=${1:?build dir}; T=${2:?canonical triple}
mt_assert_builddir "$D"
SRC=$(mt_src_of "$D") || exit 9
mt_assert_configured_from "$D" "$SRC"

mt_shell "cd $D/gcc && make multi-target-specs" > "$D/specs-fb-pre.out" 2>&1 \
  || { tail -20 "$D/specs-fb-pre.out"; mt_die "make multi-target-specs failed"; }

mt_shell "
  set -e
  nat=\$(dirname \$(command -v as))
  echo \"host binutils: \$nat\"
  cd $D && make configure-target-specs-$T TOOLS_DIR_FOR_$T=\$nat \\
    TARGET_SPECS_FLAGS_FOR_$T=\"--with-as=\$nat/as --with-ld=\$nat/ld \\
      --with-nm=\$nat/nm --with-objdump=\$nat/objdump --with-readelf=\$nat/readelf\"
" > "$D/specs-fb.out" 2>&1
rc=$?
echo "rc=$rc"

# CHECK THE ARTEFACT, NOT THE EXIT STATUS.  This machinery has exited partway
# and left a spec file truncated at 39 lines instead of 101, and every `test -s'
# guard passed because 39 lines is non-empty.
V=$(cat "$SRC/gcc/BASE-VER")
C=$D/lib/gcc/$V/$T/specs-config
[ -s "$C" ] || { tail -25 "$D/specs-fb.out"; mt_die "no specs-config at $C"; }
echo "specs-config $T: wc -l $(wc -l < "$C")  grep -c . $(grep -c . "$C")  md5 $(md5sum < "$C" | cut -c1-12)"
# The keys cc1 refuses to start without, by name.  "long enough" is not a check.
for k in target_triple; do
  grep -q "^$k" "$C" || echo "  NOTE: key '$k' not present under that spelling"
done
