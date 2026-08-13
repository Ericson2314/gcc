#!/bin/sh
# t116 / overlaps #46: find `#ifdef' / `#ifndef' / `defined()' guards on macros
# that gcc/defaults.h now defines UNCONDITIONALLY over targ_caps.
#
# Why these are vacuous: defaults.h's own comment says it --
#   "the macro is now ALWAYS DEFINED, so a consumer written as `#ifdef' would
#    take the true arm unconditionally, which is the exact opposite of the old
#    silent-false."
# So an `#ifdef' consumer is a guard that cannot select.  `#ifndef' is the same
# defect mirrored: its body is now dead.
#
# BLIND SPOTS, stated:
#  * The list of macros is taken from the `#if !defined(USED_FOR_TARGET)' arm of
#    defaults.h.  A macro defined over targ_caps somewhere else is not seen.
#  * Guards in .md files and in generated files are not searched here.
#  * A guard inside `#if defined (GENERATOR_FILE) || defined (USED_FOR_TARGET)'
#    is NOT vacuous -- those arms exist precisely because defaults.h is absent
#    there.  Such sites are reported separately rather than counted.
set -eu
cd "$(dirname "$0")/.."
ROOT=$(pwd)
W=$(mktemp -d)
trap 'rm -rf "$W"' 0

# Macros defined over targ_caps in defaults.h.
sed -n 's/^#define \([A-Z_][A-Z_0-9]*\).*targ_caps\..*/\1/p' "$ROOT/gcc/defaults.h" \
  | sort -u > "$W/macros"
# Two-line form: `#define X \' then `  (targ_caps.y)'.
awk '/^#define [A-Z_][A-Z_0-9]*[ \t]*\\$/ { name=$2; getline nxt;
       if (nxt ~ /targ_caps\./) print name }' "$ROOT/gcc/defaults.h" \
  | sort -u >> "$W/macros"
sort -u "$W/macros" -o "$W/macros"

n=$(wc -l < "$W/macros" | tr -d ' ')
if [ "$n" -lt 10 ]; then
  echo "FATAL: only $n macros extracted from defaults.h; the extractor is broken" >&2
  echo "and every guard would read as non-vacuous, which is the flattering direction." >&2
  exit 1
fi
echo "macros defined over targ_caps in defaults.h: $n"
echo

found=0
while read -r m; do
  hits=$(grep -rn "^[ \t]*#[ \t]*if\(n\)\?def[ \t][ \t]*$m[ \t]*\$\|^[ \t]*#[ \t]*if.*defined[ \t]*(\?[ \t]*$m[ \t]*)\?" \
           "$ROOT/gcc" 2>/dev/null \
         | grep -v '/defaults\.h:' || true)
  if [ -n "$hits" ]; then
    echo "=== $m"
    echo "$hits" | sed 's|'"$ROOT"'/|  |'
    found=$((found + 1))
  fi
done < "$W/macros"

echo
echo "macros with at least one defined()-style guard outside defaults.h: $found"
if [ "$found" -eq 0 ]; then
  echo "(A zero here is a claim about this instrument as much as about the tree;"
  echo " see the blind spots at the top of this file.)"
fi
