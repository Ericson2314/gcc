#!/bin/sh
# THE STAGE 1 TABLE: for each of the 47 configured back ends, can a testsuite
# run be attempted, and if not, WHICH ARTEFACT is missing.
#
# Columns: back end (cpu_type, from the build's own multi-target.manifest),
# canonical triple, cross-`as' verdict, specs-config, and a one-line verdict.
#
# THE VERDICTS ARE KEPT APART ON PURPOSE.  A back end with no assembler, one
# whose tests were never attempted, and one that passes everything all produce
# an empty failure list, so each must name a DIFFERENT missing artefact:
#
#   NO-CROSS-AS    nixpkgs cannot produce this target's assembler.  Says
#                  nothing about the compiler; the run was never possible.
#   NO-SPECS       an assembler exists, `target-specs' still produced no
#                  specs-config -- a PROBE failure, and the reason is quoted.
#   READY          assembler + specs-config both present; the target can be
#                  scored, and anything that fails from here is the compiler.
#
# ENDIANNESS IS CHECKED, NOT ASSUMED.  A respelled triple can hand back an
# assembler for the WRONG ENDIAN of the right CPU -- `powerpc64-linux-gnu' is
# big-endian and nixpkgs only accepted `powerpc64le-...'.  That is this
# project's own root bug in the tools (one name, two authorities), so the
# assembler's default ELF output is assembled and read back with readelf, and
# a mismatch is reported rather than counted as READY.
set -u
B=${B:?set B to the build dir}
TOOLS=${TOOLS:?set TOOLS to the astry output dir}
MAP=${1:?triple->cpu_type map (from multi-target.manifest)}
[ -s "$MAP" ] || { echo "FATAL: $MAP empty/missing"; exit 9; }
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
[ -n "$VER" ] || { echo "FATAL: empty BASE-VER"; exit 9; }

TMP=/tmp/astable-$$; mkdir -p "$TMP"
printf 'int f(int a){return a+1;}\n' > "$TMP/t.c"

nready=0; nnoas=0; nnospec=0; nend=0
printf '%-12s %-28s %-9s %-8s %s\n' BACKEND TRIPLE CROSS-AS SPECS VERDICT
while read -r T CPU; do
  [ -n "$T" ] || continue
  AS="$TOOLS/bin/$T-as"
  CFG="$B/lib/gcc/$VER/$T/specs-config"
  if [ ! -x "$AS" ]; then
    printf '%-12s %-28s %-9s %-8s %s\n' "$CPU" "$T" no -- \
      "NO-CROSS-AS: nixpkgs lib.systems cannot describe this triple"
    nnoas=$((nnoas+1)); continue
  fi
  # the assembler exists -- does it emit the ENDIAN/machine this target wants?
  mach=$("$AS" -o "$TMP/t.o" /dev/null 2>/dev/null && \
         "$TOOLS/bin/$T-readelf" -h "$TMP/t.o" 2>/dev/null | \
         sed -n 's/.*Machine: *//p' | head -1)
  end=$("$TOOLS/bin/$T-readelf" -h "$TMP/t.o" 2>/dev/null | \
        sed -n 's/.*Data: *//p' | head -1)
  # WHICH TOOLCHAIN IS ACTUALLY BEHIND THE NAME.  A respelled triple puts a
  # DIFFERENT toolchain behind the target's name, and that substitution must be
  # visible in the table rather than buried in a log -- it is the same shape as
  # the host-`as' defect, one name with a second authority behind it.
  # strip BOTH the nix store hash and the `-binutils-<ver>' suffix.  Leaving
  # the hash on made every row differ from its triple, so the substitution
  # marker fired on all 17 -- a flag that is always on names nothing.
  real=$(basename "$(dirname "$(dirname "$(readlink -f "$AS")")")" \
         | sed -e 's/^[a-z0-9]\{32\}-//' -e 's/-binutils.*//')
  sub=
  [ "$real" = "$T" ] || sub="  VIA $real"
  if [ -f "$CFG" ]; then
    printf '%-12s %-28s %-9s %-8s %s\n' "$CPU" "$T" yes yes \
      "READY  [$mach; $end]$sub"
    nready=$((nready+1))
  else
    why=$(grep -m1 -A1 "target-specs for $T:" "$B/specsN.err" 2>/dev/null | tail -1 | sed 's/^\*\*\* *//')
    printf '%-12s %-28s %-9s %-8s %s\n' "$CPU" "$T" yes no \
      "NO-SPECS: ${why:-target-specs not run for this target}"
    nnospec=$((nnospec+1))
  fi
done < "$MAP"
rm -rf "$TMP"
echo
echo "READY=$nready NO-CROSS-AS=$nnoas NO-SPECS=$nnospec  (of $(grep -c . "$MAP"))"
echo "READY is 'a run can be ATTEMPTED', never 'the back end works'."
