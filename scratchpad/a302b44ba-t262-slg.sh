#!/bin/sh
# The manifest -> --with-shared-libgcc derivation in Makefile.tpl, both
# directions plus the absent-line case, run as the recipe runs it.
set -u
M=${1:?manifest}
fail=0
derive () { # derive <manifest> <target> ; echoes yes|no, or exits 1 with the message
  tfp=`awk -v t="$2" \
    '$1 == "target" { seen = ($2 == t) }
     seen && $1 == "tmake_file_present" { $1 = "PRESENT"; print; exit }' "$1"`
  test -n "$tfp" || { echo "ERROR-no-tmake_file_present-line"; return 1; }
  case " $tfp " in
    *" t-slibgcc "* ) echo yes ;;
    * ) echo no ;;
  esac
}
ck () { got=`derive "$2" "$3"`; if test "$got" = "$4"
  then echo "ok   $1: $3 -> $got"
  else echo "FAIL $1: $3 -> $got, want $4"; fail=`expr $fail + 1`; fi; }

W=${TMPDIR:-/tmp}/t262slg; rm -rf "$W"; mkdir -p "$W"

echo "--- real manifest: both targets HAVE t-slibgcc, so both must say yes"
for t in `awk '$1=="target"{print $2}' "$M"`; do
  ck real "$M" "$t" yes
done

echo "--- NEGATIVE direction: a target whose tmake_file_present has no t-slibgcc"
sed 's/^tmake_file_present  *t-slibgcc/tmake_file_present /' "$M" > "$W/nolibgcc"
# Vacuity guard on the LINE THIS READS only.  `tmake_file' (the unfiltered
# list) still mentions t-slibgcc and must -- grepping the whole file fired here
# and the negative arm was fine.
grep '^tmake_file_present' "$W/nolibgcc" | grep -q 't-slibgcc' && { echo "FAIL: doctoring left t-slibgcc in tmake_file_present -- the negative arm would be vacuous"; fail=`expr $fail + 1`; }
for t in `awk '$1=="target"{print $2}' "$W/nolibgcc"`; do
  ck neg "$W/nolibgcc" "$t" no
done

echo "--- ABSENT LINE is neither: it is an error, not a silent \`no'"
grep -v '^tmake_file_present' "$M" > "$W/noline"
for t in `awk '$1=="target"{print $2}' "$W/noline"`; do
  got=`derive "$W/noline" "$t"`
  if test "$got" = ERROR-no-tmake_file_present-line
  then echo "ok   absent: $t -> error"
  else echo "FAIL absent: $t -> $got, want the error"; fail=`expr $fail + 1`; fi
done

echo; echo "t262-slg: $fail FAIL"; test "$fail" -eq 0
