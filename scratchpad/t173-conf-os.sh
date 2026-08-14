#!/bin/sh
# #173 -- a SECOND configuration, whose only job is to settle the files that
# scored N (no rule at all) in the 47-back-end build.  N is a statement about
# THAT configuration, not about the file: sol2-c.cc and vms-c.cc are
# c_target_objs of an OS nobody selected, and the *-d.cc files need the D
# front end enabled.  Configure the OSes and the language, regenerate the
# makefile, and ask the same question again.
#
# Deliberately does NOT build: multi-target-md.mk and gcc/Makefile are all the
# classification reads, and they exist after `make multi-target-md.mk'.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC to an immutable snapshot worktree}
SRC=$(cd "$SRC" && pwd)
D=${1:?build dir}
WANT=${WANT_ANCHOR:?set WANT_ANCHOR}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SRC" && git diff --quiet && git diff --cached --quiet ) \
  || { echo "FATAL: $SRC is not clean"; exit 9; }
case "$D" in
  */b-a7d1e0*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac

# One triple per file under test, chosen from config.gcc's own case arms.
LIST=x86_64-pc-linux-gnu,x86_64-apple-darwin,powerpc-wrs-vxworks,\
sparc-sun-solaris2.11,ia64-hp-openvms,loongarch64-linux-gnu,\
aarch64-unknown-linux-gnu,arm-eabi,alpha-linux-gnu,mips64-elf,\
powerpc64-linux-gnu,s390x-linux-gnu,sparc64-linux,x86_64-unknown-freebsd14

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror \
  --enable-targets=$LIST \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
echo "configure rc=$?"
echo "$SRC" > "$D/MY-SRC"
tail -3 "$D/conf.err"
