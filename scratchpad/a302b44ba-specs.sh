#!/bin/sh
# Probe a `specs-config' for each of this row's four targets, and CHECK THE
# `decimal_float' LINE IN BOTH DIRECTIONS.
#
# This is `af2bdad90c8ebe685-specs.sh' generalised from two hardcoded targets to
# a list, plus the assertion that row could not make: that `decimal_float' in
# the generated `specs-config' matches what `gcc/multi-target.manifest' says for
# that target, INCLUDING the targets where the right answer is 0.
#
# WHY BOTH DIRECTIONS.  9ee972c229d fixed "nothing passed `--with-decimal-float'
# in, so `target-specs/configure.ac:168' defaulted it to 0 for everyone".  The
# obvious wrong fix for that is to pass 1 for everyone, which is the identical
# defect with the sign flipped and produces a GREENER-looking board (dfp.exp
# runs everywhere, ~858 more results per target).  A check that only looks at
# the targets whose answer is 1 cannot tell the two apart.  So the manifest is
# the authority and every configured target is compared against it, and a target
# whose manifest says 0 and whose specs-config says 1 is a FATAL here.
#
# usage: B=<builddir> TOOLS=<toolsdir> a302b44ba-specs.sh <triple> [<triple>...]
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?set B to the build dir}
TOOLS=${TOOLS:?set TOOLS to the tools dir (with bin/ and <triple>.hdr)}
[ $# -ge 1 ] || { echo "FATAL: name at least one triple"; exit 9; }
TARGETS="$*"

NP="$HOME/src/nixos-configuration/dep/nixpkgs"
MANIFEST="$B/gcc/multi-target.manifest"

cmds="cd $B/gcc && make multi-target-specs && cd $B"
for T in $TARGETS; do
  H=$(cat "$TOOLS/$T.hdr") || exit 9
  [ -d "$H" ] || { echo "FATAL: no headers $H for $T"; exit 9; }
  [ -x "$TOOLS/bin/$T-as" ] || { echo "FATAL: no $TOOLS/bin/$T-as"; exit 9; }
  cmds="$cmds && make configure-target-specs-$T TOOLS_DIR_FOR_$T=$TOOLS/bin \
    TARGET_SPECS_FLAGS_FOR_$T=--with-native-system-header-dir=$H"
done

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    PATH=$TOOLS/bin:\$PATH; export PATH
    for t in $TARGETS; do command -v \$t-as; done
    $cmds
  " > "$B/specs.out" 2> "$B/specs.err"
rc=$?
echo "specs rc=$rc"
[ "$rc" = 0 ] || { tail -25 "$B/specs.err"; exit "$rc"; }

VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
[ -n "$VER" ] || { echo "FATAL: empty BASE-VER"; exit 9; }
[ -f "$MANIFEST" ] || { echo "FATAL: no $MANIFEST to check against"; exit 9; }

echo "-- specs-config per target (identity, not a statistic):"
n=0; bad=0; sawdf1=0; sawdf0=0
for T in $TARGETS; do
  F="$B/lib/gcc/$VER/$T/specs-config"
  if [ ! -f "$F" ]; then printf '  %-34s ABSENT\n' "$T"; bad=$((bad+1)); continue; fi
  n=$((n+1))
  # The manifest's answer for this target.  Absent is FATAL, not 0: "the line is
  # missing" and "the line says 0" are exactly the pair 9ee972c229d is about.
  mdf=$(awk -v t="$T" '$1=="target"{seen=($2==t)} seen && $1=="decimal_float"{print $2; exit}' "$MANIFEST")
  sdf=$(sed -n 's/^decimal_float //p' "$F" | head -1)
  [ -n "$mdf" ] || { echo "FATAL: $MANIFEST has no decimal_float line for $T"; exit 9; }
  [ -n "$sdf" ] || { echo "FATAL: $F has no decimal_float line at all"; exit 9; }
  printf '  %-34s wc -l %-5s md5 %s  decimal_float manifest=%s specs-config=%s' "$T" \
    "$(wc -l < "$F")" "$(md5sum < "$F" | cut -c1-12)" "$mdf" "$sdf"
  if [ "$mdf" = "$sdf" ]; then echo "  OK"; else echo "  *** MISMATCH"; bad=$((bad+1)); fi
  [ "$sdf" = 1 ] && sawdf1=$((sawdf1+1))
  [ "$sdf" = 0 ] && sawdf0=$((sawdf0+1))
done

[ "$n" -ge 2 ] || { echo "FATAL: only $n specs-configs written"; exit 9; }

# NON-VACUITY, BOTH WAYS.  If every target in this list came out 1, the
# comparison above could be satisfied by a build that hardcodes 1 -- and if
# every one came out 0 it could be satisfied by the pre-fix build.  This row's
# list is chosen to contain both, so require both to have been SEEN.
[ "$sawdf1" -ge 1 ] || { echo "FATAL: no target in this list came out decimal_float=1;"
  echo "  the comparison above cannot distinguish the fix from the pre-fix default."; exit 9; }
[ "$sawdf0" -ge 1 ] || { echo "FATAL: no target in this list came out decimal_float=0;"
  echo "  the comparison above cannot distinguish the fix from 'pass 1 to everyone'."; exit 9; }
echo "-- decimal_float: $sawdf1 target(s) at 1, $sawdf0 at 0; both arms present"

# The probes must not all be the same file: identical specs-configs mean a probe
# fell back to the host tools.
u=$(for T in $TARGETS; do md5sum < "$B/lib/gcc/$VER/$T/specs-config"; done | sort -u | wc -l)
[ "$u" = "$n" ] || { echo "FATAL: only $u distinct specs-config of $n -- a probe fell back to the host tools"; exit 9; }
echo "-- all $n specs-config md5s are distinct"

# Each target's probe must have resolved ITS OWN assembler by name.
for T in $TARGETS; do
  CL="$B/$T/target-specs/config.log"
  [ -f "$CL" ] || { echo "FATAL: no $CL -- $T's probe left no configure log"; exit 9; }
  sawas=$(sed -n 's/^gcc_cv_as=//p' "$CL" | head -1)
  [ "$sawas" = "$T-as" ] || { echo "FATAL: $T's probe resolved gcc_cv_as='$sawas', not $T-as"; exit 9; }
  printf '  %-34s gcc_cv_as=%s\n' "$T" "$sawas"
done

[ "$bad" = 0 ] || { echo "FATAL: $bad target(s) wrong or absent"; exit 9; }
echo "-- specs OK for $n target(s)"
