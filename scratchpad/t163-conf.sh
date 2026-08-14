#!/bin/sh
# #163/#154/#149 -- configure a FOUR-back-end build dir FROM AN IMMUTABLE
# SNAPSHOT.  Derived from t170-conf.sh.
#
# The base set is chosen by the QUESTIONS, not by habit:
#   x86_64    the base every shared TU is compiled against (the "primary")
#   aarch64   the second base, so anything both-sided has a second side
#   riscv64   #154 -- does the driver still segfault in riscv_compute_multilib
#   xstormy16 #149 -- is xstormy16 selectable at all
#
# WANT_ANCHOR stays EXACT (PRINCIPLES section 4: the number is not the
# invariant, the exactness is).  55 as of the forty-seven-back-end merge --
# MEASURED on the snapshot, not copied from a brief.
#
# usage: t163-conf.sh <snapdir> <builddir> [comma-list]
set -e
S=$(cd "$(dirname "$0")" && pwd)
SNAP=${1:?snap dir}
D=${2:?build dir}
LIST=${3:-x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu,riscv64-unknown-linux-gnu,xstormy16-elf}

WANT=${WANT_ANCHOR:-55}
n=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SNAP anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SNAP" && git diff --quiet ) || { echo "FATAL: $SNAP is dirty"; exit 9; }

# PRINCIPLES section 5: /tmp/b<task number> IS NOT YOUR OWN -- task numbers are
# handed out in neighbouring blocks and collide by construction.  Name it after
# the worktree.
case "$D" in
  */b-a83be9e6d5255ad9b*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac

nt=$(echo "$LIST" | tr ',' '\n' | grep -c .)
[ "$nt" = 4 ] || { echo "FATAL: $nt triples, expected 4"; exit 9; }
echo "srcdir $SNAP anchor=$n OK; $nt triples: $LIST"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SNAP/configure \
  --disable-werror \
  --enable-targets=$LIST \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
echo "configure rc=$?"
grep -m1 'running configure' "$D/config.log" || true
echo "$SNAP" > "$D/MY-SRC"
tail -3 "$D/conf.err"
