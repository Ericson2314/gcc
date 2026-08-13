#!/bin/sh
# Is `#include "tm.h"' load-bearing in each of the 101 gcc/config/ files that
# spell it?
#
# The instrument is a DIFFERENTIAL COMPILE, not a grep.  A grep for macro
# names cannot answer this: tm.h exports hundreds of names and transitive uses
# would be missed entirely.  So each file is compiled twice with a byte-
# identical command line -- once as it stands, once with the tm.h include line
# deleted -- and the two exit statuses are compared:
#
#   BASE ok, CUT ok    -> VESTIGIAL   the include buys the file nothing
#   BASE ok, CUT fail  -> NEEDS       genuinely load-bearing
#   BASE fail          -> UNCHECKABLE the file does not compile in THIS
#                                     configuration at all (its back end is
#                                     not configured here), so the question
#                                     cannot be put to it.  This is a verdict,
#                                     not a pass and not a licence to delete.
#
# The BASE arm is what makes UNCHECKABLE distinguishable from VESTIGIAL.
# Without it a file that fails for a reason having nothing to do with tm.h
# would be scored as "needs it", and a file whose failure predates the cut
# would be invisible.
#
# The edit is made IN PLACE and restored from a saved copy, deliberately: a
# quoted #include searches the including file's own directory first, so
# compiling a copy parked elsewhere would resolve sibling headers differently
# and answer a different question.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
D=${D:?set D to YOUR OWN build dir -- never /tmp/b<task number>, which collides by construction}
LIST=$W/wk/tmh-config.txt
OUT=$W/wk/probe-results.txt
SAVE=$W/wk/save.cc

[ -s "$LIST" ] || { echo "FATAL: no $LIST"; exit 9; }
n=$(wc -l < "$LIST")
[ "$n" = 101 ] || { echo "FATAL: list has $n entries, expected 101"; exit 9; }

# The command line is taken from the build's own log rather than reconstructed,
# so that a file gets exactly the flags the build would give it.  Two
# templates: per-base (carries -DMT_BASE, used for everything under config/)
# and shared (no -DMT_BASE, used for the three config objects the build
# compiles once).  CMD_* are everything except -o/-MT/-MMD/-MP/-MF and the
# source.
tmpl () {
  grep -m1 -- "$1" "$W/wk/build.out" \
    | sed -e 's/ -o [^ ]*\.o / /' -e 's/ -MT [^ ]*//' -e 's/ -MMD -MP//' \
          -e 's/ -MF [^ ]*//' -e 's| /home[^ ]*\.cc$||'
}
CMD_I386=$(tmpl '\-o mt-i386/linux\.o ')
CMD_A64=$(tmpl '\-o mt-aarch64/linux\.o ')
CMD_SHARED=$(tmpl '\-o glibc-c\.o ')
for v in "$CMD_I386" "$CMD_A64" "$CMD_SHARED"; do
  case $v in g++*) ;; *) echo "FATAL: bad template: $v"; exit 9;; esac
done
echo "$CMD_I386"   | grep -q -- '-DMT_BASE=i386-inc'    || { echo "FATAL: i386 template lost -DMT_BASE"; exit 9; }
echo "$CMD_A64"    | grep -q -- '-DMT_BASE=aarch64-inc' || { echo "FATAL: a64 template lost -DMT_BASE"; exit 9; }
echo "$CMD_SHARED" | grep -q -- '-DMT_BASE'             && { echo "FATAL: shared template has -DMT_BASE"; exit 9; }

: > "$OUT"
cd "$D/gcc" || exit 9

for f in $(cat "$LIST"); do
  src=$W/gcc/$f
  [ -f "$src" ] || { echo "FATAL: missing $src"; exit 9; }
  case $f in
    config/glibc-c.cc|config/host-linux.cc|config/i386/driver-i386.cc)
        cmd=$CMD_SHARED; base=shared ;;
    config/aarch64/*|config/arm/aarch-*)
        cmd=$CMD_A64;    base=aarch64-inc ;;
    *)  cmd=$CMD_I386;   base=i386-inc ;;
  esac

  cp "$src" "$SAVE"
  $cmd -c "$src" -o /dev/null > "$W/wk/p.out" 2> "$W/wk/p.err"; rc1=$?

  # Delete the include, and ASSERT the deletion happened.  A sed that matched
  # nothing would make every file look vestigial -- an all-green read is
  # exactly what a broken injection produces.
  sed -i '/^# *include *"tm\.h"/d' "$src"
  if grep -q '^# *include *"tm\.h"' "$src"; then
    cp "$SAVE" "$src"; echo "FATAL: cut did not remove the include in $f"; exit 9
  fi
  $cmd -c "$src" -o /dev/null > "$W/wk/p2.out" 2> "$W/wk/p2.err"; rc2=$?
  cp "$SAVE" "$src"

  if [ $rc1 != 0 ]; then v=UNCHECKABLE
  elif [ $rc2 = 0 ]; then v=VESTIGIAL
  else v=NEEDS
  fi
  printf '%-11s %-12s %s\n' "$v" "$base" "$f" >> "$OUT"
done

echo "--- tally"
awk '{print $1}' "$OUT" | sort | uniq -c
