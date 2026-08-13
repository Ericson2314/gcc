#!/bin/sh
# For each NEEDS file, print the FIRST error the cut produces -- i.e. what the
# tm.h include is actually buying.  A verdict without this is a claim; the
# error names the macro.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
D=${D:?set D to YOUR OWN build dir -- never /tmp/b<task number>, which collides by construction}
SAVE=$W/wk/save2.cc
tmpl () {
  grep -m1 -- "$1" "$W/wk/build.out" \
    | sed -e 's/ -o [^ ]*\.o / /' -e 's/ -MT [^ ]*//' -e 's/ -MMD -MP//' \
          -e 's/ -MF [^ ]*//' -e 's| /home[^ ]*\.cc$||'
}
CMD_I386=$(tmpl '\-o mt-i386/linux\.o ')
CMD_A64=$(tmpl '\-o mt-aarch64/linux\.o ')
CMD_SHARED=$(tmpl '\-o glibc-c\.o ')
cd "$D/gcc" || exit 9
awk '$1=="NEEDS"{print $3}' "$W/wk/probe-results.txt" | while read -r f; do
  src=$W/gcc/$f
  case $f in
    config/i386/driver-i386.cc) cmd=$CMD_SHARED ;;
    config/aarch64/*|config/arm/aarch-*) cmd=$CMD_A64 ;;
    *) cmd=$CMD_I386 ;;
  esac
  cp "$src" "$SAVE"
  sed -i '/^# *include *"tm\.h"/d' "$src"
  $cmd -c "$src" -o /dev/null > /dev/null 2> "$W/wk/w.err"
  cp "$SAVE" "$src"
  printf '%s\n    %s\n' "$f" "$(grep -m1 'error:' "$W/wk/w.err")"
done
