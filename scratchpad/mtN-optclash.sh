#!/bin/sh
# THE WHOLE DISTRIBUTION of options-union member collisions, not the first one.
#
# opth-gen.awk stops at the FIRST `member X declared twice, differently'.  With
# 48 back ends that turns a class of N collisions into N sequential build
# failures, each looking like a fresh bug.  This reads the same union list and
# reports every colliding member, with which back ends declare it and how many
# distinct declarations exist -- so the question becomes "how many collisions
# are there and what shape are they" rather than "what is the next one".
#
# Keyed exactly as opth-gen.awk keys it: `F'-kind records live in their own
# namespace, everything else shares one.  Getting that wrong would either
# invent collisions (merging the two namespaces) or hide them.
#
# usage: mtN-optclash.sh <gcc-options-union.list>
set -e
U=${1:?union list}
[ -s "$U" ] || { echo "FATAL: $U missing or empty"; exit 9; }

awk -F'\t' '
# NOTE: this comment is INSIDE a single-quoted awk program, so it must not
# contain an apostrophe -- one here closes the quote and the shell reports a
# syntax error somewhere else entirely.  (It did.)
#
# The "base <name>" line is SPACE separated while every record line is
# TAB separated, so $2 under -F"\t" is empty on it and every back end would be
# reported as "".  Split it again on whitespace.  This was measured, not
# assumed: the first version printed "first=  clashing=" for the one real
# collision, which reads as "no back end declares it" -- an empty answer being
# mistaken for an answer.
/^base /{ split($0, bf, /[ \t]+/); base = bf[2]; nbase++; next }
$1=="V" || $1=="O" || $1=="S" || $1=="F" {
  key = ($1=="F" ? "F" : "X") SUBSEP $2
  name[key] = $2
  kind[key] = $1
  if (!(key in text)) { text[key] = $3; owners[key] = base; ndecl[key] = 1; next }
  if (text[key] == $3) {
    # same declaration from another base is fine and is the normal case
    if (index(" " owners[key] " ", " " base " ") == 0) owners[key] = owners[key] " " base
    next
  }
  # a genuinely different declaration under the same name
  if (index(" " variants[key] " ", " " base " ") == 0) variants[key] = variants[key] " " base
  ndecl[key]++
}
END {
  if (nbase == 0) { print "FATAL: no base lines -- not a union list"; exit 9 }
  n = 0
  for (k in ndecl) if (ndecl[k] > 1) {
    n++
    printf "%s\t%s\tdecls=%d\tfirst=%s\tclashing=%s\n", kind[k], name[k], ndecl[k], owners[k], variants[k]
  }
  printf "\n%d bases read, %d colliding members\n", nbase, n
}
' "$U" | sort
