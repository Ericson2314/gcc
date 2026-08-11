#!/bin/sh
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
#
# Fail if a per-target config file carries a capability nothing reads.
#
# WHY.  This is the `targ_caps' half of check-spec-refs.sh, and it exists for
# the same failure, which has now happened four times:
#
#   --eh-frame-hdr / LINK_EH_SPEC   a channel a comment described and nobody built
#   *link_as_needed, *link_no_as_needed  written by target-specs, no driver slot
#   *link_plugin                    likewise
#   targ_caps.lto_plugin            probed, written into every config file, and
#                                   reachable only through a defaults.h macro
#
# Every one was silent.  read_target_caps ignores an unknown name on purpose --
# so that a newer spec file does not break an older compiler -- which means a
# key that no longer has a reader, or never had one, produces no diagnostic at
# any stage.  target-specs runs a real probe against a real assembler or linker
# to compute it, writes it into 183 files, and the answer is discarded.
#
# WHAT COUNTS AS A READER, and this is the whole difficulty.
#
#   1. `targ_caps.KEY' in ordinary code.  dwarf2out.cc, sol2.cc, aarch64.cc.
#   2. `targ_caps.KEY' inside a `#define' in defaults.h -- WHICH IS NOT A READER
#      BY ITSELF.  47 of the ~70 mentions in the tree are of this shape:
#      `#define HAVE_AS_LEB128 (targ_caps.leb128)'.  Counting those as reads
#      would make the check vacuous for the single largest reader file and, far
#      worse, would call the lto_plugin instance live: `#define HAVE_LTO_PLUGIN
#      (targ_caps.lto_plugin ? 2 : 0)' is exactly such a line, and the bug was
#      that nothing consumed the macro.  So a `#define' is an EDGE, not a use:
#      the key is reachable only if the macro it defines is itself reached.
#      Followed to a fixpoint, because macros are defined in terms of macros.
#   3. `targ_caps_target_name' for the `target' line, which names the
#      configuration rather than a capability and is read through its own
#      variable (common/common-target-select.cc, toplev.cc).  One alias, in a
#      table below, rather than a special case buried in the matcher.
#
# WHAT IS NOT CODE.  gcc/configure.ac mentions targ_caps SIXTEEN times and every
# one is inside `dnl' -- notes explaining where a configure probe went.
# Makefile.in mentions it three times and config.gcc once, all in `#' comments.
# If prose counted, `as_mips_dspr1_mult' and `as_mips_micromips' would read as
# live on the strength of two sentences describing the move that stranded them.
# That is not a hypothetical: it is what happened to check-spec-refs, whose own
# comment naming a spec made the check report that spec live no matter what the
# code did.  A prose mention is the single most likely thing to be written about
# a value nothing uses yet, so counting comments makes the check weakest exactly
# where the bug lives.  Comments are therefore stripped, PER LANGUAGE -- C for
# the sources, `dnl' for configure.ac, `#' for Makefile.in and config.gcc.
# Running the C stripper over configure.ac is not a harmless approximation:
# `/*)' there is a shell case pattern, and it opens a comment that never closes.
#
# GRANULARITY: TREE-WIDE, DELIBERATELY, AND FOR THE OPPOSITE REASON TO
# check-spec-refs.  That check had to go per-file, because a spec name is
# consumed by spec TEXT, and spec text is per target -- one reference from
# darwin's link_command covered the other 182 targets and *link_plugin passed
# while dead.  A targ_caps key is not consumed by text at all.  It is consumed
# by C++ that is compiled once and shared by every configuration; the config
# file only supplies the value.  There is no per-target reference set to dilute,
# so the failure that forced check-spec-refs per-file cannot arise here.
#
# The visible consequence is that a key read only from one back end
# (as_riscv_march_b, read by common/config/riscv/riscv-common.cc) is live for
# every target's file, and that is right: target-specs writes all 58 keys into
# all files unconditionally, and the code that reads riscv's key does not run
# for aarch64.  A per-file rule would demand a key -> back end map that neither
# side of this interface expresses.
#
# Usage: check-target-caps.sh GCC_SRCDIR CONFIGFILE...

set -e

srcdir=$1
shift

if test ! -f "$srcdir/target-caps.h"; then
  echo "check-target-caps: $srcdir does not look like gcc/ (no target-caps.h)" >&2
  exit 1
fi

work=`mktemp -d`
trap 'rm -rf "$work"' 0

# --- Build the reader corpus. ----------------------------------------------
# Continuations are joined BEFORE comments are stripped, because a `#define'
# that mentions targ_caps may be split over two lines (defaults.h:1557) and a
# per-physical-line reader would see a define with no key and a key with no
# define.  Same shape as the compile-line trap: get the record boundary right
# before matching anything.
join_cont () {
  awk '{ while (sub(/\\$/, "")) { if ((getline nxt) <= 0) break; $0 = $0 nxt }
	 print }' "$1"
}

strip_c_comments () {
  awk '{
	 line = ""
	 while (1) {
	   if (inc) {
	     i = index($0, "*/")
	     if (i == 0) { $0 = ""; break }
	     $0 = substr($0, i + 2); inc = 0
	   }
	   i = index($0, "/*")
	   if (i == 0) { line = line $0; break }
	   line = line substr($0, 1, i - 1)
	   $0 = substr($0, i + 2); inc = 1
	 }
	 sub(/\/\/.*/, "", line)
	 print line
       }'
}

# target-caps.cc is EXCLUDED, and it is the exclusion the check turns on.  That
# file names every key twice -- once in the designated initialiser that gives it
# a default, once in the strcmp ladder that parses it out of the config file --
# and neither is a read.  They are the two halves of the carrier itself.  Leave
# the file in and every key in the struct is trivially "live", which is precisely
# the state lto_plugin was in.
find "$srcdir" \( -name autom4te.cache -o -name testsuite -o -name po \) -prune \
  -o -type f \( -name '*.cc' -o -name '*.h' -o -name '*.c' -o -name '*.def' \) \
  -print > "$work"/cfiles
grep -v '^'"$srcdir"'/target-caps\.cc$' "$work"/cfiles > "$work"/cfiles2 || true
mv "$work"/cfiles2 "$work"/cfiles

: > "$work"/code
while read -r f; do
  join_cont "$f" | strip_c_comments
done < "$work"/cfiles >> "$work"/code

# Non-C corpora, each with its own comment syntax.  They contribute nothing
# today; they are here so that the day one of them grows a real use, the check
# sees it, rather than the check silently having decided C++ is the only place
# a reader can live.
for f in "$srcdir"/configure.ac "$srcdir"/../target-specs/configure.ac; do
  test -f "$f" && sed 's/\(^\|[ \t]\)dnl .*//' "$f" >> "$work"/code
done
for f in "$srcdir"/Makefile.in "$srcdir"/config.gcc; do
  test -f "$f" && sed 's/^[ \t]*#.*//' "$f" >> "$work"/code
done

# --- Split into uses and macro definitions. --------------------------------
# `#undef' is not a use either: defaults.h:1571 undefines HAVE_LTO_PLUGIN
# immediately before redefining it, and a word-match would have counted that
# line as a consumer of the macro it is about to replace.
grep -E '^[ \t]*#[ \t]*define[ \t]' "$work"/code > "$work"/defs || true
grep -vE '^[ \t]*#[ \t]*(define|undef)[ \t]' "$work"/code > "$work"/uses || true

# name -> definition body, for the macro reachability fixpoint.
sed -n 's/^[ \t]*#[ \t]*define[ \t]*\([A-Za-z_][A-Za-z_0-9]*\).*/\1/p' \
  "$work"/defs | sort -u > "$work"/macronames

# --- Which macros are reached? ---------------------------------------------
# Seed: every defined name that appears anywhere outside a #define/#undef.
# Then close under "a live macro's body reaches the macros it mentions", so
# that `#define A (targ_caps.k)' + `#define B A' + a use of B is live.  Without
# the closure the check reports a false death on any two-level macro, and a
# checker that cries wolf gets switched off.
awk 'NR==FNR { m[$0]=1; next }
     { n = split($0, w, /[^A-Za-z_0-9]+/)
       for (i = 1; i <= n; i++) if (w[i] in m) print w[i] }' \
  "$work"/macronames "$work"/uses | sort -u > "$work"/live_macros

rounds=0
while :; do
  rounds=`expr $rounds + 1`
  test "$rounds" -le 16 || break
  awk 'NR==FNR { live[$0]=1; next }
       { if (match($0, /^[ \t]*#[ \t]*define[ \t]*[A-Za-z_][A-Za-z_0-9]*/)) {
	   d = substr($0, RSTART, RLENGTH)
	   sub(/^[ \t]*#[ \t]*define[ \t]*/, "", d)
	   if (!(d in live)) next
	   body = substr($0, RSTART + RLENGTH)
	   n = split(body, w, /[^A-Za-z_0-9]+/)
	   for (i = 1; i <= n; i++) if (w[i] != "") print w[i]
	 } }' "$work"/live_macros "$work"/defs \
    | cat - "$work"/live_macros | sort -u > "$work"/live_macros.new
  # Only names that are actually macros stay in the set.
  comm -12 "$work"/live_macros.new "$work"/macronames > "$work"/live_macros.m
  cat "$work"/live_macros.m "$work"/live_macros | sort -u > "$work"/lm2
  if cmp -s "$work"/lm2 "$work"/live_macros; then rm -f "$work"/lm2; break; fi
  mv "$work"/lm2 "$work"/live_macros
done

# --- The reachability predicate. -------------------------------------------
# Keys whose reader is a variable of its own rather than a struct field.
cat > "$work"/aliases <<'EOF'
target targ_caps_target_name
EOF

reachable () {
  _k=$1
  _a=`awk -v k="$_k" '$1==k{print $2; exit}' "$work"/aliases`
  if test -n "$_a"; then
    grep -qw -- "$_a" "$work"/uses && return 0
    return 1
  fi
  # 1. an ordinary read.
  grep -q "targ_caps\.$_k\([^A-Za-z_0-9]\|\$\)" "$work"/uses && return 0
  # 2. a #define that mentions it, whose macro is reached.
  awk -v k="$_k" '
    match($0, /^[ \t]*#[ \t]*define[ \t]*[A-Za-z_][A-Za-z_0-9]*/) {
      d = substr($0, RSTART, RLENGTH); sub(/^[ \t]*#[ \t]*define[ \t]*/, "", d)
      if ($0 ~ ("targ_caps\\." k "([^A-Za-z_0-9]|$)")) print d
    }' "$work"/defs | sort -u > "$work"/via
  while read -r m; do
    test -n "$m" || continue
    grep -qx -- "$m" "$work"/live_macros && return 0
  done < "$work"/via
  return 1
}

# --- Calibration.  Two-sided, four shapes, ALL SYNTHETIC. -------------------
# Every stimulus below is written here, outside the tree, on purpose.  A control
# taken from the corpus under test cannot question it, and worse, a control
# whose stimulus is the bug stops working the moment the bug is fixed -- which
# is exactly what would happen if lto_plugin were used as the must-hit.  These
# four cannot be moved by anything anyone does to GCC.
mkdir -p "$work"/calib
cat > "$work"/calib/reader.cc <<'EOF'
/* A comment mentioning targ_caps.zzz_comment_only, which must NOT count.  */
int f (void) { return targ_caps.zzz_direct_read; }
#define ZZZ_LIVE_MACRO (targ_caps.zzz_via_live_macro)
#define ZZZ_DEAD_MACRO (targ_caps.zzz_via_dead_macro)
#define ZZZ_MIDDLE ZZZ_LIVE_MACRO
int g (void) { return ZZZ_MIDDLE; }
EOF
join_cont "$work"/calib/reader.cc | strip_c_comments >> "$work"/code
grep -E '^[ \t]*#[ \t]*define[ \t]' "$work"/calib/reader.cc >> "$work"/defs
grep -vE '^[ \t]*#[ \t]*(define|undef)[ \t]' "$work"/calib/reader.cc \
  | strip_c_comments >> "$work"/uses
sed -n 's/^[ \t]*#[ \t]*define[ \t]*\([A-Za-z_][A-Za-z_0-9]*\).*/\1/p' \
  "$work"/calib/reader.cc >> "$work"/macronames
sort -u "$work"/macronames -o "$work"/macronames
printf 'ZZZ_LIVE_MACRO\nZZZ_MIDDLE\n' >> "$work"/live_macros
sort -u "$work"/live_macros -o "$work"/live_macros

calib_fail=0
must_hit () {			# must be reachable
  if reachable "$1"; then :; else
    echo "check-target-caps: CALIBRATION FAILED -- $2" >&2
    calib_fail=1
  fi
}
must_miss () {			# must NOT be reachable
  if reachable "$1"; then
    echo "check-target-caps: CALIBRATION FAILED -- $2" >&2
    calib_fail=1
  fi
}
must_hit  zzz_direct_read \
  "a key read directly is called dead"
must_hit  zzz_via_live_macro \
  "a key reached through a chain of macros that IS used is called dead"
must_miss zzz_via_dead_macro \
  "a key reachable only through an UNUSED macro is called live.  That is the lto_plugin shape, and this check cannot see it."
must_miss zzz_comment_only \
  "a key mentioned only in a comment is called live"
must_miss zzz_absent_entirely \
  "a key nothing mentions at all is called live"
if test ! -s "$work"/uses; then
  echo "check-target-caps: the reader corpus is empty; every key would read" \
       "as dead for a reason that has nothing to do with the tree." >&2
  calib_fail=1
fi
if test "$calib_fail" -ne 0; then
  echo "check-target-caps: refusing to report." >&2
  exit 1
fi

# --- The actual check. ------------------------------------------------------
: > "$work"/dead
files=0
for f in "$@"; do
  test -f "$f" || continue
  files=`expr $files + 1`
  sed -e 's/#.*//' -e 's/^[ \t]*//' "$f" \
    | awk 'NF >= 2 && $1 ~ /^[a-z_][a-z_0-9]*$/ { print $1 }' \
    | sort -u > "$work"/keys
  if test ! -s "$work"/keys; then
    echo "check-target-caps: $f contains no 'name value' lines; the config" \
	 "format or this parser has changed, and a check that reads nothing" \
	 "passes everything." >&2
    exit 1
  fi
  while read -r k; do
    reachable "$k" || echo "$k $f" >> "$work"/dead
  done < "$work"/keys
done

if test "$files" -eq 0; then
  echo "check-target-caps: no config files given; nothing checked" >&2
  exit 1
fi

if test -s "$work"/dead; then
  echo "check-target-caps: capabilit(ies) written into a target config file" \
       "that nothing reads:" >&2
  awk '{print "  " $1 "  (first seen in " $2 ")"}' "$work"/dead | sort -u >&2
  echo "check-target-caps: read it as targ_caps.<name>, or reach it through a" \
       "macro something actually uses, or stop writing it.  A probe whose" \
       "answer is thrown away is a probe that lies to the next reader." >&2
  exit 1
fi

echo "check-target-caps: $files config file(s), every capability read by something"
