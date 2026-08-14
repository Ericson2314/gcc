#!/bin/sh
# #155 -- SOURCE-level N-way collision census over gcc/config/.
#
# WHY THIS EXISTS ALONGSIDE THE nm SWEEP.  `nm' over built objects is the
# authority, but it can only be run after a build that gets that far, and it
# cannot distinguish "this back end never compiled" from "this back end defines
# nothing".  Under `make -k' those are the same silence (PRINCIPLES section 1).
# This reads the SOURCE, so its population does not depend on what built.
#
# It is deliberately OVER-BROAD in one direction and exact in the other: it can
# only NOMINATE a name for the rename list, never authorise removing one.
# ("When an instrument can only take away, make it too eager; when it can
# grant, make it exact.")
#
# GNU style puts the declarator at column 0 with the return type on the line
# above, so `static' is on the PREVIOUS line.  That distinction is the entire
# difference between a collision and a non-collision: arm.cc and i386.cc both
# spell extract_base_offset_in_addr and neither collides, because both are
# `static'.  Two agents got that population wrong.
#
# usage: t155-census.sh   -> writes t155-census.txt to stdout
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
[ -d "$G/config" ] || { echo "FATAL: $G/config missing"; exit 9; }

tmp=${TMPDIR:-/tmp}/t155-census.$$
: > "$tmp"
nf=0
for f in "$G"/config/*/*.cc "$G"/config/*/*.c; do
  [ -f "$f" ] || continue
  nf=$((nf + 1))
  be=$(basename "$(dirname "$f")")
  awk -v BE="$be" -v F="$f" '
    # A definition: identifier at column 0 followed by an open paren, an open
    # bracket or an equals sign.  Exclude a method (already namespaced by its
    # class) and anything whose previous line makes it static.
    #
    # NB: no backticks anywhere in this awk program.  The awk text sits inside
    # a double-quoted shell word, so a backtick in a COMMENT is still command
    # substitution -- PRINCIPLES section 5, and it bit this script on its first
    # run with "syntax error near unexpected token".
    # The bracket expression is spelled [(=[] and NOT [([=]: the latter puts
    # "[" immediately before "=", which POSIX reads as the start of a
    # collating-element [= =].  gawk then errors "invalid collating element"
    # ONCE PER FILE and matches nothing -- i.e. it reports zero collisions,
    # which is the answer that reads as success.  The non-vacuity arm below is
    # the only reason this was caught rather than banked.
    /^[A-Za-z_][A-Za-z0-9_]*[ \t]*[(=[]/ {
      name = $0; sub(/[ \t]*[(=[].*$/, "", name);
      if (prev !~ /(^|[ \t])static([ \t]|$)/ && name !~ /::/)
        printf "%s %s %s:%d\n", name, BE, F, NR;
    }
    { prev = $0 }' "$f" >> "$tmp"
done
# NON-VACUITY FIRST (PRINCIPLES: "the harness must refuse to score when it
# cannot show it read anything at all").  An empty read here looks exactly like
# "no collisions", which is the answer this script would most like to give.
n=$(grep -c . "$tmp" || true)
[ "$nf" -gt 100 ] || { echo "REFUSING TO SCORE: only $nf source files"; rm -f "$tmp"; exit 9; }
[ "$n" -gt 100 ] || { echo "REFUSING TO SCORE: only $n candidate definitions"; rm -f "$tmp"; exit 9; }
echo "arm 0 ok: $nf sources, $n non-static column-0 definitions" >&2

# A name collides when it is defined in MORE THAN ONE back-end DIRECTORY.
# Per directory, not per file: rs6000 defines a name in rs6000.cc and again in
# rs6000-c.cc and that is one back end, not a collision.
sort -u -k1,2 "$tmp" | awk '{ print $1, $2 }' | sort -u \
  | awk '{ c[$1]++; d[$1] = d[$1] " " $2 } END { for (n in c) if (c[n] > 1) printf "%3d %s %s\n", c[n], n, d[n] }' \
  | sort -rn
rm -f "$tmp"
