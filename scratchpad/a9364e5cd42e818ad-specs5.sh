#!/bin/sh
# `taa-specs.sh' with arm added -- FIVE targets, each probed with ITS OWN cross
# assembler and ITS OWN glibc headers.
#
# The fifth target is the point.  The acceptance for this task is that the
# `TYPE_OPERAND_FMT' fix is verified on aarch64 AS WELL AS arm, because aarch64
# is the target that proves the finding: it asks for `%object', it has been
# getting `@object' on every board this branch has taken, and its assembler
# accepts the wrong answer silently.  Probing arm alone would fix the row and
# leave the finding unmeasured.
#
# The md5s are printed and MUST ALL DIFFER: #113b measured that without real
# cross tools configure falls back to the build machine's own `as' and writes a
# file NAMING the target while DESCRIBING x86_64, with every name- and
# path-based check green.  The 232-line / 224-non-blank count is the stable
# bar; the md5 is a function of the probing toolchain's paths and is NOT one.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?set B to the build dir}
# NO APOSTROPHE IN THIS MESSAGE.  The text of a `${VAR:?msg}' is parsed by the
# shell, so `tools.sh's dir' opened a single quote and the whole file died with
# `unexpected EOF while looking for matching' -- reported at the LAST line, 51
# lines away from the cause.  PRINCIPLES 2a lists the unterminated quote as a
# diagnostic that has twice meant something was silently truncated; here it was
# the script itself.
TOOLS=${TOOLS:?set TOOLS to the dir made by a9364e5cd42e818ad-tools.sh}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
HDRX=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
TX=x86_64-pc-linux-gnu
CROSS="aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu s390x-ibm-linux-gnu arm-unknown-linux-gnueabihf"

sh "$S/a9364e5cd42e818ad-tools.sh" || exit 9

cmds="cd $B/gcc && make multi-target-specs && cd $B"
cmds="$cmds && make configure-target-specs-$TX TOOLS_DIR_FOR_$TX=\$nat \
  TARGET_SPECS_FLAGS_FOR_$TX=--with-native-system-header-dir=$HDRX"
for T in $CROSS; do
  H=$(cat "$TOOLS/$T.hdr")
  [ -d "$H" ] || { echo "FATAL: no headers for $T ($H)"; exit 9; }
  cmds="$cmds && make configure-target-specs-$T \
    TOOLS_DIR_FOR_$T=$TOOLS/bin \
    TARGET_SPECS_FLAGS_FOR_$T=--with-native-system-header-dir=$H"
done

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    echo \"native binutils: \$nat\"
    PATH=$TOOLS/bin:\$PATH; export PATH
    $cmds
  " > "$B/specs5.out" 2> "$B/specs5.err"
rc=$?
echo "specs rc=$rc"
[ "$rc" = 0 ] || tail -15 "$B/specs5.err"
# BASE-VER lives in the SRCDIR.  taa-specs.sh records reading it from the build
# dir instead, which left VER empty and printed ABSENT for all four targets on
# a run where all four had been written correctly.
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
[ -n "$VER" ] || { echo "FATAL: empty BASE-VER"; exit 9; }
echo "-- specs-config per target (identity, not a statistic):"
seen=0; md5s=
for T in $TX $CROSS; do
  F="$B/lib/gcc/$VER/$T/specs-config"
  if [ -f "$F" ]; then
    l=$(wc -l < "$F"); nb=$(grep -c . "$F"); m=$(md5sum < "$F" | cut -c1-12)
    printf '  %-30s wc -l %s  grep -c . %s  md5 %s\n' "$T" "$l" "$nb" "$m"
    [ "$l" = 232 ] && [ "$nb" = 224 ] || echo "    !! NOT 232/224 -- the stable bar moved"
    seen=$((seen+1)); md5s="$md5s $m"
  else
    printf '  %-30s ABSENT\n' "$T"
  fi
done
[ "$seen" = 5 ] || { echo "FATAL: $seen of 5 specs-config written"; exit 9; }
u=$(printf '%s\n' $md5s | sort -u | wc -l)
[ "$u" = 5 ] || { echo "FATAL: only $u distinct md5s among 5 targets -- a probe fell back to the host as"; exit 9; }
echo "-- 5 targets, 5 DISTINCT md5s: each probe used its own toolchain"
