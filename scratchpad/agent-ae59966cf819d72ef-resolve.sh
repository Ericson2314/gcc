#!/bin/sh
# Union-resolve the three add/add conflicts of the agent-a4568de8f522450d3-mt
# merge: every hunk is a block APPENDED by each side (struct members, #includes,
# case arms), so both sides must survive.  Base section (diff3 `|||||||' arm) is
# dropped, which is correct only because it is EMPTY in every hunk -- asserted.
set -e
for f in gcc/target-cumargs.cc gcc/target-cumargs-select.cc gcc/target-frame.h; do
  awk -v F="$f" '
    /^<<<<<<< /   { inbase=0; next }
    /^\|\|\|\|\|\|\| / { inbase=1; next }
    /^=======$/   { inbase=0; next }
    /^>>>>>>> /   { next }
    inbase        { nb++; print "FATAL: non-empty base in " F ": " $0 > "/dev/stderr"; next }
                  { print }
    END { if (nb) exit 9 }
  ' "$f" > "$f.resolved"
  mv "$f.resolved" "$f"
done
echo "resolved; remaining markers:"
grep -c '^<<<<<<< \|^>>>>>>> ' gcc/target-cumargs.cc gcc/target-cumargs-select.cc gcc/target-frame.h || true
