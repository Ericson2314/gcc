#!/bin/sh
# conf-audit.sh -- audit EVERY script in scratchpad/ that invokes a configure,
# and score each one.  Written because the top level's `--enable-targets=LIST
# is required' flag day broke the guard corpus wholesale and nobody could say
# HOW MANY scripts were broken, only that "the tNNN-build.sh ones" were.
#
# Two DIFFERENT defects are scored, and they fail in OPPOSITE directions:
#
#   MISSING-TARGETS  a TOP-LEVEL configure invocation with no
#                    `--enable-targets'.  Fails LOUDLY, by name
#                    (`--enable-targets=LIST is required', configure.ac:157).
#                    Annoying, but self-announcing.
#
#   FOREIGN-SRC      `SRC=' hardcoded to ANOTHER agent's worktree.  This is the
#                    dangerous one: it configures and builds SOMEBODY ELSE'S
#                    TREE and succeeds.  Measured 2026-08-13: this worktree has
#                    39 `MULTI_TARGET' hits in gcc/Makefile.in; the trees these
#                    scripts point at have 27, 28 or 39.  A script pointing at a
#                    28 would build a compiler missing eleven landed changes and
#                    report a clean green for it.  There is no diagnostic.
#
# A THIRD case is scored explicitly so it is not "repaired" into a bug:
#
#   GCC-LEVEL        invokes `$SRC/gcc/configure', where SRC ends in `/gcc'.
#                    gcc/configure.ac contains ZERO occurrences of
#                    `enable-targets' (measured) -- gcc/ takes `--enable-backends'
#                    and knows nothing about targets, which is the whole
#                    host-not-target ruling.  Adding `--enable-targets' here
#                    would be an UNRECOGNISED OPTION, i.e. the brief's blanket
#                    "repair them all" is wrong for these.  They are OK by
#                    construction and are reported as such rather than silently
#                    omitted -- a file checked and judged fine is a result.
#
# Exit 0 only if every script scores OK.  Any defect exits 1 and NAMES it.
#
# NON-VACUITY: refuses to score if it found no configure invocations at all.
# An empty sweep otherwise prints "0 defects" and reads exactly like a pass.
set -u
S=$(cd "$(dirname "$0")" && pwd)
HERE=$(cd "$S/.." && pwd)

cd "$S" || exit 9

n_conf=0 n_ok=0 n_bad=0 n_exempt=0 n_gcc=0 n_top=0

for f in *.sh; do
  # Never score the auditor against itself.  It necessarily CONTAINS every
  # pattern it looks for, and scored itself BAD on the first run -- a
  # self-match that would have sat in the output forever reading as a real
  # defect in a real script.
  case "$f" in conf-audit.sh|conf-repair.sh) continue ;; esac

  # Does this file invoke a configure at all?  Match the INVOCATION
  # (`.../configure' being run), not the word "configure" in prose -- t45-all.sh
  # has four comment lines about configure and one invocation.
  grep -q '\$SRC/configure\|\$SRC/gcc/configure\|"\$SRC/configure"' "$f" || continue
  n_conf=$((n_conf + 1))

  srcline=$(grep -m1 '^SRC=' "$f")
  bad=

  case "$srcline" in
    *"/worktrees/agent-"*)
      # Hardcoded.  Is it THIS worktree?  Even then it is wrong -- the next
      # agent copies the file and inherits a foreign path.
      case "$srcline" in
        *"$HERE"*) bad="$bad HARDCODED-SELF" ;;
        *)         bad="$bad FOREIGN-SRC" ;;
      esac
      ;;
    *'$(cd "$S/.."'*|*'$(cd "$S/../.."'*) : ;;   # self-relative: correct
    '') bad="$bad NO-SRC-ASSIGNMENT" ;;
    *)  : ;;
  esac

  # gcc-level or top-level?  Decided by what SRC POINTS AT, not by the name of
  # the script.
  #
  # THIS TEST HAS ALREADY FAILED ONCE, IN THE DIRECTION THAT MANUFACTURES A
  # PASS.  It originally matched a literal path ending in `/gcc'.  The moment
  # conf-repair.sh rewrote those to `SRC=$(cd "$S/../gcc" && pwd)' the pattern
  # stopped matching, all three eb-* scripts were reclassified TOP, and
  # eb-reconf-ctl.sh scored OK -- not because its exemption applied, but
  # because the defect it is exempt from was NEVER SCORED.  A wrong-reason
  # green inside the check written to catch wrong-reason greens.  So match
  # BOTH spellings, and assert below that the GCC class is not empty.
  case "$srcline" in
    */gcc|*'/../gcc"'*|*'/gcc'\ *) level=GCC ;;
    *)                             level=TOP ;;
  esac

  if [ "$level" = TOP ]; then
    grep -q -- '--enable-targets' "$f" || bad="$bad MISSING-TARGETS"
  else
    # The inverse check.  Adding --enable-targets to a gcc/configure call is a
    # plausible "repair" and would be an unrecognised option.
    grep -q -- '--enable-targets' "$f" && bad="$bad TARGETS-ON-GCC-CONFIGURE"
  fi

  # EXEMPTIONS LIVE IN THE FILE, NOT IN A LIST HERE.  A script may carry
  #     # CONF-AUDIT-EXEMPT: <DEFECT> -- <reason>
  # and that defect stops being scored FOR THAT FILE.  Deliberately NOT an
  # allowlist in this script: an allowlist is a name in a file nobody reads
  # next to the code it excuses, which is how a check gets quietly hollowed
  # out.  Putting the marker in the script under test forces whoever adds it
  # to write the reason where the next reader of that script will see it, and
  # makes `grep CONF-AUDIT-EXEMPT *.sh' the complete list of excuses.
  for d in $bad; do
    if grep -q "CONF-AUDIT-EXEMPT: $d" "$f"; then
      bad=$(echo "$bad" | sed -e "s/ *$d//")
      n_exempt=$((n_exempt + 1))
      printf 'EXEMPT %-19s %s %s\n' "$f" "$level" "$d"
    fi
  done

  [ "$level" = GCC ] && n_gcc=$((n_gcc + 1))
  [ "$level" = TOP ] && n_top=$((n_top + 1))

  if [ -z "$bad" ]; then
    n_ok=$((n_ok + 1))
    printf 'OK    %-20s %s\n' "$f" "$level"
  else
    n_bad=$((n_bad + 1))
    printf 'BAD   %-20s %s %s\n' "$f" "$level" "$bad"
  fi
done

echo "---"
echo "configure-invoking scripts found : $n_conf"
echo "OK                               : $n_ok"
echo "BAD                              : $n_bad"
echo "exempted defects (with reasons)  : $n_exempt"

# NON-VACUITY.  If the loop matched nothing, every count above is 0 and the
# script would exit 0 having proved nothing.  That is the shape PRINCIPLES
# section 7 names: an all-empty read is indistinguishable from a pass.
if [ "$n_conf" -lt 10 ]; then
  echo "FATAL: only $n_conf configure invocations found (expected >= 10)."
  echo "FATAL: the matcher is broken, not the corpus.  Refusing to score."
  exit 9
fi

# PER-CLASS NON-VACUITY.  The overall count above stayed at 39 while the GCC
# class silently emptied to 0 and every one of its members was scored under the
# TOP rules instead.  A total that does not move is exactly what a
# misclassification looks like, so assert the CLASSES, not just the sum.
echo "  of which TOP-LEVEL             : $n_top"
echo "  of which gcc/configure         : $n_gcc"
if [ "$n_gcc" -lt 3 ]; then
  echo "FATAL: only $n_gcc gcc-level scripts classified (expected >= 3:"
  echo "FATAL: eb-conf.sh, eb-reconf.sh, eb-reconf-ctl.sh).  The LEVEL test is"
  echo "FATAL: broken and every gcc-level script is being scored under the"
  echo "FATAL: top-level rules.  Refusing to score."
  exit 9
fi

[ "$n_bad" = 0 ] || exit 1
exit 0
