#!/bin/sh
# WHICH GENERATED PER-BASE MACROS ACTUALLY DIFFER ACROSS THE CONFIGURED BACK
# ENDS -- the residual sweep for the bound-as-SIZE-vs-as-PREDICATE class after
# NUM_INT_N_ENTS.  Every such name is a candidate, because the BUILD ROOT's
# copy of the same header is the PRIMARY's and is what every shared
# translation unit reads.
#
# READ THIS BEFORE TRUSTING A NUMBER FROM IT.  Two earlier versions of this
# script reported **640** divergent names in `insn-modes', which contradicts
# PRINCIPLES' measured "the whole divergence is five names".  PRINCIPLES was
# right and the script was wrong, twice, in the matched-too-much direction:
#
#   * v1 collected `name<TAB>body' over all 47 files and took `uniq -d' on the
#     names.  But EVERY mode name is defined TWICE inside EACH file, once
#     under `#ifdef USE_ENUM_MODES' and once under the `#else' -- so every
#     mode name has two bodies before any comparison between bases happens.
#   * v2 "fixed" it with a per-FILE `sort -u', which removes duplicate
#     (name, body) PAIRS and therefore does not collapse two DIFFERENT bodies
#     of one name at all.  Same 640.
#
# Neither was visible from the output: a list of 640 plausible mode names
# reads exactly like a finding.  It was caught by printing one name's bodies
# and seeing 47 of each -- i.e. the split was 1-per-file, not between bases.
#
# So this script does the direct thing instead, which is also what settles it:
# `diff' whole headers pairwise and name the lines that differ.  A whole-file
# diff cannot be fooled by how many times a name appears.
set -u
D=${1:-/tmp/b-a3cea52a56e315ee4}/gcc
cd "$D" || exit 1

names () {   # differing #define names between two headers
  diff "$1" "$2" | grep '^[<>]' \
    | grep -o 'define [A-Za-z_][A-Za-z0-9_]*' | sed 's/define //' | sort -u
}

for stem in insn-modes insn-constants insn-config; do
  base=$(ls ${stem}-*.h 2>/dev/null | grep -v -- '-inline' | head -1)
  [ -n "$base" ] || { echo "=== $stem: no per-base headers"; continue; }
  echo "=== $stem   (reference: $base)"
  all=""
  for f in $(ls ${stem}-*.h | grep -v -- '-inline'); do
    [ "$f" = "$base" ] && continue
    n=$(names "$base" "$f" | tr '\n' ' ')
    [ -n "$n" ] && echo "  vs $f: $n"
    all="$all $n"
  done
  echo "  UNION of differing names: $(echo $all | tr ' ' '\n' | sort -u | tr '\n' ' ')"
done
