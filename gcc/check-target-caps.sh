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
# THE OTHER DIRECTION, WHICH THIS CHECK WAS BLIND TO UNTIL NOW, AND WHICH IS
# THE MORE DANGEROUS OF THE TWO.
#
# Everything above judges the keys that a config file CONTAINS.  A key nothing
# reads is caught.  A key nothing WRITES is not even looked at, and its failure
# is strictly worse:
#
#   nothing reads it   -> one probe's answer is discarded.  Behaviour is that of
#                         the built-in default, which is at least a value
#                         somebody chose.
#   nothing writes it  -> read_target_caps never assigns it, so cc1 uses the
#                         built-in default ON EVERY TARGET, FOREVER, and the
#                         reader looks completely healthy.  The struct field
#                         exists, defaults.h defines the macro over it, the back
#                         end consults the macro, the testsuite passes because
#                         the default is usually right.  There is no moment at
#                         which anything is wrong enough to look at.
#
# The live instance that prompted this: `f8d15aa7640' added gxx_include_dir,
# gxx_tool_include_dir, gxx_backward_include_dir and gxx_libcxx_include_dir,
# all four read by cppdefault.cc and written by nobody.  Behaviour was unchanged
# -- which is exactly why nobody would ever notice.
#
# AND THE THIRD SET, which falls out of the same comparison for free: a key
# target-specs EMITS for which target-caps.h has no field at all.
# read_target_caps' strcmp ladder has no arm for it, and the deliberate
# ignore-unknown-names rule -- correct, so a newer spec file does not break an
# older compiler -- swallows it in silence.  There are 26 of these today (avr,
# powerpc, loongarch, s390, darwin, ia64, cris, msp430, hppa, arm), every one a
# probe that runs against a real assembler and whose answer is dropped on the
# floor.  The read-direction arm CANNOT see them, and not by oversight: it reads
# config files, and a config file for a target this build does not enable does
# not exist.  Its corpus is what this build happens to enable.  The corpus of
# the two arms below is target-specs/configure.ac -- WHAT THE GENERATOR CAN
# EMIT -- which is the corpus the question is actually about.
#
# THE EXEMPTION TABLE, AND WHY IT IS NOT AN ADVISORY MODE.  There are 48 of
# these today and they are not mine to fix: the writes belong in
# target-specs/configure.ac and the fields in target-caps.h.  A check that
# blocks the work needed to fix what it found is worse than no check -- but the
# standard remedy, demoting the whole arm to a warning, is what once outlived
# its fix by minutes and left an arm silently non-enforcing.  So the arms are
# FATAL, and the backlog is an EXPLICIT, ITEMISED, SELF-EXPIRING table below.
# Consequences, all of them deliberate:
#
#   * a key that lands unwritten TOMORROW is fatal on day one, because it is not
#     in the table.  The gap closes for new work immediately.
#   * an entry whose bug has been FIXED is fatal as a stale exemption.  The
#     table cannot outlive what it excuses; when it empties, the arm is simply
#     fatal, with no flag anyone has to remember to flip.
#   * `bug' entries are printed on every run.  An exemption you never see is an
#     exemption that becomes permanent.
#
# `optout' is for a capability whose built-in default no target needs to
# override.  Each one carries its reason on the line.  Adding an entry is a
# claim about the tree, so make it a claim someone can check.
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

# --- Declared keys, and keys the generator can emit. ------------------------
# Two extractors, each with its own way of being quietly wrong, so each gets its
# own two-sided calibration below against synthetic input whose answer is known.

# Fields of `struct target_caps'.  Comments are stripped first and the struct is
# bounded at its closing brace: target-caps.h continues past line 690 with
# `extern struct target_caps targ_caps;' and a couple of inline functions, and
# an unbounded scan would take a parameter name for a capability.
decl_keys () {
  join_cont "$1" | strip_c_comments \
    | awk '/^struct target_caps/ { s = 1 } s { print } s && /^};/ { exit }' \
    | sed -n 's/^[ \t]*\(bool\|int\|unsigned\|long\|const char \*\)[ \t*]*\([a-z_][a-z_0-9]*\)[ \t]*;.*/\2/p' \
    | sort -u
}

# Keys target-specs/configure.ac can write.  The config file is produced by
# heredocs onto $target_config_file, so a `name value' line inside one of those
# heredocs is an emission and nothing else in the file is.  In particular
# `gcc_cv_solaris_ld=no' and the sixteen dnl notes about targ_caps are NOT
# emissions -- the same prose trap the reader arm exists to avoid, and here it
# is sharper, because a key's shell variable is naturally named after the key.
emit_keys () {
  awk '
    /^[ \t]*cat[ \t]*>>?[ \t]*"?\$\{?target_config_file\}?"?[ \t]*<</ {
      d = $0; sub(/.*<<[ \t]*/, "", d); gsub(/[^A-Za-z_0-9]/, "", d)
      inh = 1; delim = d; next }
    inh && $0 == delim { inh = 0; next }
    inh && /^[a-z_][a-z_0-9]*[ \t]/ { print $1 }
  ' "$1" | sort -u
}

# ANY OTHER WAY OF WRITING TO THAT FILE IS A HOLE IN emit_keys, and a hole here
# reads as "this key is never written", i.e. a false positive on a live key --
# the report that gets a checker demoted.  So the shapes are enumerated rather
# than assumed: a redirection onto $target_config_file that is not one of the
# heredoc openers emit_keys understands is a hard error, not a missed key.
emit_guard () {
  grep -nE '>>?[ \t]*"?\$\{?target_config_file' "$1" > "$work"/g1 || true
  grep -vE 'cat[ \t]*>>?[ \t]*"?\$\{?target_config_file\}?"?[ \t]*<<' \
    "$work"/g1 || true
}

emitter=$srcdir/../target-specs/configure.ac
if test ! -f "$emitter"; then
  echo "check-target-caps: no $emitter, so nothing can be said about which" \
       "capabilities are ever written.  Refusing to report: a missing emitter" \
       "corpus and an emitter that writes nothing look identical from here." >&2
  exit 1
fi

# --- Calibration for the two new arms.  Synthetic, and two-sided. -----------
# The must-MISSES are drawn from OUTSIDE the class of true positives on purpose.
# A declared key that IS emitted cannot detect an extractor that calls prose an
# emission; the stimuli that can are a dnl note, a shell assignment, a heredoc
# onto a DIFFERENT file, and text after the struct's closing brace -- none of
# which is a declaration or an emission, and all of which look like one to a
# grep.  Each arm asserts the extractor's EXACT output, so a stimulus that
# stops being exercised shows up as a failure rather than as a silent pass.
cat > "$work"/calib/caps.h <<'EOF'
/* struct target_caps
   bool zzz_comment_field;  */
struct target_caps
{
  bool zzz_decl_bool;
  const char *zzz_decl_str;
  int zzz_decl_int;
};
extern struct target_caps targ_caps;
inline bool zzz_not_a_field (int zzz_param_int) { return zzz_param_int; }
EOF
# Note the outer delimiter: the stimulus CONTAINS `EOF' lines, and writing this
# heredoc as <<'EOF' would end it at the first of them -- leaving a stimulus
# that no longer exercises what it claims to.
cat > "$work"/calib/configure.ac <<'CALIB_AC_EOF'
dnl zzz_dnl_only 1 -- a note, not an emission.
zzz_shell_assign=no
cat > "$other_file" <<XEOF
zzz_other_file 1
XEOF
cat > "$target_config_file" <<EOF
# zzz_comment_in_heredoc 1
zzz_emit_first ${zzz_shell_assign}
EOF
cat >> "$target_config_file" <<EOF
zzz_emit_appended `zzz_bool "$x"`
EOF
CALIB_AC_EOF

calib_want_decl="zzz_decl_bool
zzz_decl_int
zzz_decl_str"
calib_got_decl=`decl_keys "$work"/calib/caps.h`
if test "x$calib_got_decl" != "x$calib_want_decl"; then
  echo "check-target-caps: CALIBRATION FAILED -- the declaration extractor" \
       "does not read a known struct correctly.  Wanted:" >&2
  echo "$calib_want_decl" | sed 's/^/    /' >&2
  echo "  got:" >&2
  echo "$calib_got_decl" | sed 's/^/    /' >&2
  calib_fail=1
fi

calib_want_emit="zzz_emit_appended
zzz_emit_first"
calib_got_emit=`emit_keys "$work"/calib/configure.ac`
if test "x$calib_got_emit" != "x$calib_want_emit"; then
  echo "check-target-caps: CALIBRATION FAILED -- the emission extractor does" \
       "not read a known emitter correctly.  A dnl note, a shell assignment," \
       "a comment inside the heredoc or a heredoc onto another file has been" \
       "counted as an emission, or a real one has been missed.  Wanted:" >&2
  echo "$calib_want_emit" | sed 's/^/    /' >&2
  echo "  got:" >&2
  echo "$calib_got_emit" | sed 's/^/    /' >&2
  calib_fail=1
fi

# emit_guard gets its own two-sided arm, and it needs one more than anything
# else here: it is the part with no visible output when it works, its whole
# job is to notice a shape nobody has written yet, and its first draft used an
# invalid BRE -- `\{\{0,1\}' -- so grep failed on every line, the guard reported
# nothing, and "nothing" is indistinguishable from "all clear".  That is the
# grep-exit-status trap in its purest form.  The must-MISS is the emitter shape
# that IS understood; the must-HIT is a shape from outside that class.
if test -n "`emit_guard "$work"/calib/configure.ac`"; then
  echo "check-target-caps: CALIBRATION FAILED -- emit_guard objects to the" \
       "ordinary heredoc emissions it is supposed to understand, so it would" \
       "fail every build." >&2
  calib_fail=1
fi
printf 'echo "zzz_sneaky 1" >> "$target_config_file"\n' \
  > "$work"/calib/configure-sneaky.ac
if test -z "`emit_guard "$work"/calib/configure-sneaky.ac`"; then
  echo "check-target-caps: CALIBRATION FAILED -- emit_guard does not notice a" \
       "write to the target config file that emit_keys cannot follow, so a" \
       "capability written that way would be reported as never written." >&2
  calib_fail=1
fi

if test "$calib_fail" -ne 0; then
  echo "check-target-caps: refusing to report." >&2
  exit 1
fi

declared=`decl_keys "$srcdir/target-caps.h"`
emitted=`emit_keys "$emitter"`
if test -z "$declared"; then
  echo "check-target-caps: no fields extracted from $srcdir/target-caps.h;" \
       "the header or this parser has changed, and then every key would read" \
       "as undeclared for a reason that has nothing to do with the tree." >&2
  exit 1
fi
if test -z "$emitted"; then
  echo "check-target-caps: no emissions extracted from $emitter; the emitter" \
       "or this parser has changed, and then EVERY capability would read as" \
       "never written." >&2
  exit 1
fi
stray=`emit_guard "$emitter"`
if test -n "$stray"; then
  echo "check-target-caps: $emitter writes the target config file in a way" \
       "this check cannot follow, so it cannot tell which capabilities are" \
       "written.  Teach emit_keys the new shape; do not delete this test." >&2
  echo "$stray" | sed 's/^/  /' >&2
  exit 1
fi

printf '%s\n' "$declared" > "$work"/declared
printf '%s\n' "$emitted" > "$work"/emitted

# --- The backlog.  KEY  KIND  REASON.  See the header for the rules. --------
# KIND is `bug' (a real defect, reported every run until fixed) or `optout' (a
# built-in default no target needs to override).  A stale entry is fatal.
cat > "$work"/exempt <<'EOF'
# Emitted, but target-caps.h has no field: read_target_caps' strcmp ladder has
# no arm, so the probe's answer is dropped and the ignore-unknown-names rule
# hides it.  All of these are probes that run against a real assembler.
target optout The configuration's own name, not a capability.  It is read through targ_caps_target_name (see the alias table above), which is why it has no struct field and must not grow one.
as_avr_mgccisr bug avr __gcc_isr probe, answer discarded.
as_avr_mlink_relax bug avr -mlink-relax probe, answer discarded.
as_avr_mrmw bug avr -mrmw probe, answer discarded.
as_entry_markers bug powerpc entry-marker probe, answer discarded.
as_mfcrf bug powerpc mfcrf probe, answer discarded.
as_power10_htm bug powerpc power10 HTM probe, answer discarded.
as_pltseq bug powerpc pltseq-marker probe, answer discarded.
as_rel16 bug powerpc rel16 probe, answer discarded.
as_loongarch_16b_atomic bug loongarch probe, answer discarded.
as_loongarch_eh_frame_pcrel_encoding bug loongarch probe, answer discarded.
as_loongarch_support_call36 bug loongarch probe, answer discarded.
as_loongarch_tls_le_relaxation bug loongarch probe, answer discarded.
as_s390_architecture_modifiers bug s390 probe, answer discarded.
as_s390_machine_machinemode bug s390 probe, answer discarded.
as_s390_vector_loadstore_alignment_hints bug s390 probe, answer discarded.
as_s390_vector_loadstore_alignment_hints_on_z13 bug s390 probe, answer discarded.
as_macos_build_version bug darwin -mbuild-version probe, answer discarded.
as_mmacosx_version_min bug darwin -mmacosx-version-min probe, answer discarded.
as_ltoffx_ldxmov_relocs bug ia64 probe, answer discarded.
as_no_mul_bug_abort bug cris probe, answer discarded.
as_mspabi_attribute bug msp430 probe, answer discarded.
gas_arm_extended_arch bug arm probe, answer discarded.
gas_literal16 bug darwin .literal16 probe, answer discarded.
gas_nsubspa_comdat bug hppa probe, answer discarded.
use_as_traditional_format bug eh_frame traditional-format probe, answer discarded.
# Declared and read, but target-specs/configure.ac emits nothing for them, so
# cc1 uses the built-in default on every target.  These are the silent half.
gxx_include_dir bug Read by cppdefault.cc since f8d15aa7640; no emitter.
gxx_tool_include_dir bug Read by cppdefault.cc since f8d15aa7640; no emitter.
gxx_backward_include_dir bug Read by cppdefault.cc since f8d15aa7640; no emitter.
gxx_libcxx_include_dir bug Read by cppdefault.cc since f8d15aa7640; no emitter.
as_gotoff_in_data bug HAVE_AS_GOTOFF_IN_DATA; no ix86 probe was carried over.
as_ix86_cmov_sun_syntax bug No ix86 probe was carried over to target-specs.
as_ix86_ffreep bug No ix86 probe was carried over to target-specs.
as_ix86_fildq bug No ix86 probe was carried over to target-specs.
as_ix86_filds bug No ix86 probe was carried over to target-specs.
as_ix86_got32x bug No ix86 probe was carried over to target-specs.
as_ix86_hle bug No ix86 probe was carried over to target-specs.
as_ix86_interunit_movq bug No ix86 probe was carried over to target-specs.
as_ix86_rep_lock_prefix bug No ix86 probe was carried over to target-specs.
as_ix86_sahf bug No ix86 probe was carried over to target-specs.
as_ix86_tls_get_addr_got bug No ix86 probe was carried over to target-specs.
as_ix86_tlsgdplt bug No ix86 probe was carried over to target-specs.
as_ix86_tlsldm bug No ix86 probe was carried over to target-specs.
as_ix86_tlsldmplt bug No ix86 probe was carried over to target-specs.
as_ix86_ud2 bug No ix86 probe was carried over to target-specs.
as_r_x86_64_code_6_gottpoff bug No ix86 probe was carried over to target-specs.
solaris_ld bug gcc_cv_solaris_ld IS probed; the answer reaches spec text only and never the config file.
vms_debug bug Read by dwarf2out.cc; nothing probes or emits it.
EOF

sed 's/^#.*//' "$work"/exempt | awk 'NF { print $1 }' | sort > "$work"/exempt_keys
if test `wc -l < "$work"/exempt_keys` -ne `sort -u "$work"/exempt_keys | wc -l`
then
  echo "check-target-caps: the exemption table lists a key twice; one of the" \
       "two reasons is not being applied to anything." >&2
  exit 1
fi
exempt_kind () {
  sed 's/^#.*//' "$work"/exempt | awk -v k="$1" '$1 == k { print $2; exit }'
}

# Undeclared-and-emitted, undeclared-and-not-emitted, declared-and-not-emitted.
comm -13 "$work"/declared "$work"/emitted > "$work"/emit_nofield
comm -23 "$work"/declared "$work"/emitted > "$work"/decl_nowrite
cat "$work"/emit_nofield "$work"/decl_nowrite | sort -u > "$work"/gaps

# A stale exemption is fatal.  This is the whole reason the table can be
# trusted: it cannot outlive what it excuses, and when it empties the arms are
# simply fatal with no flag to remember.  If you have just made a key work,
# the fix is to delete its line from the table above.
comm -23 "$work"/exempt_keys "$work"/gaps > "$work"/stale
if test -s "$work"/stale; then
  echo "check-target-caps: STALE EXEMPTION(S).  These are listed in the" \
       "backlog table in $0 as capabilities that are not written, and they" \
       "now are.  Delete their lines from that table -- an exemption that" \
       "outlives its fix is how an arm stops enforcing without anyone" \
       "deciding that it should:" >&2
  sed 's/^/  /' "$work"/stale >&2
  exit 1
fi

: > "$work"/unwritten
: > "$work"/known
while read -r k; do
  test -n "$k" || continue
  case `exempt_kind "$k"` in
    bug)    echo "$k" >> "$work"/known ;;
    optout) ;;
    *)      echo "$k" >> "$work"/unwritten ;;
  esac
done < "$work"/gaps

if test -s "$work"/known; then
  echo "check-target-caps: `wc -l < "$work"/known | tr -d ' '` known-unwritten" \
       "capabilit(ies), exempted with a reason in $0.  A probe whose answer" \
       "never reaches cc1, or a field cc1 never has assigned, is the built-in" \
       "default on every target forever:" >&2
  sed 's/^#.*//' "$work"/exempt \
    | awk 'NR==FNR { want[$0] = 1; next }
	   NF && ($1 in want) { k = $1; $1 = ""; $2 = ""; sub(/^[ \t]*/, "")
			        print "  " k " -- " $0 }' \
	  "$work"/known - >&2
fi

if test -s "$work"/unwritten; then
  echo "check-target-caps: capabilit(ies) that no target config file can ever" \
       "carry -- target-specs/configure.ac emits nothing for them, or emits a" \
       "name target-caps.h has no field for:" >&2
  sed 's/^/  /' "$work"/unwritten >&2
  echo "check-target-caps: emit it from target-specs/configure.ac and give it" \
       "a field and a strcmp arm, or stop declaring it.  A capability nothing" \
       "writes is not a default -- it is a reader that looks healthy and is" \
       "answering a question nobody ever asked the toolchain." >&2
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
