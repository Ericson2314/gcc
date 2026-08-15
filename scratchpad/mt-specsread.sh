#!/bin/sh
# mt-specsread.sh -- PROVE THAT THE TARGET'S OWN `specs' FILE WAS READ, and
# fail BY NAME when it was not.
#
# WHY THIS EXISTS.  `gcc.cc' resolves the target from `-ftarget-config=FILE'
# first and from the program name second.  Only the second path used to set
# `found_target_config', and `set_up_specs' derives
# `dirname (found_target_config)/specs' from it -- so an explicit
# `-ftarget-config=' read NO per-target spec file at all: no `*option_defaults',
# no `*self_spec', no `*asm', no `*link' for that target.  `mtcheck.sh' drives
# exactly that flag, on `xgcc', which carries no triple.  Therefore EVERY board
# this project recorded through mtcheck.sh -- TAA-BOARD.md, SC-BOARD.md's
# multi-target column, every per-target score -- was taken on a compiler whose
# target had contributed nothing to the spec set.
#
# AND THE TWO STATES ARE INDISTINGUISHABLE FROM A LOG.  A compiler that read no
# spec file and a compiler whose spec file says nothing produce byte-identical
# output, byte-identical diagnostics and the same exit status.  That is this
# branch's most expensive failure shape (PRINCIPLES 4: "a null result must be
# impossible to confuse with a pass"), and it is why this file is a
# PRECONDITION on the board rather than a note beside it.
#
# THE FOUR ARMS, and arm 3 is the one that makes arms 2 and 4 mean anything.
#
#   1  the file exists AND names the specs it defines, BY NAME.  Not `test -s':
#      a truncated specs file is non-empty and this machinery has shipped 39
#      lines of 101 (PRINCIPLES 4).
#   2  POSITIVE: the running driver says `Reading specs from <dir>/specs'.
#      Read out of the compiler, never out of the build system.
#   3  NEGATIVE CONTROL ON THE INSTRUMENT ITSELF: the same target-config,
#      copied to a directory with NO `specs' beside it, must produce NO such
#      line.  Without this, arm 2 passing proves only that the grep matched
#      something -- and a `Reading specs from' for the BUILT-IN specs would
#      pass it.  If arm 3 also reports "read", the instrument is broken and
#      this script REFUSES rather than reporting arm 2's green.
#   4  LOAD-BEARING: the cc1 command line `-###' produces must DIFFER between
#      those two configurations, and the difference is printed.  Arm 2 says a
#      file was opened; arm 4 says its contents reached cc1.  Those are two
#      claims and the second needs its own instrument -- the regression this
#      file guards was invisible to arm-2-shaped reasoning for months.
#
# EVERY cc1/xgcc INVOCATION HERE IS CAPPED by tb1-memcap.sh: one testcase
# reached 20.8 GB and took the user's machine with it.
#
# usage: mt-specsread.sh <builddir> <triple> [<triple> ...]
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

B=${1:?build dir}; shift
[ $# -ge 1 ] || mt_die "name at least one target triple"
mt_assert_builddir "$B"
SRC=$(mt_src_of "$B") || exit 9
mt_assert_configured_from "$B" "$SRC"
n=$(mt_assert_anchor "$SRC") || exit 9
kind=$(mt_assert_src_frozen "$SRC") || exit 9
[ -x "$B/gcc/xgcc" ] || mt_die "no $B/gcc/xgcc"
VER=$(cat "$SRC/gcc/BASE-VER")
[ -n "$VER" ] || mt_die "empty BASE-VER"
CAP=${MT_MEMCAP_KB:-8388608}

W="$B/specsread"; rm -rf "$W"; mkdir -p "$W"
echo 'int mt_specsread_probe (void) { return 0; }' > "$W/probe.c"

echo "== mt-specsread: srcdir $SRC $kind anchor=$n  gcc $VER  targets: $*"
fail=0
for T in "$@"; do
  echo
  echo "################ $T"
  CFG="$B/lib/gcc/$VER/$T/specs-config"
  DIR=$(dirname "$CFG")
  SPECS="$DIR/specs"

  # ---- ARM 1: the artefact, by name ----------------------------------------
  if [ ! -f "$CFG" ]; then
    echo "FAIL[$T] ARM1: no target-config at $CFG (run the target-specs probe)"
    fail=$((fail+1)); continue
  fi
  if [ ! -f "$SPECS" ]; then
    echo "FAIL[$T] ARM1: no per-target spec file at $SPECS"
    echo "  The target-config exists, so target-specs ran; it wrote no \`specs'."
    fail=$((fail+1)); continue
  fi
  names=$(sed -n 's/^\*\([a-zA-Z_0-9]*\):.*/\1/p' "$SPECS" | sort -u | tr '\n' ' ')
  echo "-- ARM1 $SPECS: wc -l $(wc -l < "$SPECS")  md5 $(md5sum < "$SPECS" | cut -c1-12)"
  echo "   defines: $names"
  # The four the driver actually consults for a target.  Absence of all four
  # would make arms 2 and 4 vacuous -- the file would be read and say nothing,
  # which is exactly the state this script cannot be allowed to score green.
  got=0
  for want in option_defaults self_spec asm link; do
    case " $names " in *" $want "*) got=$((got+1)) ;; esac
  done
  if [ "$got" = 0 ]; then
    echo "FAIL[$T] ARM1: $SPECS defines none of *option_defaults *self_spec *asm *link."
    echo "  A spec file that says nothing is indistinguishable from one never read."
    fail=$((fail+1)); continue
  fi
  echo "   $got of 4 target-bearing specs present"

  # ---- ARM 3 fixture: the same config, alone in a directory ----------------
  # Built BEFORE arm 2 runs, so the control cannot be skipped when arm 2 fails.
  BARE="$W/bare-$T"; rm -rf "$BARE"; mkdir -p "$BARE"
  cp "$CFG" "$BARE/specs-config"
  [ ! -e "$BARE/specs" ] || mt_die "the bare fixture has a specs file; the control is void"

  runv () {  # $1 = target-config path, $2 = output stem
    sh "$MT_LIB_DIR/tb1-memcap.sh" "$CAP" \
      "$B/gcc/xgcc" -B"$B/gcc/" -v -S -o /dev/null \
        -ftarget-config="$1" "$W/probe.c" > "$2.out" 2> "$2.err"
    echo $? > "$2.rc"
  }
  runv "$CFG"              "$W/real-$T"
  runv "$BARE/specs-config" "$W/bare-$T-run"

  # ---- ARM 2: POSITIVE -----------------------------------------------------
  if grep -qF "Reading specs from $SPECS" "$W/real-$T.err"; then
    echo "-- ARM2 PASS: driver reports \`Reading specs from $SPECS'"
  else
    echo "FAIL[$T] ARM2: the driver NEVER READ $SPECS."
    echo "  Command:"
    echo "    $B/gcc/xgcc -B$B/gcc/ -v -S -ftarget-config=$CFG $W/probe.c"
    echo "  This is the \`-ftarget-config= leaves found_target_config NULL' defect."
    echo "  Any board taken with this compiler measured a target with NO"
    echo "  *option_defaults, *self_spec, *asm or *link of its own."
    grep -i 'Reading specs' "$W/real-$T.err" | sed 's/^/    saw: /'
    fail=$((fail+1))
  fi

  # ---- ARM 3: NEGATIVE CONTROL ON THE INSTRUMENT ---------------------------
  if grep -q 'Reading specs from' "$W/bare-$T-run.err"; then
    echo "FAIL[$T] ARM3 (control): the driver reports reading specs even with"
    echo "  the target-config alone in $BARE, where no \`specs' file exists:"
    grep -i 'Reading specs' "$W/bare-$T-run.err" | sed 's/^/    /'
    echo "  ARM2's green therefore proves nothing.  REFUSING."
    fail=$((fail+1))
  else
    echo "-- ARM3 PASS (control): no \`Reading specs from' when none is there"
  fi

  # ---- ARM 4: the contents reach cc1 ---------------------------------------
  cc1line () {
    sh "$MT_LIB_DIR/tb1-memcap.sh" "$CAP" \
      "$B/gcc/xgcc" -B"$B/gcc/" -\#\#\# -S -o /dev/null \
        -ftarget-config="$1" "$W/probe.c" 2>&1 | grep -F 'cc1' | tail -1
  }
  a=$(cc1line "$CFG")
  b=$(cc1line "$BARE/specs-config")
  printf '%s\n' "$a" > "$W/cc1-real-$T.txt"
  printf '%s\n' "$b" > "$W/cc1-bare-$T.txt"
  if [ -z "$a" ] || [ -z "$b" ]; then
    echo "FAIL[$T] ARM4: \`-###' produced no cc1 line (real=[${a:-}] bare=[${b:-}])"
    fail=$((fail+1))
  elif [ "$a" = "$b" ]; then
    echo "FAIL[$T] ARM4: the cc1 command line is IDENTICAL with and without the"
    echo "  target's spec file.  The file was opened and contributed nothing to"
    echo "  what cc1 was told; the board would be measuring an unconfigured target."
    fail=$((fail+1))
  else
    echo "-- ARM4 PASS: the spec file changes what cc1 is told.  Added by it:"
    tr ' ' '\n' < "$W/cc1-real-$T.txt" | sort -u > "$W/ra-$T"
    tr ' ' '\n' < "$W/cc1-bare-$T.txt" | sort -u > "$W/rb-$T"
    comm -23 "$W/ra-$T" "$W/rb-$T" | sed 's/^/     + /'
    comm -13 "$W/ra-$T" "$W/rb-$T" | sed 's/^/     - /'
  fi
done

echo
if [ "$fail" != 0 ]; then
  echo "SPECSREAD: $fail arm(s) FAILED.  Do not score a board with this compiler."
  exit 9
fi
echo "SPECSREAD PASSES for: $*"
