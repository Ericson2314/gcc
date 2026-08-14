#!/bin/sh
# #163 -- classify every HAVE_AS_TLS site by BACK END and by SHAPE.
#
# The shape is what decides the fix, because the POSITION OF USE decides what a
# runtime value may be spelled as:
#
#   PP-EXIST   `#ifdef' / `#ifndef' / `#if defined(...)' -- asks whether the
#              macro EXISTS.  A runtime value cannot appear here at all; the
#              site has to be restructured (the gas_lcomm_with_alignment shape:
#              define unconditionally, branch at the call site).
#   PP-VALUE   `#if HAVE_AS_TLS' -- asks for its VALUE on a preprocessor line.
#              Also impossible for a runtime value, same restructuring.
#   MD-COND    an insn condition in a .md file.  gencondmd emits
#              `__builtin_constant_p(e) ? (int)e : -1', so a NON-constant
#              condition is legal and becomes a run-time test -- but the
#              expression must still COMPILE inside build/gencondmd.cc, which
#              is built -DGENERATOR_FILE, where defaults.h guards target-caps.h
#              out.  That, not folding, is the real blocker.
#   C-VALUE    ordinary C++ value position.  Converts with no restructuring.
#
# PRINCIPLES section 7: non-vacuity FATAL -- refuse to score when the greps read
# nothing, because an all-empty read is indistinguishable from "no sites".
set -e
cd "$(dirname "$0")/.."

RAW=$(grep -rn '\bHAVE_AS_TLS\b' gcc/ \
        | grep -v '/ChangeLog' | grep -v 'CONFIGURE-HISTORY' \
        | grep -v '^gcc/configure:' )
[ -n "$RAW" ] || { echo "FATAL: no HAVE_AS_TLS sites read at all"; exit 9; }
nraw=$(printf '%s\n' "$RAW" | grep -c .)
[ "$nraw" -ge 40 ] || { echo "FATAL: only $nraw sites, expected >=40"; exit 9; }

echo "== $nraw non-ChangeLog HAVE_AS_TLS sites =="
echo

printf '%s\n' "$RAW" | awk -F: '
{
  file=$1; line=$2; $1=""; $2=""; txt=substr($0,3)
  # back end = the directory under gcc/config/, else "shared"
  be="(shared)"
  if (file ~ /^gcc\/config\//) { split(file,a,"/"); be=a[3]; if (be ~ /\./) be="(config)" }
  shape="C-VALUE"
  if (file ~ /\.md$/)                       shape="MD-COND"
  else if (txt ~ /^[ \t]*#[ \t]*(ifdef|ifndef)/)  shape="PP-EXIST"
  else if (txt ~ /^[ \t]*#[ \t]*if.*defined/)     shape="PP-EXIST"
  else if (txt ~ /^[ \t]*#[ \t]*(if|elif)/)       shape="PP-VALUE"
  else if (txt ~ /^[ \t]*#[ \t]*(undef|endif)/)   shape="PP-OTHER"
  else if (txt ~ /^[ \t]*#[ \t]*define/)          shape="C-VALUE(define)"
  key=be" "shape
  cnt[key]++; bes[be]++; shapes[shape]++
}
END{
  printf "%-14s %-16s %s\n","BACK END","SHAPE","SITES"
  for (k in cnt) print k, cnt[k]
}' | (read -r h1 h2 h3; echo "$h1 $h2 $h3"; sort) | awk 'NR==1{print;next}{printf "%-14s %-16s %s\n",$1,$2,$3}'

echo
echo "== shape totals =="
printf '%s\n' "$RAW" | awk -F: '
{
  file=$1; $1=""; $2=""; txt=substr($0,3)
  shape="C-VALUE"
  if (file ~ /\.md$/)                       shape="MD-COND"
  else if (txt ~ /^[ \t]*#[ \t]*(ifdef|ifndef)/)  shape="PP-EXIST"
  else if (txt ~ /^[ \t]*#[ \t]*if.*defined/)     shape="PP-EXIST"
  else if (txt ~ /^[ \t]*#[ \t]*(if|elif)/)       shape="PP-VALUE"
  else if (txt ~ /^[ \t]*#[ \t]*(undef|endif)/)   shape="PP-OTHER"
  else if (txt ~ /^[ \t]*#[ \t]*define/)          shape="C-VALUE(define)"
  s[shape]++
}
END{ for (k in s) printf "  %-16s %d\n", k, s[k] }' | sort -k2 -rn

echo
echo "== distinct back ends touched =="
printf '%s\n' "$RAW" | awk -F: '$1 ~ /^gcc\/config\//{split($1,a,"/"); if (a[3] !~ /\./) print a[3]}' | sort -u | tr '\n' ' '
echo
printf '%s\n' "$RAW" | awk -F: '$1 ~ /^gcc\/config\//{split($1,a,"/"); if (a[3] !~ /\./) print a[3]}' | sort -u | grep -c . | sed 's/^/  count: /'
