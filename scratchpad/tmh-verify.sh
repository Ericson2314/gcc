#!/bin/sh
# Post-change verification, per file, with the same command lines probe.sh used.
#
# It must be able to FAIL: the 51 UNCHECKABLE files are still expected to fail
# to compile, so a run in which everything passes would mean the harness had
# stopped compiling anything.  The tally is therefore checked against the
# classification, not merely reported.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
D=${D:?set D to YOUR OWN build dir -- never /tmp/b<task number>, which collides by construction}
tmpl () {
  grep -m1 -- "$1" "$W/wk/build.out" \
    | sed -e 's/ -o [^ ]*\.o / /' -e 's/ -MT [^ ]*//' -e 's/ -MMD -MP//' \
          -e 's/ -MF [^ ]*//' -e 's| /home[^ ]*\.cc$||'
}
CMD_I386=$(tmpl '\-o mt-i386/linux\.o ')
CMD_A64=$(tmpl '\-o mt-aarch64/linux\.o ')
CMD_SHARED=$(tmpl '\-o glibc-c\.o ')
cd "$D/gcc" || exit 9
OUT=$W/wk/verify-results.txt
: > "$OUT"
for f in $(cat "$W/wk/tmh-config.txt"); do
  src=$W/gcc/$f
  case $f in
    config/glibc-c.cc|config/host-linux.cc|config/i386/driver-i386.cc) cmd=$CMD_SHARED ;;
    config/aarch64/*|config/arm/aarch-*) cmd=$CMD_A64 ;;
    *) cmd=$CMD_I386 ;;
  esac
  $cmd -c "$src" -o /dev/null > /dev/null 2> "$W/wk/v.err"
  printf '%-4s %s\n' "$([ $? = 0 ] && echo OK || echo FAIL)" "$f" >> "$OUT"
done
awk '{print $1}' "$OUT" | sort | uniq -c
echo "--- files that changed verdict vs the pre-change probe"
join -j2 -o 0,1.1,2.1 \
  <(sort -k2 "$W/wk/probe-results.txt" | awk '{print $1, $3}' | sort -k2) \
  <(sort -k2 "$OUT") 2>/dev/null | awk '
    { want = ($2 == "UNCHECKABLE") ? "FAIL" : "OK" }
    $3 != want { print "CHANGED", $0; bad++ }
    END { printf "%d verdict changes (expected 0)\n", bad+0 }'
