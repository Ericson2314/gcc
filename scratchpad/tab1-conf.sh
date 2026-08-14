#!/bin/sh
# Configure an ELEVEN-back-end build dir FROM AN IMMUTABLE SNAPSHOT, optionally
# with AddressSanitizer in the compiler itself (MT_SAN=1).
#
# WHY AN ASAN cc1.  mips64 and ia64 are nondeterministic at -O2 (5 emit / 7
# SIGSEGV in twelve mips runs; five distinct outcomes in eight ia64 runs) and
# never fault under gdb, which disables ASLR.  That is memory corruption, and
# the instrument that names a corruption is ASAN, not a debugger.
#
# THE BUILD DIR IS NAMED AFTER THE FULL WORKTREE ID, not a task number
# (PRINCIPLES section 5: /tmp/b<task> collides by construction, and a guard
# matching truncated ids protected nothing while deleting 207 directories).
#
# usage: tab1-conf.sh <snapdir> <builddir> [comma-list|file]
set -e
S=$(cd "$(dirname "$0")" && pwd)
SNAP=${1:?snap dir}
D=${2:?build dir}
LIST=${3:-$S/t170-bases11.txt}
if [ -f "$LIST" ]; then
  LIST=$(grep -v '^#' "$LIST" | awk 'NF{print $1}' | tr '\n' ',' | sed 's/,$//')
fi
[ -n "$LIST" ] || { echo "FATAL: empty triple list"; exit 9; }

# EXACT, never >=.  A tree missing a landed change must fail here rather than
# silently produce a green for a compiler that is not this one.
WANT=${WANT_ANCHOR:-49}
n=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SNAP anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SNAP" && git diff --quiet ) || { echo "FATAL: $SNAP is dirty"; exit 9; }

case "$D" in
  */b-agent-ab1fcb485731b7a4d*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac

if [ "${MT_SAN:-0}" = 1 ]; then
  # -O1 not -O2: ASAN at -O2 on GCC's own sources is very slow to build and
  # inlining costs stack frames in the report.  -fno-omit-frame-pointer is what
  # makes the malloc/free stacks readable.  -fsanitize=undefined is added
  # because this branch has a known shift-by-219 in AARCH64_APPROX_MODE.
  SAN="-fsanitize=address -fsanitize=undefined -fno-sanitize=vptr -fno-omit-frame-pointer -g -O1"
  TAG=ASAN
else
  SAN="-O2 -g0"
  TAG=NORMAL
fi
echo "flags: $TAG"

nt=$(echo "$LIST" | tr ',' '\n' | grep -c .)
echo "srcdir $SNAP anchor=$n OK; $nt triples"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SNAP/configure \
  --disable-werror \
  --enable-targets=$LIST \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='$SAN -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='$SAN -Wno-error=format-security' \
  --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
echo "configure rc=$?"
grep -m1 'running configure' "$D/config.log" || true
echo "$SNAP" > "$D/MY-SRC"
echo "$TAG" > "$D/MY-FLAGS"
tail -3 "$D/conf.err"
