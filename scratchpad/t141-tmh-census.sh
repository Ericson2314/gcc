#!/bin/sh
# t141: census of which gcc/ TUs reach tm.h, and through which shared header.
#
# INSTRUMENT: source-level transitive closure over quoted #include edges.
# Deliberately independent of any build dir, per PRINCIPLES rule 6 ("sweep the
# source, not the build output" -- ~186 targets are never built).
#
# BLIND SPOTS, stated up front:
#  - angle-bracket includes are NOT followed (system headers; none reach tm.h)
#  - includes inside #if blocks are followed unconditionally (OVER-broad:
#    this instrument can only ADD reachers, never remove them, which is the
#    safe direction -- it authorises no deletion)
#  - generated headers (insn-*.h, options.h, ...) are absent from the source
#    tree, so edges through them are invisible.  See ARM G.
set -e

SRC=$(cd "$(dirname "$0")/.." && pwd)
# Assert we are measuring THIS tree, by content anchor (PRINCIPLES sec 4).
WANT_ANCHOR=${WANT_ANCHOR:-47}
GOT=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")
if [ "$GOT" != "$WANT_ANCHOR" ]; then
  echo "FATAL: anchor mismatch: gcc/Makefile.in has $GOT MULTI_TARGET hits, want $WANT_ANCHOR" >&2
  echo "       (this tree is not the one the task targets; git reset --hard multi-target)" >&2
  exit 9
fi
echo "# tree: $SRC  anchor=$GOT"

cd "$SRC/gcc"

# --- header index: relative path -> exists.  Used to resolve quoted includes.
find . -name '*.h' -o -name '*.def' | sed 's|^\./||' | sort > /tmp/t141-hdrs.$$

# --- TU list: every .cc/.c under gcc/, excluding testsuite (plugins are not
#     part of the compiler) but INCLUDING config/, ada/, d/, m2/, rust/ ...
find . -name '*.cc' -o -name '*.c' | sed 's|^\./||' | grep -v '^testsuite/' | sort > /tmp/t141-tus.$$

awk -v HDRS=/tmp/t141-hdrs.$$ -v TUS=/tmp/t141-tus.$$ '
BEGIN {
  while ((getline l < HDRS) > 0) exists[l] = 1
  n = 0
  while ((getline l < TUS) > 0) tus[++n] = l
}
# resolve a quoted include NAME appearing in file F, GCC-style: including
# file own directory first, then the -I list.
function resolve(f, name,   d, c, i, cands) {
  d = f; sub(/\/[^\/]*$/, "", d); if (d == f) d = "."
  cands[1] = (d == "." ? name : d "/" name)
  cands[2] = name
  cands[3] = "config/" name
  cands[4] = "../include/" name
  cands[5] = "../libcpp/include/" name
  for (i = 1; i <= 5; i++) { c = cands[i]; gsub(/\/\.\//, "/", c); if (c in exists) return c }
  return ""
}
# parse a file once, caching its quoted-include edge list
function edges(f,   line, r, out, cmd) {
  if (f in ecache) return ecache[f]
  out = ""
  while ((getline line < f) > 0) {
    if (line ~ /^[ \t]*#[ \t]*include[ \t]*"/) {
      r = line; sub(/^[ \t]*#[ \t]*include[ \t]*"/, "", r); sub(/".*$/, "", r)
      out = out " " r
    }
  }
  close(f)
  ecache[f] = out
  return out
}
# DFS from START; sets global hit=1 if tm.h reached, and records the
# FIRST-HOP header (direct child of START) through which it was reached.
function dfs(f, start,   e, i, a, k, nm, res) {
  if (f in seen) return seen[f]
  seen[f] = 0            # cycle guard: assume no until proven
  res = 0
  k = split(edges(f), a, " ")
  for (i = 1; i <= k; i++) {
    nm = a[i]
    if (nm == "tm.h") { res = 1; via[f] = via[f] " tm.h(direct)"; continue }
    e = resolve(f, nm)
    if (e == "") continue
    if (dfs(e, start)) { res = 1; if (f == start) firsthop[nm] = 1 }
  }
  seen[f] = res
  return res
}
END {
  for (i = 1; i <= n; i++) {
    t = tus[i]
    delete seen; delete firsthop
    # direct include?
    direct = 0
    k = split(edges(t), a, " ")
    for (j = 1; j <= k; j++) if (a[j] == "tm.h") direct = 1
    r = dfs(t, t)
    if (!r && !direct) { printf "NONE\t%s\t-\n", t; continue }
    hops = ""
    for (h in firsthop) hops = hops (hops ? "," : "") h
    if (direct) hops = "DIRECT" (hops ? "," hops : "")
    printf "REACH\t%s\t%s\n", t, hops
  }
}
' > /tmp/t141-census.$$

# non-vacuity FATAL: refuse to score if we read nothing (PRINCIPLES sec 7)
NT=$(wc -l < /tmp/t141-census.$$)
NR_=$(wc -l < /tmp/t141-tus.$$)
if [ "$NT" -lt 100 ] || [ "$NT" != "$NR_" ]; then
  echo "FATAL: census produced $NT rows for $NR_ TUs -- instrument did not read the tree" >&2
  exit 8
fi

cp /tmp/t141-census.$$ "$SRC/scratchpad/t141-census.txt"
echo "# TUs scanned: $NR_"
echo "# reach tm.h : $(grep -c '^REACH' /tmp/t141-census.$$)"
echo "# do not     : $(grep -c '^NONE'  /tmp/t141-census.$$)"
echo "# --- first-hop breakdown (a TU may appear under several hops):"
cut -f3 /tmp/t141-census.$$ | grep -v '^-$' | tr ',' '\n' | sort | uniq -c | sort -rn
rm -f /tmp/t141-hdrs.$$ /tmp/t141-tus.$$ /tmp/t141-census.$$
