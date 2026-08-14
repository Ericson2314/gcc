#!/bin/sh
# #170 -- build a per-target BINUTILS DIRECTORY for each of the eleven back
# ends that has real cross binutils in this nixpkgs, and PROVE each one is the
# assembler it claims to be before anything is measured with it.
#
# WHY A DIRECTORY OF SYMLINKS RATHER THAN THE STORE PATH DIRECTLY.  The triples
# this branch configures and the triples nixpkgs builds binutils for are not
# spelled the same:
#
#     configured triple             nixpkgs binutils prefix
#     powerpc64-linux-gnu           powerpc64-unknown-linux-gnuabielfv2-
#     s390x-linux-gnu               s390x-unknown-linux-gnu-
#     mips64-elf                    mips64-unknown-linux-gnuabi64-
#     arm-eabi                      armv7l-unknown-linux-gnueabihf-
#     aarch64-unknown-linux-gnu     aarch64-unknown-linux-gnu-      (exact)
#     riscv64-unknown-linux-gnu     riscv64-unknown-linux-gnu-      (exact)
#
# target-specs/configure looks up `${target}-as' by name, so on four of the six
# it would find nothing and take every probe's "no tool, assume the worst"
# branch -- pessimistic rather than obviously broken, which is the failure
# shape this project keeps paying for.  The symlink gives the REAL cross tool
# the name the probe looks up.  It is a rename, not a shim: nothing here
# produces output, it only forwards to genuine binutils.
#
# THIS IS THE DANGEROUS MOVE IN THIS TASK, so it carries its own arm.
# PRINCIPLES section 5 records that a probe run without cross binutils writes a
# file NAMING the target while DESCRIBING x86_64, and passes every name- and
# path-based check.  A wrongly-pointed symlink reproduces that exactly.  So
# every linked `as' is made to assemble an empty file and the resulting
# object's ELF machine is read back and compared with the machine that target
# is supposed to have.  A link pointing at the host `as' fails here by name.
#
# usage: t170-tools.sh <toolroot>
set -e
S=$(cd "$(dirname "$0")" && pwd)
ROOT=${1:?tool root dir}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"

# triple | nixpkgs pkgsCross attr (or "-" for the build machine) | expected
# `readelf -h' Machine: substring
SETS='
x86_64-pc-linux-gnu|-|X86-64
aarch64-unknown-linux-gnu|aarch64-multiplatform|AArch64
powerpc64-linux-gnu|ppc64|PowerPC64
s390x-linux-gnu|s390x|IBM S/390
riscv64-unknown-linux-gnu|riscv64|RISC-V
mips64-elf|mips64-linux-gnuabi64|MIPS
arm-eabi|armv7l-hf-multiplatform|ARM
'

rm -rf "$ROOT"; mkdir -p "$ROOT"
echo "$SETS" | grep . > "$ROOT/SETS"

for line in $(echo "$SETS" | grep . | tr ' ' '\001'); do
  line=$(printf '%s' "$line" | tr '\001' ' ')
  t=${line%%|*}; rest=${line#*|}; attr=${rest%%|*}; want=${rest#*|}
  d="$ROOT/$t"; mkdir -p "$d"
  if [ "$attr" = "-" ]; then
    bin=$(sh "$S/eb-shell.sh" 'dirname $(command -v as)')
  else
    p=$(nix-build --no-out-link -I "nixpkgs=$NP" \
          -E "(import <nixpkgs> {}).pkgsCross.$attr.buildPackages.binutils" \
          2>/dev/null | tail -1)
    [ -n "$p" ] || { echo "FATAL: no binutils store path for $attr"; exit 9; }
    bin="$p/bin"
  fi
  n=0
  for tool in as ld nm objdump readelf strip objcopy ar ranlib; do
    for cand in "$bin"/*-"$tool" "$bin/$tool"; do
      [ -x "$cand" ] || continue
      ln -sf "$cand" "$d/$t-$tool"
      ln -sf "$cand" "$d/$tool"
      n=$((n+1)); break
    done
  done
  [ "$n" -ge 5 ] || { echo "FATAL: $t: only $n tools linked from $bin"; exit 9; }
  echo "$bin" > "$d/FROM"
  echo "$want" > "$d/WANT-MACHINE"
  echo "$t: $n tools <- $bin"
done

echo
echo "== ARM: does each linked \`as' actually assemble for its own target?"
echo "   (a link pointing at the host as reproduces the section-5 lie exactly)"
fail=0
: > "$ROOT/MACHINES"
for line in $(echo "$SETS" | grep . | tr ' ' '\001'); do
  line=$(printf '%s' "$line" | tr '\001' ' ')
  t=${line%%|*}; want=${line##*|}
  d="$ROOT/$t"
  : > "$d/empty.s"
  if ! "$d/$t-as" -o "$d/empty.o" "$d/empty.s" 2> "$d/empty.aserr"; then
    echo "  $t: FAIL -- as rc!=0"; sed -n 1,3p "$d/empty.aserr"; fail=$((fail+1)); continue
  fi
  got=$("$d/$t-readelf" -h "$d/empty.o" | sed -n 's/^ *Machine: *//p')
  echo "$t|$got" >> "$ROOT/MACHINES"
  case "$got" in
    *"$want"*) echo "  $t: OK   Machine: $got" ;;
    *) echo "  $t: FAIL wanted '$want', got '$got'"; fail=$((fail+1)) ;;
  esac
done
echo "arm failures: $fail"
[ "$fail" = 0 ] || exit 9
