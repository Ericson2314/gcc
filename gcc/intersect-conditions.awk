# Copyright (C) 2026 Free Software Foundation, Inc.
#
# This file is part of GCC.
#
# GCC is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3, or (at your option) any later
# version.
#
# GCC is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with GCC; see the file COPYING3.  If not see
# <http://www.gnu.org/licenses/>.

# Reduce several triples' insn-conditions files, all for ONE back end, to the
# conditions that hold for every one of them:
#
#	awk -f intersect-conditions.awk cond-T1.md cond-T2.md ... > cond.md
#
# A condition keeps its constant only where every triple agrees; where they
# disagree, or any one of them says -1, the answer is -1 -- unknown, decide at
# run time.
#
# WHY THIS EXISTS.  gencondmd evaluates each condition against a tm.h, and a
# back end serving many triples has no single tm.h: `tm-<base>.h' is built from
# whichever triple configure happened to list first.  Folding against it would
# record one arbitrary triple's OS and ABI choices for all of them -- and since
# gensupport elides patterns whose condition is provably false, that does not
# merely bake a wrong constant, it deletes patterns.  sparc's TARGET_ARCH32 and
# i386's TARGET_MACHO are the examples that made it visible.
#
# Not folding at all is not an option either: gcn's
# vec_extract<V_1REG:mode><V_1REG_ALT:mode>_nop uses its condition as the
# filter over a two-iterator cross product, so genrecog rejects gcn's machine
# description outright unless the invariant part is folded.
#
# The two are separable, which is what this script is for.  gcn's conditions
# are mode arithmetic and are invariant across gcn's triples, so they still
# fold; TARGET_ARCH32 varies across sparc's triples, so it does not.
#
# DEGRADES SAFELY.  Every failure direction of this script yields -1, i.e. the
# condition is left to run time exactly as if it had never been folded.  It
# cannot turn an unknown into a constant.

# WHY A POSITIONAL MERGE IS SAFE.  Every triple of a back end reads the same
# machine description, and gencondmd walks its condition table in insertion
# order, so the files agree line for line and differ only in the leading value.
# That is a property worth checking rather than trusting: if the payload text
# of any line differs, or the files are different lengths, we stop rather than
# silently pair up unrelated conditions.

FNR == 1 {
  nfile++
  if (nfile == 1)
    first = FILENAME
  nline = 0
}

{
  nline++
  if (nfile == 1) {
    line[nline] = $0
    val[nline] = value_of($0)
    text[nline] = text_of($0)
    maxline = nline
    next
  }
  if (nline > maxline) {
    printf "%s: %s is longer than %s\n", progname, FILENAME, first > "/dev/stderr"
    bad = 1
    exit 1
  }
  if (text_of($0) != text[nline]) {
    printf "%s: %s:%d: condition text differs from %s:%d\n",
	   progname, FILENAME, FNR, first, nline > "/dev/stderr"
    bad = 1
    exit 1
  }
  v = value_of($0)
  if (v != val[nline])
    val[nline] = "-1"
  seen[nline] = 1
}

END {
  if (bad)
    exit 1
  if (nfile > 1 && nline != maxline) {
    printf "%s: %s is shorter than %s\n", progname, FILENAME, first > "/dev/stderr"
    exit 1
  }
  for (i = 1; i <= maxline; i++)
    if (val[i] == "")
      print line[i]
    else
      printf "  (%s %s\n", val[i], text[i]
}

BEGIN { progname = "intersect-conditions" }

# A condition entry is `  (VALUE "text...' and may run over several lines;
# only the first line of one carries a value.
function value_of(s) {
  if (s ~ /^  \(-?[0-9]+ "/) {
    sub(/^  \(/, "", s)
    sub(/ .*/, "", s)
    return s
  }
  return ""
}

function text_of(s) {
  if (s ~ /^  \(-?[0-9]+ "/) {
    sub(/^  \(-?[0-9]+ /, "", s)
    return s
  }
  return s
}
