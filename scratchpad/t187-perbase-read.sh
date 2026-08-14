#!/bin/sh
# #187 -- THE SEMANTIC ACCEPTANCE CHECK FOR "no shared object reads a
# per-base header".
#
# WHY THE TEXTUAL GREP CANNOT BE THE ACCEPTANCE TEST.  The criterion in use is
#
#     git grep '#include *"tm.h"' gcc       (minus ChangeLogs)  ->  0
#
# and it can reach 0 with the channel fully open, three independent ways:
#
#   1. The four shared channel headers no longer SPELL the include.  They
#      write `#include MT_HEADER (tm.h)', which that grep cannot see, and
#      multi-target-header.h expands MT_HEADER to a plain "tm.h" whenever
#      MT_BASE is unset -- which is EVERY shared object.  The include is
#      still there; only its spelling moved.
#   2. `#  include "tm.h"' (space after `#') slips past the pattern entirely.
#      That was caught only because a census ran an independent directive
#      regex alongside the grep and the two disagreed, 56 vs 59.
#   3. The criterion names one stem.  `tm_p.h' is the same defect -- the
#      build root's copy is the primary's protos under a neutral name -- and
#      no textual criterion mentions it.
#
# This is the riscv64 shape: "assembles, right ELF machine" passed on 32-bit
# code.  A proxy a real defect can satisfy is worse than no proxy, because it
# is believed.  So this script asks what the COMPILER READ, not what the
# source spells: every object's .deps/*.Po is the `-MD' record of every header
# that compilation actually opened, produced by the real compile recipe.
#
# THE THREE THINGS IT REFUSES TO ASSUME
#
#   * WHICH OBJECTS ARE SHARED.  Not a path pattern -- "outside gcc/config/"
#     is not "shared", 221 sources at gcc/ are compiled once per base, and the
#     per-base object set contains names like `insn-attrtab-aarch64.o' and
#     `target-cdata-aarch64.o' that live nowhere near `mt-<cpu>/'.  The
#     authority is the generated makefile, and it is EXPANDED BY MAKE (arm 1)
#     rather than parsed, because the assignments are made to variable
#     references (`$(MULTI_TARGET_OBJS_aarch64)') that only make can resolve.
#   * WHICH BUILD-ROOT HEADERS ARE PER-BASE.  Measured in arm 2 by comparing
#     the build root's copy of each stem against every base's own.  `options.h'
#     and `insn-modes.h' are unioned and are NOT leaks; `tm.h' and `tm_p.h'
#     are the primary's.  Hardcoding that list would make the check wrong the
#     moment a stem changes side.
#   * THAT IT READ ANYTHING.  Arms 0 and 4.  A missing tool, an empty .Po and
#     a genuine zero are the same output through a counting pipe.
#
# usage: t187-perbase-read.sh <builddir>
#        MT_ALLOW_MISSING_RC=1   score a build that has not finished (says so)
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
G=$D/gcc
O=${MT_OUT:-$D/t187}
rc_total=0

say () { printf '%s\n' "$*"; }
hdr () { say ""; say "== $*"; }

# ---------------------------------------------------------------- arm 0
hdr "arm 0  tree identity and non-vacuity"
[ -d "$G" ] || { say "FATAL: no $G"; exit 9; }
[ -f "$D/MY-SRC" ] || { say "FATAL: $D has no MY-SRC -- cannot say which tree this measures"; exit 9; }
SRC=$(cat "$D/MY-SRC")
grep -q "$SRC/configure" "$D/config.log" \
  || { say "FATAL: $D/config.log does not name $SRC"; exit 9; }
ANCHOR=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
say "srcdir     $SRC"
say "sha        $(cat "$SRC/SNAP-SHA" 2>/dev/null || echo NONE)"
say "anchor     $ANCHOR   (grep -c MULTI_TARGET gcc/Makefile.in)"
if [ -f "$D/make-top.rc" ]; then
  say "make rc    $(cat "$D/make-top.rc")   (stamped after make returned)"
elif [ "${MT_ALLOW_MISSING_RC:-0}" = 1 ]; then
  say "make rc    ABSENT -- scoring an UNFINISHED build by explicit request"
else
  say "FATAL: no $D/make-top.rc; a log being written looks exactly like one that finished"
  exit 9
fi
# `make' is NOT on the bare PATH here -- it lives in the nix-shell (DEVSHELL.md),
# so assert it where it will actually be run.  A missing tool piped into a
# counting pipe scores 0, in the direction that makes the reference look right.
for t in md5sum awk sort comm; do
  command -v "$t" > /dev/null || { say "FATAL: $t not on PATH"; exit 9; }
done
mkdir -p "$O"
sh "$S/eb-shell.sh" "make --version" > "$O/make-version.txt" 2>&1 || true
grep -q 'GNU Make' "$O/make-version.txt" \
  || { say "FATAL: no GNU Make inside eb-shell.sh; arm 1 would score 0 objects for the wrong reason"; exit 9; }
say "make       $(head -1 "$O/make-version.txt")"

find "$G" -name '*.Po' | sed "s|^$G/||" | sort > "$O/po-all.txt"
NPO=$(wc -l < "$O/po-all.txt")
say "deps files $NPO"
[ "$NPO" -gt 500 ] || { say "FATAL: only $NPO .Po files -- nothing to score"; exit 9; }

BASES=$(ls -d "$G"/*-inc 2>/dev/null | sed -e "s|^$G/||" -e 's|-inc$||' | sort)
NB=$(printf '%s\n' "$BASES" | grep -c . || true)
say "bases      $NB"
[ "$NB" -ge 1 ] || { say "FATAL: no <base>-inc directories"; exit 9; }

# ---------------------------------------------------------------- arm 1
# THE PER-BASE OBJECT SET, EXPANDED BY MAKE.
#
# Every per-base object is one the makefile gives a MULTI_TARGET_BASE_DEF
# (`-DMT_BASE=<cpu>-inc').  That is the only thing that says which back end an
# object's headers come from, so it is the definition of "not shared".  The
# targets of those assignments are largely variable REFERENCES, so this
# harvests the target expressions verbatim and hands them back to make in a
# generated fragment that includes the real Makefile -- make expands them, not
# a regex.
hdr "arm 1  per-base object set, from the generated makefile"
grep -hE '^[^	 =]+[^=]*: *MULTI_TARGET_BASE_DEF *=' "$G"/Makefile "$G"/*.mk 2>/dev/null \
  | sed 's/: *MULTI_TARGET_BASE_DEF *=.*//' | sort -u > "$O/mt-exprs.txt"
NEXPR=$(wc -l < "$O/mt-exprs.txt")
say "target expressions assigning MULTI_TARGET_BASE_DEF: $NEXPR"
[ "$NEXPR" -gt 0 ] || { say "FATAL: no MULTI_TARGET_BASE_DEF assignments -- wrong tree?"; exit 9; }

{
  echo 'include Makefile'
  echo 't187-print:'
  while read -r e; do
    printf '\t@printf "%%s\\n" %s\n' "$e"
  done < "$O/mt-exprs.txt"
} > "$O/t187-list.mk"
# The fragment lives in the OUTPUT dir, not in the build dir: this script must
# be runnable against a build tree it does not own without writing to it.
# `-C' makes `include Makefile' resolve there all the same.
sh "$S/eb-shell.sh" "make -C $G -f $O/t187-list.mk t187-print" \
  > "$O/perbase-raw.txt" 2> "$O/perbase-raw.err" || true
tr ' ' '\n' < "$O/perbase-raw.txt" | grep -E '\.o$' | sed 's|^\./||' | sort -u > "$O/perbase-objs.txt"
NPB=$(wc -l < "$O/perbase-objs.txt")
say "per-base objects (make-expanded): $NPB"
if [ "$NPB" -lt 500 ]; then
  say "FATAL: only $NPB per-base objects; make refused the fragment?  see $O/perbase-raw.err"
  head -5 "$O/perbase-raw.err"
  exit 9
fi
# Non-vacuity with teeth: the expansion must contain objects of BOTH shapes,
# `mt-<cpu>/x.o' and the flat `x-<cpu>.o' a path pattern would have missed.
grep -qE '^mt-[a-z0-9_]+/' "$O/perbase-objs.txt" \
  || { say "FATAL: expansion has no mt-<cpu>/ objects"; exit 9; }
NFLAT=$(grep -cvE '^mt-[a-z0-9_]+/' "$O/perbase-objs.txt" || true)
say "  of which NOT under mt-<cpu>/: $NFLAT   (a path pattern would call these shared)"
[ "$NFLAT" -gt 0 ] || { say "FATAL: expansion found no flat per-base objects"; exit 9; }

# The .Po path for object `d/x.o' is `d/.deps/x.Po'.
sed -e 's|\.o$|.Po|' -e 's|\([^/]*\)$|.deps/\1|' "$O/perbase-objs.txt" | sort -u > "$O/perbase-po.txt"
comm -23 "$O/po-all.txt" "$O/perbase-po.txt" > "$O/shared-po.txt"
NSH=$(wc -l < "$O/shared-po.txt")
say "shared objects with a .Po: $NSH"
[ "$NSH" -gt 100 ] || { say "FATAL: only $NSH shared .Po -- classification collapsed"; exit 9; }

# ---------------------------------------------------------------- arm 2
# WHICH BUILD-ROOT STEMS ARE PER-BASE, MEASURED.
#
# `<base>-inc/<stem>.h' is a one-line forwarder to the real `<stem>-<base>.h';
# follow it rather than md5-ing the forwarder, which would say every base is
# different for a trivial reason.  A build-root copy identical to EVERY base's
# is unioned and reading it is not a leak (`options.h' is generated from every
# configured back end's .opt files; `insn-modes.h' is the mode union).  A copy
# equal to one base's, or to none, is a per-base answer wearing a neutral
# name, and a shared object reading it gets that base's answer -- the bug.
hdr "arm 2  which build-root headers are per-base (measured, not assumed)"
sh "$S/t187-stemclass.sh" "$D" > "$O/stemclass.txt" || { say "FATAL: t187-stemclass.sh failed"; exit 9; }
cat "$O/stemclass.txt"
awk 'NR>1 && $4 ~ /^PER-BASE/  {print $1}' "$O/stemclass.txt" | sort -u > "$O/leak-stems.txt"
awk 'NR>1 && $4 ~ /^UNDECIDED/ {print $1}' "$O/stemclass.txt" | sort -u > "$O/undecided-stems.txt"
NLS=$(wc -l < "$O/leak-stems.txt")
NUD=$(wc -l < "$O/undecided-stems.txt")
say ""
say "leak-channel stems (scored):    $NLS   $(paste -sd' ' "$O/leak-stems.txt")"
say "undecided stems (NOT scored):   $NUD   $(paste -sd' ' "$O/undecided-stems.txt")"
say "  -- undecided means the md5, config-chain and name-set arms all declined"
say "     to say whose answer the root copy is.  Counted and reported below,"
say "     never folded into the verdict: an unexamined pass is not a result."
[ "$NLS" -gt 0 ] || { say "FATAL: arm 2 found no per-base build-root header at all -- it cannot fail, so it proves nothing"; exit 9; }
grep -qx 'tm.h' "$O/leak-stems.txt" \
  || { say "FATAL: tm.h did not classify PER-BASE; the classifier has stopped working"; exit 9; }

# ---------------------------------------------------------------- arm 3
# THE ACCEPTANCE CHECK.  For each SHARED object, does its dependency record
# name the BUILD ROOT's copy of a leak-channel stem?
#
# Reads the .Po by tokenising on whitespace and backslash-newline, and matches
# the whole path -- `<base>-inc/tm.h' must not count as `tm.h', and neither
# must `bits/types/struct_tm.h', which an unanchored pattern matches and which
# once made a correct FAIL unreadable.
hdr "arm 3  ACCEPTANCE -- shared objects that READ a per-base build-root header"
: > "$O/hits.txt"
while read -r p; do
  obj=$(echo "$p" | sed -e 's|\.deps/||' -e 's|\.Po$|.o|')
  tr ' \\\t' '\n\n\n' < "$G/$p" | sed -e 's|^\./||' -e 's|:$||' | grep -v '^$' \
    | while read -r dep; do
        case "$dep" in
          */*) continue ;;              # any subdirectory: not the build root
        esac
        if grep -qxF "$dep" "$O/leak-stems.txt"; then
          printf '%s %s\n' "$obj" "$dep"
        elif grep -qxF "$dep" "$O/undecided-stems.txt"; then
          printf '%s %s UNDECIDED\n' "$obj" "$dep"
        fi
      done
done < "$O/shared-po.txt" | sort -u > "$O/hits-all.txt"
grep -v ' UNDECIDED$' "$O/hits-all.txt" > "$O/hits.txt" || true
grep ' UNDECIDED$' "$O/hits-all.txt" > "$O/hits-undecided.txt" || true

NHIT=$(wc -l < "$O/hits.txt")
NOBJ=$(awk '{print $1}' "$O/hits.txt" | sort -u | wc -l)
say "shared objects reading a per-base build-root header: $NOBJ of $NSH   (object,header pairs: $NHIT)"
say ""
say "by header (scored):"
awk '{print $2}' "$O/hits.txt" | sort | uniq -c | sort -rn | sed 's/^/  /'
say ""
say "by header (UNDECIDED stems -- reported, not scored):"
awk '{print $2}' "$O/hits-undecided.txt" | sort | uniq -c | sort -rn | sed 's/^/  /'
say ""
# The stems the user's criterion is actually named after, called out by name,
# because "812 objects" answers a question nobody asked.  This is the honest
# version of the `git grep' figure.
for s in tm.h tm_p.h; do
  n=$(awk -v s="$s" '$2 == s {print $1}' "$O/hits.txt" | sort -u | wc -l)
  say "shared objects reading the build root's $s:  $n"
done
say ""
say "first 20 offenders:"
head -20 "$O/hits.txt" | sed 's/^/  /'
say "  (full list: $O/hits.txt)"
[ "$NOBJ" = 0 ] || rc_total=1

# ---------------------------------------------------------------- arm 4
# CAN IT FAIL, AND CAN IT PASS?  Two controls, because a scan that reads
# nothing and a scan that finds nothing print the same number.
hdr "arm 4  controls"
# 4a POSITIVE: the same reader, pointed at per-base objects, must see them
#    opening <base>-inc/tm.h.  If this is 0 the reader is not reading.
n4a=$(head -200 "$O/perbase-po.txt" | while read -r p; do
        [ -f "$G/$p" ] || continue
        tr ' \\\t' '\n\n\n' < "$G/$p" | grep -c -- '-inc/tm\.h$' || true
      done | awk '{s+=$1} END {print s+0}')
if [ "$n4a" -gt 0 ]; then
  say "4a PASS  reader sees $n4a <base>-inc/tm.h opens in the first 200 per-base objects"
else
  say "4a FATAL reader saw no per-base tm.h at all -- it is not reading the .Po files"; exit 9
fi
# 4b NEGATIVE: a synthetic shared .Po naming the build root's tm.h must be
#    caught.  An unfired mitigation is indistinguishable from an absent one.
CTL=$O/ctl
rm -rf "$CTL"; mkdir -p "$CTL/.deps"
printf 'ctl.o: ../../src/ctl.cc tm.h %s-inc/tm.h bits/types/struct_tm.h\n' "$(echo "$BASES" | head -1)" > "$CTL/.deps/ctl.Po"
got=$(tr ' \\\t' '\n\n\n' < "$CTL/.deps/ctl.Po" | sed -e 's|^\./||' -e 's|:$||' | grep -v '^$' \
      | while read -r dep; do
          case "$dep" in */*) continue ;; esac
          grep -qxF "$dep" "$O/leak-stems.txt" && echo "$dep"
        done | sort -u | paste -sd, -)
if [ "$got" = "tm.h" ]; then
  say "4b PASS  synthetic .Po: caught 'tm.h', and did NOT count <base>-inc/tm.h or struct_tm.h"
else
  say "4b FATAL synthetic .Po scored '$got', wanted exactly 'tm.h'"; exit 9
fi

# ---------------------------------------------------------------- arm 5
# AN INDEPENDENT INSTRUMENT ON THE SAME QUESTION.
#
# Arm 3 reads `.deps/*.Po', which is a RECORD of a past compilation.  A stale
# .Po survives a change that only alters a compile flag -- adding
# MULTI_TARGET_BASE_DEF once left 46 of 47 objects unrebuilt and the deps-diff
# reported a loss that was not there.  So a sample of the same objects is
# re-preprocessed NOW, with each object's OWN recipe taken from make, and
# `cpp -H' asked which tm.h it opens.  Two instruments, one question; they
# must agree.
#
# `-x c++' is not decoration: multi-target-macros.h's guard has an
# `|| !defined (__cplusplus)' arm that switches every redirect off under C,
# and an agent concluded Pmode was unconverted that way.  The recipe comes
# from make and already names the C++ compiler, which is the point of taking
# it from make rather than writing one.
hdr "arm 5  cpp -H cross-check on the real recipe (independent of .Po)"
N5=${MT_ARM5_N:-6}
: > "$O/arm5.txt"
agree=0; disagree=0; skipped=0
for p in $(head -400 "$O/shared-po.txt" | shuf -n 40 2>/dev/null || head -"$N5" "$O/shared-po.txt"); do
  [ "$((agree + disagree))" -lt "$N5" ] || break
  obj=$(echo "$p" | sed -e 's|\.deps/||' -e 's|\.Po$|.o|')
  R=$(sh "$S/eb-shell.sh" "make -C $G -n $obj" 2>/dev/null | grep -m1 -- "-o $obj ")
  [ -n "$R" ] || { skipped=$((skipped + 1)); continue; }
  SRCF=$(printf '%s\n' "$R" | tr ' ' '\n' | grep -m1 -E '\.(cc|c)$')
  [ -n "$SRCF" ] || { skipped=$((skipped + 1)); continue; }
  CXX=$(printf '%s\n' "$R" | awk '{print $1}')
  FLAGS=$(printf '%s\n' "$R" | sed -e "s| -o $obj .*||" -e 's/^[^ ]* //')
  sh "$S/eb-shell.sh" "cd $G && $CXX $FLAGS -H -E -o /dev/null $SRCF" \
    > /dev/null 2> "$O/arm5-$(echo "$obj" | tr '/' '_').H" || true
  # `. tm.h' with no directory component is the build root's copy.  Anchored,
  # because an unanchored pattern also matches bits/types/struct_tm.h and
  # reported a glibc header as the answer once already.
  h=$(grep -cE '^\.+ (\./)?tm\.h$' "$O/arm5-$(echo "$obj" | tr '/' '_').H" || true)
  d=$(awk -v o="$obj" '$1 == o && $2 == "tm.h"' "$O/hits.txt" | wc -l)
  if { [ "$h" -gt 0 ] && [ "$d" -gt 0 ]; } || { [ "$h" = 0 ] && [ "$d" = 0 ]; }; then
    printf 'AGREE     %-28s cpp-H=%s .Po=%s\n' "$obj" "$h" "$d" >> "$O/arm5.txt"
    agree=$((agree + 1))
  else
    printf 'DISAGREE  %-28s cpp-H=%s .Po=%s\n' "$obj" "$h" "$d" >> "$O/arm5.txt"
    disagree=$((disagree + 1))
  fi
done
cat "$O/arm5.txt"
say "arm 5: agree=$agree disagree=$disagree skipped=$skipped"
if [ "$agree" = 0 ]; then
  say "FATAL: arm 5 scored nothing -- it cannot corroborate or contradict arm 3"; exit 9
fi
[ "$disagree" = 0 ] || { say "arm 5 FAIL: the two instruments disagree; .Po may be stale"; rc_total=1; }

# ---------------------------------------------------------------- arm 6
# THE TEXTUAL TRIPWIRE, KEPT AND DEMOTED.  It is a fine early warning and it
# cannot be the acceptance test: it reads the source, and the source no longer
# spells what the compiler reads.  Printed beside the semantic number so the
# gap between them is visible rather than inferred.
hdr "arm 6  textual tripwire (early warning only -- NOT the acceptance test)"
if [ -d "$SRC/.git" ] || [ -f "$SRC/gcc/tsystem.h" ]; then
  t1=$( (cd "$SRC" && grep -rl '#include *"tm.h"' gcc 2>/dev/null) | grep -vc ChangeLog || true)
  t2=$( (cd "$SRC" && grep -rlE '^[[:space:]]*#[[:space:]]*include[[:space:]]*"tm\.h"' gcc 2>/dev/null) | grep -vc ChangeLog || true)
  t3=$( (cd "$SRC" && grep -rlE '^[[:space:]]*#[[:space:]]*include[[:space:]]*"tm_p\.h"' gcc 2>/dev/null) | grep -vc ChangeLog || true)
  t4=$( (cd "$SRC" && grep -rlE 'MT_HEADER *\( *tm\.h *\)' gcc 2>/dev/null) | grep -vc ChangeLog || true)
  say "  files spelling  \"tm.h\"        (the criterion): $t1"
  say "  same by directive regex (catches '#  include'): $t2"
  say "  files spelling  \"tm_p.h\"     (named by no criterion): $t3"
  say "  files spelling  MT_HEADER (tm.h)  (invisible to the criterion): $t4"
  say "  A disagreement between the first two is the '# include' evasion."
  say "  The fourth is the channel the criterion cannot see at all."
else
  say "  (source tree not readable from $SRC -- tripwire skipped, deliberately not scored)"
fi

hdr "verdict"
if [ "$rc_total" = 0 ]; then
  say "PASS  no shared object opens a per-base build-root header ($NSH shared objects, $NLS leak stems)"
else
  say "FAIL  $NOBJ of $NSH shared objects open a per-base build-root header"
fi
exit "$rc_total"
