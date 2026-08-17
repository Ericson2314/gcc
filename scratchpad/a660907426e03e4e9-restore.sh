#!/bin/sh
# RESTORE ONLY WHAT THE MERGE DROPPED -- and nothing else.
#
# `803794e7c6b' resolved three files by taking one side whole, so the tip has
# the CALL SITES of eight converted macros and none of their accessors, and
# `make all-gcc' dies in `c-cppbuiltin.o' on the first one it reaches.  A
# three-way re-merge (`-remerge.sh') produces six large conflicts because both
# sides did real work in these files; a `git checkout <old> -- <file>' would
# delete the other side's work outright (seven new externs, the
# `ASM_OUTPUT_ADDR_VEC_ELT' family -- which is the ONE fix on this branch that
# a 32-bit target most needs).
#
# So: take `git diff <good> HEAD' for each file, keep ONLY the hunks that are
# PURE DELETIONS (no `+' line at all), and apply that patch in REVERSE.  A pure
# deletion reversed is a pure insertion, so this can only ADD text back; it
# cannot touch a line the other side wrote.  That property is ASSERTED below,
# per hunk, rather than assumed -- a hunk with a `+' line in it would rewrite
# the other side's work silently, which is the failure this whole commit is
# about.
set -eu
GOOD=${GOOD:-05ea5c4a6db}
T=$(mktemp -d)
trap 'rm -rf "$T"' 0
for f in gcc/target-frame.h gcc/target-cumargs-select.cc gcc/target-cumargs.cc; do
  git diff "$GOOD" HEAD -- "$f" > "$T/full.diff"
  awk -v out="$T/one" '
    /^diff --git/ { hdr = $0; nh = 0; next }
    /^index |^--- |^\+\+\+ / { head[nh++] = $0; next }
    /^@@/ {
      if (n > 0) flushh()
      n = 0; hunk[n++] = $0; plus = 0; next
    }
    { if (n > 0) { hunk[n++] = $0; if (substr($0,1,1) == "+") plus++ } }
    END { if (n > 0) flushh() }
    function flushh(  i) {
      if (plus > 0) { printf "  SKIP (has %d + lines): %s\n", plus, hunk[0] > "/dev/stderr"; return }
      if (!wrote) { print hdr; for (i = 0; i < nh; i++) print head[i]; wrote = 1 }
      for (i = 0; i < n; i++) print hunk[i]
    }
  ' "$T/full.diff" > "$T/del.diff"
  if [ ! -s "$T/del.diff" ]; then echo "  $f: nothing to restore"; continue; fi
  # ARM: the filtered patch must contain no `+' line outside the `+++' header.
  bad=$(grep -c '^+' "$T/del.diff" || true)
  [ "$bad" = 1 ] || { echo "FATAL: $f patch has $bad '+' lines (expected exactly the +++ header)"; exit 9; }
  git apply -R --verbose "$T/del.diff" 2>&1 | sed 's/^/    /'
  echo "  $f: restored"
done
