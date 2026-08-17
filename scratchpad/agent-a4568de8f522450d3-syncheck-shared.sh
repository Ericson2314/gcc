#!/bin/sh
# agent-a4568de8f522450d3-syncheck-shared.sh -- `-fsyntax-only' a SHARED
# translation unit (compiled once, against the primary's tm.h) from the
# working tree, using the flags a real build used for it.
#
# The sibling `-syncheck.sh' covers `target-cumargs.cc', which is compiled once
# PER BASE.  It says nothing about the shared files a conversion also edits --
# `final.cc', `varasm.cc' -- and those are where a call-site rewrite actually
# lands.  Two populations, two harnesses; scoring one and reporting the other
# is this project's own root pattern.
#
# Same false-green trap and the same remedy: `g++' is absent outside the nix
# dev shell, so a broken invocation produces no `error:' and every file scores
# clean.  The negative control is not optional.
set -u
D=${D:?set D to an existing build dir}
SRC=${SRC:?set SRC to the source tree to check}
LOG=${LOG:-$D/all-gcc.log}
FILES=${FILES:-final.cc varasm.cc}

[ -f "$LOG" ] || { echo "FATAL: no $LOG"; exit 9; }
cd "$D/gcc" || exit 9

# THE SNAPSHOT'S `-I' PATHS MUST BE REPOINTED AT $SRC, AND NOT DOING SO MAKES
# THIS HARNESS WORTHLESS IN THE QUIET DIRECTION.
#
# The compile line lifted from the log carries `-I<snapshot>/gcc'.  Left alone,
# the harness compiles the WORKING TREE's `.cc' against the SNAPSHOT's `.h' --
# i.e. new code against old headers.  A conversion that adds a prototype to
# `target-frame.h' and a call in `final.cc' then fails with
# `mt_addr_vec_align was not declared', which reads as a bug in the change and
# is a bug in the harness; and worse, a change that only EDITS a header scores
# clean because the header under test was never opened.
#
# Measured: the first version of the sibling `-syncheck.sh' reported 47 of 47
# bases `ok' for a `target-cumargs.cc' whose new table initialiser refers to a
# struct field that exists only in the working tree's `target-frame.h'.  That
# should have been "too many initializers" and was not, because the snapshot's
# header was the one it read.
SNAP=""
cmd_for () { # cmd_for <basename.cc> -- the g++ line whose NEXT line names it
  n=$(grep -n "/gcc/$1[[:space:]]*\$" "$LOG" | head -1 | cut -d: -f1)
  [ -n "$n" ] || return 1
  line=$(sed -n "$((n-1))p" "$LOG" | sed 's/[[:space:]]*\\$//')
  SNAP=$(printf '%s\n' "$line" | tr ' ' '\n' | sed -n 's|^-I\(/tmp/snap-[^/]*\)/gcc$|\1|p' | head -1)
  [ -n "$SNAP" ] || { echo "FATAL: no -I<snapshot>/gcc in the compile line" >&2; return 1; }
  printf '%s\n' "$line" \
    | sed "s#$SNAP#$SRC#g" \
    | sed "s/ -o [A-Za-z0-9_.-]*\.o//" \
    | sed "s/ -MT [A-Za-z0-9_.-]*\.o//" \
    | sed "s# -MF \./\.deps/[A-Za-z0-9_.-]*\.TPo##" \
    | sed 's/ -MMD -MP//'
}

ok=0; fail=0
for f in $FILES; do
  [ -f "$SRC/gcc/$f" ] || { echo "  $f SKIP (not in $SRC/gcc)"; continue; }
  C=$(cmd_for "$f") || { echo "  $f FAIL: no compile line in $LOG"; fail=$((fail+1)); continue; }
  err=/tmp/syn-shared-a4568-$(echo "$f" | tr / _).err
  eval "$C -fsyntax-only '$SRC/gcc/$f'" > /dev/null 2> "$err"
  if grep -q 'error:' "$err"; then
    printf '  %-14s FAIL\n' "$f"
    grep 'error:' "$err" | head -4 | sed 's/^/       /'
    fail=$((fail+1))
  else
    printf '  %-14s ok\n' "$f"
    ok=$((ok+1))
  fi
done

echo
echo "shared TUs ok=$ok fail=$fail"

# NON-VACUITY -- see the header.  A clean sweep here is worthless unless the
# compiler demonstrably ran and demonstrably read our file.
echo "NON-VACUITY (can this harness fail at all?):"
first=$(echo $FILES | awk '{print $1}')
C=$(cmd_for "$first") || { echo "  FATAL: no template command"; exit 9; }
BAD=/tmp/syn-shared-a4568-negctl.cc
{ cat "$SRC/gcc/$first"; echo 'int mt_negative_control (void) { return undeclared_on_purpose_a4568; }'; } > $BAD
eval "$C -fsyntax-only $BAD" > /dev/null 2> /tmp/syn-shared-a4568-negctl.err
if grep -q 'undeclared_on_purpose_a4568' /tmp/syn-shared-a4568-negctl.err; then
  echo "  ok: an injected undeclared identifier IS reported -- the harness runs"
else
  echo "  FATAL: the negative control did NOT fire; every 'ok' above is void"
  head -5 /tmp/syn-shared-a4568-negctl.err | sed 's/^/       /'
  exit 9
fi
[ $ok -gt 0 ] || { echo "FATAL: zero files compiled"; exit 9; }
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
