#!/bin/sh
# A #246 WORKAROUND, AND NOTHING ELSE.  It is here so that #250's own arms can
# be measured; it is NOT part of #250's change and must not outlive #246.
#
# WHAT IT WORKS AROUND, measured: an installed `<triple>-gcc' with a real cross
# binutils on PATH runs cc1 correctly and then hands the assembly to the BUILD
# MACHINE's `as':
#
#   configure:3824: aarch64-unknown-linux-gnu-gcc -c conftest.c
#   /nix/store/...-gcc-wrapper-15.2.0/bin/as: unrecognized option '-EL'
#
# `-EL' is aarch64's; the assembler is x86_64's.  `just_machine_prefix'
# (gcc/gcc.cc:3274) is prepended in every machine-agnostic directory, and
# gcc/gcc.cc:9305 is its only assignment -- to "" -- inside `set_up_specs',
# which runs before the target is resolved.  So the driver looks for `as' and a
# cross binutils installs only `<triple>-as'.
#
# THESE ARE THE REAL CROSS TOOLS UNDER A SECOND NAME, NOT A SHIM AND NOT A
# FALLBACK.  Every symlink points at the aarch64 binutils; nothing here can
# resolve to the host's `as'.  The directory is passed with `-B' so the effect
# is confined to the one command line that uses it -- deliberately NOT a PATH
# entry, because a PATH entry would make the defect invisible everywhere else,
# which is the thing NIXPKGS-NOTE says not to do.
#
# usage: a7b00-t246-workaround.sh <out dir> <real tools bin> <triple>
set -eu
OUT=${1:?out dir}; TOOLS=${2:?tools bin}; T=${3:?triple}
mkdir -p "$OUT"
for t in as ld nm ar ranlib objdump objcopy strip readelf; do
  [ -e "$TOOLS/$T-$t" ] || continue
  ln -sf "$TOOLS/$T-$t" "$OUT/$t"
done
[ -x "$OUT/as" ] || { echo "FATAL: no $OUT/as"; exit 9; }
# `OK' must mean it RAN and is the RIGHT machine, not that a path exists.
printf 'f: ret\n' > "$OUT/.probe.s"
"$OUT/as" -o "$OUT/.probe.o" "$OUT/.probe.s"
m=$("$OUT/readelf" -h "$OUT/.probe.o" | sed -n 's/.*Machine: *//p')
echo "$OUT/as -> $(readlink "$OUT/as")"
echo "assembles to: $m"
case "$m" in
  *AArch64*|*ARM*|*X86-64*) ;;
  *) echo "FATAL: unexpected machine $m"; exit 9 ;;
esac
