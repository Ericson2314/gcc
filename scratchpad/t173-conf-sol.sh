#!/bin/sh
# #173 -- solaris and openvms FIRST for their cpu_type, with no competing
# linux record ahead of them.
#
# WHY THIS CONFIGURATION EXISTS.  In the mixed build, sol2-c.o and vms-c.o
# appear in NO rule, while config.gcc:1131/1153 plainly put them in
# c_target_objs.  gen-multi-target-md.awk unions `extra_gcc_objs' over every
# record for a cpu_type and says so at length (the darwin-driver.o comment),
# but takes `c_target_objs' from the FIRST record only -- so sparc64-linux
# ahead of sparc-sun-solaris2.11 silently drops sol2-c.o.  If that is the
# cause, putting solaris first must make it reappear.  If it appears anyway,
# the story is wrong and the cause is elsewhere.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC to an immutable snapshot worktree}
SRC=$(cd "$SRC" && pwd)
D=${1:?build dir}
WANT=${WANT_ANCHOR:?set WANT_ANCHOR}
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SRC" && git diff --quiet ) || { echo "FATAL: $SRC is not clean"; exit 9; }
case "$D" in
  */b-a7d1e0*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac

LIST=${MT_LIST:-x86_64-pc-linux-gnu,sparc-sun-solaris2.11,ia64-hp-openvms}
rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror --enable-targets=$LIST \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
echo "configure rc=$?  list=$LIST"
echo "$SRC" > "$D/MY-SRC"
