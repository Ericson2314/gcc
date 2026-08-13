#!/bin/sh
# conf-repair.sh -- apply the two mechanical repairs conf-audit.sh scores, and
# ASSERT the result rather than assuming it.  Run once; idempotent.
#
#   FOREIGN-SRC     `SRC=<hardcoded foreign worktree>' -> self-relative, plus a
#                   refusal that the tree is actually a multi-target tree.
#   MISSING-TARGETS add `--enable-targets' (and `--prefix') to TOP-LEVEL
#                   configure invocations only.
#
# sed, NOT python3 -- PRINCIPLES section 7: `python3' is not in the dev shell
# and an injection written in it does nothing while every downstream reading
# looks clean.
#
# EVERY substitution ASSERTS ITS RESULT.  A sed that matches nothing exits 0
# and leaves the file untouched, which is indistinguishable from a repair that
# was not needed.  So each file is re-checked for the intended END STATE after
# editing, and the script refuses by name if it is not there.
set -u
S=$(cd "$(dirname "$0")" && pwd)
cd "$S" || exit 9

T1=aarch64-unknown-linux-gnu
T2=x86_64-pc-linux-gnu

n_try=0 n_src=0 n_tgt=0 n_fail=0

fix_src () {           # $1 = file, $2 = "top" | "gcc"
  f=$1; lvl=$2
  grep -q '^SRC=/home/jcericson/src/gnu/gcc/\.claude/worktrees/agent-' "$f" || return 0
  if [ "$lvl" = gcc ]; then rel='$S/../gcc'; else rel='$S/..'; fi
  # awk, not a sed s/// -- the replacement text contains `||', which collides
  # with any delimiter sed is likely to be given.  The first attempt used `|'
  # and produced `unknown option to s' on 22 of 23 files; it was caught by the
  # end-state assertion below and not by sed's exit status.
  awk -v rel="$rel" '
    /^SRC=\/home\/jcericson\/src\/gnu\/gcc\/\.claude\/worktrees\/agent-/ {
      print "S=$(cd \"$(dirname \"$0\")\" && pwd)"
      print "SRC=$(cd \"" rel "\" && pwd)"
      print "# REFUSE THE WRONG TREE.  This line used to name ANOTHER agent'\''s"
      print "# worktree; those trees measure 27-28 `MULTI_TARGET'\'' hits in"
      print "# gcc/Makefile.in against this one'\''s 39, so the script configured and"
      print "# built a STALE compiler and reported a clean green for it, with no"
      print "# diagnostic.  0 hits is the documented bare-repo-HEAD case"
      print "# (PRINCIPLES section 5)."
      print "grep -q MULTI_TARGET \"$SRC/gcc/Makefile.in\" || { echo \"FATAL: $SRC is not a multi-target tree\"; exit 9; }"
      next
    }
    { print }
  ' "$f" > "$f.tmp" || return 1
  mv "$f.tmp" "$f" || return 1
  # ASSERT THE END STATE.  Not "sed exited 0" -- it does that on no match.
  grep -q '^SRC=$(cd' "$f" || { echo "FAIL: $f -- SRC not self-relative after edit"; return 1; }
  grep -q '/worktrees/agent-' "$f" && { echo "FAIL: $f -- a foreign path SURVIVED the edit"; return 1; }
  n_src=$((n_src + 1)); return 0
}

fix_targets () {       # $1 = file.  TOP-LEVEL only -- caller decides.
  f=$1
  grep -q -- '--enable-targets' "$f" && return 0
  grep -q -- '--enable-backends=' "$f" || { echo "FAIL: $f -- no --enable-backends= to anchor on"; return 1; }
  # Insert --enable-targets on the line BEFORE --enable-backends, copying its
  # own list.  Anchoring on the existing flag rather than writing a fresh line
  # keeps the two lists identical by construction; two hand-written lists that
  # drift is exactly the shared-numbering bug this project is about.
  sed -i -e 's|^\( *\)\(--enable-backends=\)\([^ ]*\)\( *\\\)$|\1--enable-targets=\3 \\\n\1\2\3\4|' "$f" || return 1
  grep -q -- '--enable-targets=' "$f" || { echo "FAIL: $f -- --enable-targets not inserted"; return 1; }
  # Both lists must be the SAME list.
  a=$(grep -o -- '--enable-targets=[^ ]*'  "$f" | head -1 | sed -e 's/.*=//')
  b=$(grep -o -- '--enable-backends=[^ ]*' "$f" | head -1 | sed -e 's/.*=//')
  [ "$a" = "$b" ] || { echo "FAIL: $f -- target list '$a' != backend list '$b'"; return 1; }
  n_tgt=$((n_tgt + 1)); return 0
}

do_file () {           # $1 = file, $2 = level
  n_try=$((n_try + 1))
  fix_src "$1" "$2" || { n_fail=$((n_fail + 1)); return; }
  [ "$2" = top ] && { fix_targets "$1" || { n_fail=$((n_fail + 1)); return; }; }
  return 0
}

# TOP-LEVEL: SRC is the worktree root, `$SRC/configure' is the dispatcher, and
# it REQUIRES --enable-targets (configure.ac:157, `--enable-targets=LIST is
# required').
for f in rv-build.sh t106-build.sh t106-conf.sh t107-build.sh t108-build.sh \
         t111-build.sh t111m-build.sh t112-build.sh t113-build.sh \
         t116-build.sh t117-build.sh t135-build.sh t24-build.sh \
         t45-build.sh t77-conf.sh t78-build.sh t88-conf.sh \
         t92-build.sh; do
  do_file "$f" top
done

# t45-all.sh gets the SRC fix but NOT the generic --enable-targets insertion:
# it is `--enable-backends=all', and `--enable-targets=all' is not legal (every
# element goes through config.sub).  Its flag is written by hand, with the
# reason recorded in the script itself.  Asserted here so a future run cannot
# quietly conclude the file needs nothing.
n_try=$((n_try + 1)); fix_src t45-all.sh top || n_fail=$((n_fail + 1))
grep -q -- '--enable-targets=x86_64' t45-all.sh \
  || { echo "FAIL: t45-all.sh -- hand-written --enable-targets is missing"; n_fail=$((n_fail + 1)); }

# t24-fp-build.sh takes SRC from the environment (`SRC=${SRC:?set SRC}'), so it
# has no foreign path to fix -- only the missing flag.
n_try=$((n_try + 1)); fix_targets t24-fp-build.sh || n_fail=$((n_fail + 1))

# GCC-LEVEL: SRC ends in `/gcc'.  gcc/configure.ac contains ZERO occurrences of
# `enable-targets' -- gcc/ takes `--enable-backends' and knows nothing about
# targets.  These get the SRC fix and MUST NOT get --enable-targets.
for f in eb-conf.sh eb-reconf.sh eb-reconf-ctl.sh; do
  do_file "$f" gcc
done

echo "---"
echo "files attempted        : $n_try"
echo "SRC made self-relative : $n_src"
echo "--enable-targets added : $n_tgt"
echo "failures               : $n_fail"
[ "$n_fail" = 0 ] || exit 1
exit 0
