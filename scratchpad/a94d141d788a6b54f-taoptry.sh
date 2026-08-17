#!/bin/sh
# a94d141d788a6b54f-taoptry.sh -- compile `target-asm-ops.cc' for N bases in
# SECONDS, from the LIVE worktree, inside an already-configured build dir.
#
# WHY.  Every `target-asm-ops.cc' error found here is of the form "this base's
# header expands to a body that calls something this TU has not declared", and
# they arrive ONE AT A TIME across 47 bases.  Discovering them through a full
# `make all-gcc' costs ~40 minutes per attempt for a diagnostic the compiler
# can give in two seconds.  This is `agent-a4568de8f522450d3-syncheck.sh''s
# shape, aimed at one file.
#
# THE NEGATIVE CONTROL IS MANDATORY AND IS THE LESSON THAT SCRIPT RECORDS: its
# first run swept 22 bases `ok' while compiling NOTHING, because it ran outside
# the nix dev shell and every compile died with `command not found', which
# produces no `error:' line and scores as a pass.  So this script appends a
# deliberately undeclared identifier to a copy of the file and REQUIRES the
# compiler to name it.  "Did the command exit 0" and "is the error file
# non-empty" both pass in the broken case; only demanding a specific diagnostic
# works.
#
# It reads the compile command out of the build dir's own `all-gcc.log', so it
# cannot drift from what `make' actually runs -- and it takes the SOURCE from
# the worktree rather than the snapshot, which is the whole point.
#
# usage: D=<builddir> SRCFILE=<worktree>/gcc/target-asm-ops.cc taoptry.sh <base>...
set -u
D=${D:?build dir}
SRCFILE=${SRCFILE:?path to the target-asm-ops.cc under test}
[ $# -ge 1 ] || { echo "FATAL: name at least one base"; exit 9; }
[ -f "$D/all-gcc.log" ] || { echo "FATAL: no $D/all-gcc.log to read the command from"; exit 9; }
[ -f "$SRCFILE" ] || { echo "FATAL: no $SRCFILE"; exit 9; }

W=$(cd "$(dirname "$0")" && pwd)
T=/tmp/taoptry-$$
mkdir -p "$T"
cp "$SRCFILE" "$T/good.cc"
cp "$SRCFILE" "$T/ctrl.cc"
echo 'int gcc_taop_negative_control (void) { return mt_taop_no_such_identifier; }' >> "$T/ctrl.cc"

ok=0; bad=0; ctrl_fired=0
for b in "$@"; do
  # The command make ran, joined from its backslash continuations, with the
  # source path replaced.  `-o' is redirected so nothing in the build dir moves.
  cmd=$(awk -v want="target-asm-ops-$b.o " '
    index($0, "-o " want) { c = $0; while (c ~ /\\$/) { sub(/\\$/, "", c); getline nx; c = c " " nx } print c; exit }
  ' "$D/all-gcc.log")
  if [ -z "$cmd" ] && [ -n "${TEMPLATE:-}" ]; then
    # A FAILED build stops early, so its log holds compile lines for only the
    # handful of bases make reached before the error -- and sweeping "the
    # bases that happen to be in the log" is a population chosen by the bug.
    # So one base's line is used as a TEMPLATE and its base name substituted.
    # The five places the name appears are the ones the generator writes:
    # tm-<b>.h, tm_p-<b>.h, TARGETM_ASM_OPS_SYMBOL, MT_BASE and -o.  A
    # substitution that missed one would compile the TEMPLATE's headers under
    # another base's name, which is this branch's own bug -- so the loop below
    # asserts afterwards that the template's own name no longer appears.
    cmd=$(awk -v want="target-asm-ops-$TEMPLATE.o " '
      index($0, "-o " want) { c = $0; while (c ~ /\\$/) { sub(/\\$/, "", c); getline nx; c = c " " nx } print c; exit }
    ' "$D/all-gcc.log")
    cmd=$(printf '%s' "$cmd" | sed -e "s#tm-$TEMPLATE\.h#tm-$b.h#g" \
                                   -e "s#tm_p-$TEMPLATE\.h#tm_p-$b.h#g" \
                                   -e "s#targetm_asm_ops_$TEMPLATE#targetm_asm_ops_$b#g" \
                                   -e "s#MT_BASE=$TEMPLATE-inc#MT_BASE=$b-inc#g" \
                                   -e "s#target-asm-ops-$TEMPLATE#target-asm-ops-$b#g")
    case "$cmd" in
      *"$TEMPLATE"*) echo "FATAL: '$TEMPLATE' survives in the command for $b -- a substitution was missed"; exit 9 ;;
    esac
  fi
  if [ -z "$cmd" ]; then
    echo "SKIP  $b   (no compile line in $D/all-gcc.log; set TEMPLATE=<base>)"
    continue
  fi
  base_cmd=$(printf '%s' "$cmd" | sed -e "s#-o target-asm-ops-$b\.o#-o $T/$b.o#" \
                                      -e "s#-MF [^ ]*##" -e "s#-MT [^ ]*##" -e "s#-MMD##" -e "s#-MP##" \
                                      -e "s#[^ ]*/gcc/target-asm-ops\.cc##")
  # EXTRA is expanded with `$b' available, so a per-base flag under test (e.g.
  # EXTRA='-DMT_BASE=$b-inc') can be tried BEFORE it is added to the generator
  # and a 40-minute build is spent on it.
  extra=$(eval "echo \"${EXTRA:-}\"")
  ( cd "$D/gcc" && eval "$base_cmd $extra $T/good.cc" ) > "$T/$b.err" 2>&1
  if grep -q 'error:' "$T/$b.err"; then
    echo "FAIL  $b"
    sed -n 's/.*error: /        /p' "$T/$b.err" | sort -u | head -4
    bad=$((bad + 1))
  else
    ok=$((ok + 1))
  fi
  if [ "$ctrl_fired" = 0 ]; then
    ( cd "$D/gcc" && eval "$base_cmd $extra $T/ctrl.cc" ) > "$T/ctrl.err" 2>&1
    grep -q 'mt_taop_no_such_identifier' "$T/ctrl.err" && ctrl_fired=1
  fi
done

echo "taoptry: ok=$ok fail=$bad"
if [ "$ctrl_fired" != 1 ]; then
  echo "FATAL: the negative control did NOT fire; every 'ok' above is VOID"
  sed -n 1,3p "$T/ctrl.err"
  exit 9
fi
echo "negative control fired (the compiler named mt_taop_no_such_identifier)"
[ "$bad" = 0 ]
