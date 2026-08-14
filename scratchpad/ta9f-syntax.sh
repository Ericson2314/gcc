#!/bin/sh
# CHEAP SYNTAX ARM.  A full eleven-base `all-gcc' is ~40 minutes; a typo in a
# shared file costs all of it.  This replays the EXACT compile line make used
# for one object in an existing build dir, with the worktree's `gcc' directory
# prepended to the include path so the file under test and any new headers
# beside it are the ones compiled, and with -fsyntax-only.
#
# WHAT IT CANNOT SEE, stated because a green here is easy to over-read: it does
# not link, so it cannot catch a missing definition, and it compiles the SHARED
# variant only -- a per-base object (`mt-<base>/target-cumargs.o') has a
# different command line and is checked by passing that object's name.
#
# usage: ta9f-syntax.sh <builddir> <objectname> <source-basename>
set -u
S=$(cd "$(dirname "$0")" && pwd)
W=$(cd "$S/../gcc" && pwd)
D=${1:?build dir}
OBJ=${2:?object name, e.g. mode-switching.o}
SRCB=${3:?source basename, e.g. mode-switching.cc}
case "$D" in
  */b-a9f631a78e8fb27d2*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
LOG=$D/make-top.out
[ -f "$LOG" ] || { echo "FATAL: no $LOG"; exit 9; }

# THE PER-BASE COMPILE LINES ARE WRAPPED.  `target-cumargs-riscv.o''s recipe
# ends in a backslash and the source file is on the FOLLOWING log line, so a
# single-line grep finds the command and silently loses the input -- which is
# the shape that scores a green about a file it never compiled.  awk joins the
# continuation before anything is matched.
line=$(awk -v obj=" -o $OBJ " '
  { if (cont) { cur = cur " " $0 } else { cur = $0 } }
  { cont = (cur ~ /\\$/); if (cont) { sub(/\\$/, "", cur); next } }
  index (cur, obj) { print cur; exit }' "$LOG")
[ -n "$line" ] || { echo "FATAL: no compile line for $OBJ in $LOG"; exit 9; }
case "$line" in
  *"$SRCB"*) ;;
  *) echo "FATAL: compile line for $OBJ does not name $SRCB"; exit 9 ;;
esac

SNAP=$(cat "$D/MY-SRC")
cmd=$(printf '%s\n' "$line" \
  | sed -e "s|-I$SNAP/gcc |-I$W -I$SNAP/gcc |" \
        -e "s|$SNAP/gcc/$SRCB|$W/$SRCB|" \
        -e "s|^g++ |g++ -fsyntax-only |" \
        -e "s| -o $OBJ | |" \
        -e "s| -MT $OBJ -MMD -MP -MF [^ ]*| |")
# NON-VACUITY: the substitution must actually have redirected the source, or
# this would compile the SNAPSHOT's unmodified file and report a green about
# code that is not under test.
case "$cmd" in
  *"$W/$SRCB"*) ;;
  *) echo "FATAL: source was not redirected to $W/$SRCB"; exit 9 ;;
esac
case "$cmd" in
  *" -I$W "*) ;;
  *) echo "FATAL: worktree include dir was not prepended"; exit 9 ;;
esac

cd "$D/gcc" || exit 9
sh "$S/eb-shell.sh" "cd $D/gcc && $cmd"
echo "rc=$? for $OBJ ($W/$SRCB)"
