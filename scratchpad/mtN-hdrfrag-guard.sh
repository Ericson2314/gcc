#!/bin/sh
# EVERY t-<cpu>-headers FRAGMENT MUST DECLARE EVERYTHING IT GENERATES.
#
# gen-multi-target-md.awk's scan_hdr_frag reads `generated_files +=' and
# nothing else.  A fragment that carries rules without that line is invisible
# to it, so the headers get no dependant, and a rule nothing depends on is
# never run.  The artefact is missing while the rule is present -- which reads
# as a missing rule and is not.
#
# That gap was real in two fragments at once (arm, loongarch) and each cost a
# build.  This guard closes the class rather than the two instances.
#
# It compares, per fragment:
#   declared  -- the names on generated_files += lines
#   ruled     -- targets of rules in the fragment that look like build-directory
#                artefacts (no `/', and a generated-file suffix)
# and REFUSES if anything is ruled but not declared.
#
# Deliberately one-directional: declaring a name with no rule is somebody
# else's problem (make will say so by name), while ruling a name with no
# declaration is the silent one.
#
# Note `s-<something>' stamp targets and `.o' targets are NOT artefacts of this
# kind -- the stamps are internal to the fragment and the objects have their own
# rules elsewhere -- so they are excluded rather than reported as 40 false
# positives, which is what the first version of this did.
set -e
S=${1:-$(cd "$(dirname "$0")/../gcc" && pwd)}
[ -d "$S/config" ] || { echo "FATAL: $S/config is not a directory"; exit 9; }

frags=$(echo "$S"/config/*/t-*-headers)
[ -n "$frags" ] || { echo "FATAL: no t-<cpu>-headers fragments found"; exit 9; }

nfrag=0; nbad=0
for f in $frags; do
  [ -f "$f" ] || continue
  nfrag=$((nfrag + 1))
  declared=$(sed -n 's/^[ \t]*generated_files[ \t]*+=[ \t]*//p' "$f" | tr ' \t' '\n\n' | grep . | sort -u)
  ruled=$(sed -n 's/^\([A-Za-z0-9_.-]*\.\(h\|inc\|cc\|def\|gen\.def\)\)[ \t]*:.*/\1/p' "$f" | sort -u)
  for r in $ruled; do
    case "$r" in *.o) continue ;; esac
    if ! echo "$declared" | grep -x -- "$r" > /dev/null; then
      echo "MISSING: $f rules $r but does not declare it in generated_files"
      nbad=$((nbad + 1))
    fi
  done
done

echo "checked $nfrag fragments, $nbad undeclared generated files"
[ "$nfrag" -ge 9 ] || { echo "FATAL: only $nfrag fragments read; the glob is wrong"; exit 9; }
[ "$nbad" = 0 ] || exit 1
