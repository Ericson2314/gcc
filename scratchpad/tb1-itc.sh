#!/bin/sh
# #181 / T159 -- IS `IN_TARGET_CODE' ACTUALLY REACHING THE COMPILER PROPER?
#
# The brief's premise is a COUNT OF `-DIN_TARGET_CODE' ON COMPILE LINES, and
# that count is zero.  It is zero upstream too: `IN_TARGET_CODE' has never been
# a command-line flag.  Every back-end source spells `#define IN_TARGET_CODE 1'
# as its first line, and nine generators (genattrtab, genautomata, genemit,
# genextract, genopinit, genoutput, genpeep, genpreds, genrecog) write that
# same line into the sources they emit.  So a `-D' census cannot see the
# mechanism at all, in either direction.
#
# This asks the only question that decides it: for a REAL object in THIS build,
# with its REAL compile command, what is the macro state the preprocessor
# actually arrives at?  Read with `-E -dM' off the object's own recipe, so an
# undefined name is reported as ABSENT rather than silently evaluating false
# (PRINCIPLES section 4).
#
# NON-VACUITY: the harness refuses to score unless it recovered a compile
# command for every probe and each `-dM' run produced a non-trivial macro set.
#
# usage: tb1-itc.sh <builddir>
set -e
D=${1:?build dir}
case "$D" in
  */b-agent-aab545de8b02de843*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/make-top.rc" ] || { echo "FATAL: $D/make-top.rc absent -- the log is unstamped and will not be scored"; exit 9; }
RAWLOG="$D/make-top.out"
[ -s "$RAWLOG" ] || { echo "FATAL: $RAWLOG empty"; exit 9; }

# JOIN BACKSLASH CONTINUATIONS FIRST.  Some recipes -- target-regs-<cpu>.o,
# target-addr-<cpu>.o and the rest of the per-base shims -- are written across
# two physical lines, so a `grep' for the object's `-o' returns a fragment that
# ENDS IN `\' and does not contain the source file at all.  Appending `-E -dM'
# to that fragment produced `ld: cannot find -E' -- an instrument failure
# wearing the shape of a build failure, and one that would have been recorded
# as MISSING-CMD (i.e. "this object has no per-base rule") had the harness not
# insisted on a macro count.
LOG="$D/tb1-joined.log"
awk '{ if (buf != "") $0 = buf " " $0; if (sub(/\\$/, "")) { buf = $0; next } buf = ""; print }' \
  "$RAWLOG" > "$LOG"
S=$(cd "$(dirname "$0")" && pwd)

WANT="IN_TARGET_CODE TARGET_POLY_AWARE ONLY_FIXED_SIZE_MODES POLY_INT_CONVERSION MACRO_MODE(MODE) MACRO_INT(X)"

# The objects to probe, and what each one is here to prove.
#   mt-xstormy16/xstormy16.o  hand-written target code, NOT poly-aware
#   mt-aarch64/aarch64.o      hand-written target code, poly-aware
#   insn-output-xstormy16.o   GENERATED target code, not poly-aware
#   insn-output-aarch64.o     GENERATED target code, poly-aware
#   target-regs-xstormy16.o   per-base object from a SHARED source
#   expr.o                    shared code -- the both-sided control
PROBES="mt-xstormy16/xstormy16.o mt-aarch64/aarch64.o \
insn-output-xstormy16.o insn-output-aarch64.o \
target-regs-xstormy16.o expr.o"

nprobe=0
for o in $PROBES; do
  # The compile line for this object.  Objects are compiled by $(COMPILE),
  # which ends in `-o <obj> <src>'; match on the -o.
  cmd=$(grep -F -- " -o $o " "$LOG" | grep -v '^ *#' | tail -1)
  if [ -z "$cmd" ]; then
    echo "MISSING-CMD $o"
    continue
  fi
  nprobe=$((nprobe+1))
  # Re-run the same command as a preprocessor macro dump.  -E -dM prints every
  # macro that survives, so ABSENT and 0 are distinguishable.
  #
  # `-c', the `-o <obj>' and the whole -M dependency group have to come OUT:
  # -E replaces the compile, a second -o would fight the first, and -MF would
  # rewrite the object's real depfile from a probe run -- which is the
  # "instrument corrupts the thing it measures" shape.  Stripped by name so a
  # flag this does not know about is carried through rather than dropped.
  pp=$(printf '%s\n' "$cmd" \
	 | sed -e 's/ -c / /' \
	       -e 's/ -o [^ ]*//' \
	       -e 's/ -MT [^ ]*//' -e 's/ -MF [^ ]*//' \
	       -e 's/ -MMD//' -e 's/ -MP//' -e 's/ -MD//')
  case "$pp" in
    *" -c "*|*" -o "*|*" -MF "*) echo "FATAL: $o -- strip left a compile flag in: $pp"; exit 9 ;;
  esac
  # Through a temp SCRIPT, not through `nix-shell --run "<cmd>"': the recipes
  # carry quoted -D values (-DBASE_HEADER='"..."'), and --run re-parses its
  # argument, so the quoting is lost and the flags after it are handed to the
  # linker.  That failed as `ld: cannot find -E' -- a diagnostic about the
  # instrument wearing the shape of a diagnostic about the build.
  tmp="$D/tb1-pp.sh"
  { echo "cd $D/gcc"; printf '%s -E -dM\n' "$pp"; } > "$tmp"
  out=$(sh "$S/eb-shell.sh" "sh $tmp" 2>/dev/null || true)
  n=$(printf '%s\n' "$out" | grep -c '^#define ' || true)
  if [ "$n" -lt 500 ]; then
    echo "FATAL: $o -- only $n macros recovered; the -dM run did not preprocess"
    exit 9
  fi
  printf '%-28s (%s macros)\n' "$o" "$n"
  for m in $WANT; do
    v=$(printf '%s\n' "$out" | awk -v m="$m" '$1=="#define" && $2==m {$1="";$2="";print substr($0,3); found=1} END{if(!found) print "<ABSENT>"}')
    printf '    %-24s %s\n' "$m" "$v"
  done
done

[ "$nprobe" -ge 5 ] || { echo "FATAL: only $nprobe compile commands recovered of 6"; exit 9; }
echo "probes scored: $nprobe"
