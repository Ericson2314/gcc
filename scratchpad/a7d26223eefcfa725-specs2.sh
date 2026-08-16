#!/bin/sh
# Run `target-specs' PER TARGET, INDEPENDENTLY -- one target's failure must not
# hide the next 23.
#
# THE DEFECT THIS REPLACES, measured at 4387bf9ce42 with 45 verified cross
# assemblers.  `agent-acda89931a903ec27-specs.sh' accumulates every target into
# ONE `&&'-chained command string:
#
#     cmds="$cmds && make configure-target-specs-$T TOOLS_DIR_FOR_$T=$TOOLS"
#
# and runs it once.  `m68k-unknown-elf' is the known #218 blocker -- its
# `OPTION_DEFAULT_SPECS' spells the value `-%(VALUE)', the only back end of 22
# that does, so the driver is handed `-mcpu=m68020' and refuses it.  m68k sits
# in the MIDDLE of the alphabetical list, so `make' returned 2 there and the
# remaining 23 targets were NEVER ATTEMPTED.  The report then printed:
#
#     specs OK=21 SPECS-FAIL=24
#
# All 24 of those rows read `has an as; target-specs produced nothing' -- which
# is a statement about a target, and it was true of exactly ONE of them.  The
# other 23 are `NOT-ATTEMPTED', a fourth verdict, and the difference is the
# whole point of the exercise: rs6000, sparc, riscv, s390 and 19 others were
# scored as broken when nothing had asked them anything.
#
# This is PRINCIPLES' `-k' rule in a new place -- "never attempted" and
# "failed" arriving as the same silence -- and it is the specific trap the
# brief names: collapsing distinct missing-artefact verdicts makes the table
# worse than useless.  Note the failure direction: it makes the branch look
# WORSE than it is, which is the direction nobody double-checks.
#
# So: one `make' invocation per target, each with its own rc, and four
# verdicts kept apart.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?build dir}
TOOLS=${TOOLS:?verified tools bin dir}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
HDRX=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
TX=x86_64-pc-linux-gnu
OUT=${OUT:-$B/specs-per-target}
mkdir -p "$OUT"

LIST=$(cut -d: -f2 "$S/agent-acda89931a903ec27-backends.txt")
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
[ -n "$VER" ] || { echo "FATAL: empty BASE-VER"; exit 9; }

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"

# `multi-target-specs' once, up front -- it is a shared prerequisite, not a
# per-target step, and rebuilding it per target would serialise 45 makes.
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' \
  --run "cd $B/gcc && make multi-target-specs" > "$OUT/prereq.out" 2>&1
echo "prereq multi-target-specs rc=$? (see $OUT/prereq.out)"

nas=0
for T in $LIST; do
  [ -x "$TOOLS/$T-as" ] || { echo "$T NO-CROSS-AS"; continue; }
  nas=$((nas+1))
done
echo "== targets with a verified cross as: $nas"

for T in $LIST; do
  F="$B/lib/gcc/$VER/$T/specs-config"
  if [ -f "$F" ]; then
    printf '%-30s ALREADY  md5 %s\n' "$T" "$(md5sum < "$F" | cut -c1-12)"
    continue
  fi
  if [ ! -x "$TOOLS/$T-as" ]; then
    # NOT-APPLICABLE, not "not probed": gcn uses LLVM's assembler and nvptx
    # uses `ptxas'.  There is no GNU cross `as' to package for them and their
    # absence says nothing about the back end.
    case "$T" in
      amdgcn-*|nvptx-*) printf '%-30s NOT-APPLICABLE (LLVM as / ptxas)\n' "$T" ;;
      *)                printf '%-30s NO-CROSS-AS\n' "$T" ;;
    esac
    continue
  fi
  if [ "$T" = "$TX" ]; then
    mk="make configure-target-specs-$TX TOOLS_DIR_FOR_$TX=\$nat \
        TARGET_SPECS_FLAGS_FOR_$TX=--with-native-system-header-dir=$HDRX"
  else
    mk="make configure-target-specs-$T TOOLS_DIR_FOR_$T=$TOOLS"
  fi
  nix-shell -I "nixpkgs=$NP" \
    -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
    --substituters 'https://cache.nixos.org/' --run "
      nat=\$(dirname \$(command -v as))
      PATH=$TOOLS:\$PATH; export PATH
      cd $B && $mk
    " > "$OUT/$T.out" 2> "$OUT/$T.err"
  rc=$?
  echo "$rc" > "$OUT/$T.rc"
  if [ -f "$F" ]; then
    printf '%-30s OK       wc -l %-5s grep -c . %-5s md5 %s\n' "$T" \
      "$(wc -l < "$F")" "$(grep -c . "$F")" "$(md5sum < "$F" | cut -c1-12)"
  else
    # NAME THE MISSING ARTEFACT.  The first `error:' line is the finding; a
    # bare "produced nothing" is what made 23 innocent targets look broken.
    why=$(grep -m1 'error:' "$OUT/$T.err" "$OUT/$T.out" 2>/dev/null | cut -c1-100)
    printf '%-30s SPECS-FAIL rc=%s  %s\n' "$T" "$rc" "${why:-no error: line; see $OUT/$T.err}"
  fi
done

echo
echo "-- totals"
ok=0; fail=0; na=0; noas=0
for T in $LIST; do
  if [ -f "$B/lib/gcc/$VER/$T/specs-config" ]; then ok=$((ok+1))
  elif [ ! -x "$TOOLS/$T-as" ]; then
    case "$T" in amdgcn-*|nvptx-*) na=$((na+1)) ;; *) noas=$((noas+1)) ;; esac
  else fail=$((fail+1)); fi
done
echo "specs OK=$ok  SPECS-FAIL=$fail  NOT-APPLICABLE=$na  NO-CROSS-AS=$noas  (of 47)"
echo "NOTE: every SPECS-FAIL above was ATTEMPTED and has its own rc file."
