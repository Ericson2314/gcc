#!/bin/sh
# Task #24, the BOTH-SIDED arm: give the two targets DIFFERENT tool_include_dir
# values and show each gets its own -- not the other's, and not one shared one.
#
# One-sided evidence ("x86_64 gets x86_64's directory") cannot tell a fix from
# "everyone now gets the same new answer", which is the exact defect being
# fixed, so both columns are printed and cross-checked.
#
# Three arms per target, the same three fixed_include_dir carries:
#   absent   -- key not in the config file at all -> built-in "" -> no entry
#   verbatim -- key present -> that exact path appears in the search list
#   searched -- a header that exists ONLY there is actually found
set -u
B=${B:-/tmp/b24-after}
TMP=$(mktemp -d)
X=/tmp/t24-tid-x86
A=/tmp/t24-tid-a64
mkdir -p "$X" "$A"
printf '#define T24_WHICH "x86-tool-include-dir"\n' > "$X/t24which.h"
printf '#define T24_WHICH "a64-tool-include-dir"\n' > "$A/t24which.h"

pick () { case $1 in x86_64-pc-linux-gnu) echo "$X";; *) echo "$A";; esac; }
other () { case $1 in x86_64-pc-linux-gnu) echo "$A";; *) echo "$X";; esac; }

printf '#include <t24which.h>\nconst char *f (void) { return T24_WHICH; }\n' \
  > "$TMP/e.c"

for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  base="$B/gcc/specs-$t-config"
  [ -f "$base" ] || { echo "FATAL: no $base"; exit 9; }
  mine=$(pick "$t"); theirs=$(other "$t")

  # --- arm 1: key ABSENT (the shipped config file has no tool_include_dir)
  if grep -q '^tool_include_dir' "$base"; then
    echo "FATAL: $base already has tool_include_dir; the 'absent' arm is vacuous"
    exit 9
  fi
  n=$("$B/gcc/cc1" -quiet -v -ftarget-config="$base" -fsyntax-only "$TMP/e.c" 2>&1 \
        | sed -n '/#include <\.\.\.>/,/End of search/p' | grep -c 't24-tid')
  echo "$t  absent:   $n t24-tid entries in the search list (want 0)"

  # --- arm 2 + 3: key PRESENT, this target's own directory
  cfg="$TMP/cfg-$t"
  cp "$base" "$cfg"
  echo "tool_include_dir $mine" >> "$cfg"
  echo "$t  verbatim: $("$B/gcc/cc1" -quiet -v -ftarget-config="$cfg" -fsyntax-only "$TMP/e.c" 2>&1 \
        | sed -n '/#include <\.\.\.>/,/End of search/p' | grep 't24-tid' | tr -d ' ' | tr '\n' ' ')"
  if "$B/gcc/cc1" -quiet -ftarget-config="$cfg" -fsyntax-only "$TMP/e.c" \
       > "$TMP/o" 2> "$TMP/e"; then
    got=$("$B/gcc/cc1" -quiet -E -ftarget-config="$cfg" "$TMP/e.c" 2>/dev/null \
          | grep -o '"[a-z0-9-]*-tool-include-dir"')
    echo "$t  searched: found t24which.h saying $got"
    case "$got" in
      *"$(basename "$mine" | sed 's/t24-tid-//')"*) : ;;
      *) echo "$t  MISMATCH: got $got but its directory is $mine"; exit 1 ;;
    esac
  else
    echo "$t  searched: NOT FOUND -- $(head -1 "$TMP/e")"; exit 1
  fi

  # --- negative control: the OTHER target's directory must not be reachable
  m=$("$B/gcc/cc1" -quiet -v -ftarget-config="$cfg" -fsyntax-only "$TMP/e.c" 2>&1 \
        | sed -n '/#include <\.\.\.>/,/End of search/p' | grep -c "$theirs")
  echo "$t  control:  $m entries naming the other target's dir $theirs (want 0)"
done
rm -rf "$TMP"
