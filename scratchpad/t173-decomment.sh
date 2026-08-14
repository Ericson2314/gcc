#!/bin/sh
# #173 -- delete the repeated two-line rationale comment from gcc/config/.
#
# User's ruling: *"you can remove those comments -- and just use scratchpad for
# that."*  Thirty copies of one paragraph is the same one-fact-several-
# authorities shape the project exists to remove, and it makes
# `git grep -- '-I.*-inc'` return prose instead of uses.  The rationale is in
# scratchpad/T173-BASE-HEADER.md, referenced from gcc/multi-target-base.h.
#
# Deletes exactly the two-line block
#     /* Compiled once per configured back end: name the back end's own
#        <stem>.h rather than relying on -I<base>-inc.  See multi-target-base.h.  */
# and any one-line variant carrying the same sentence.  Nothing else.
set -e
cd "$(dirname "$0")/.."
n=0
for f in $(git grep -l 'rather than relying on -I' -- gcc/config); do
  awk '
    # Buffer a comment-opening line so it can be dropped with its sequel.
    /^\/\* Compiled once per configured back end: name the back end.s own$/ {
      held = $0; next
    }
    /rather than relying on -I<base>-inc\.  See multi-target-base\.h\.  \*\/$/ {
      held = ""; next
    }
    { if (held != "") { print held; held = "" } print }
    END { if (held != "") print held }
  ' "$f" > "$f.t173" && mv "$f.t173" "$f"
  n=$((n + 1))
done
echo "de-commented $n file(s)"
left=$(git grep -l -- '-I<base>-inc' -- gcc/config | wc -l)
echo "gcc/config files still mentioning -I<base>-inc: $left"
