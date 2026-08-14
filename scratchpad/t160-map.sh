#!/bin/sh
# #160 PART A -- THE PAIRWISE/TRIPLE MAP.
#
# For each of the 48 back ends X: what blocks `{i386, aarch64, X}' from
# producing a linked cc1?
#
# A SYMBOL-LEVEL PREDICTOR over ONE 48-base build, not 48 builds.  It is
# validated against real 3-base builds by t160-validate.sh -- per the brief,
# "a predictor nobody checked is worth less than nothing here".
#
# THE MODEL
#
#   LINK   the objects cc1 actually links: $(OBJS) + $(OBJS-libcommon-target)
#          + $(OBJS-libcommon) + $(C_OBJS) + $(EXTRA_BACKEND_OBJS) + main.o.
#          Getting this set wrong is the first thing this script got wrong:
#          with $(OBJS) alone, `hooks.o' is absent -- it lives in
#          libcommon-target.a -- and EVERY back end scored 12-41 bogus
#          undefined `hook_*' defaults.  46 false blockers from one omission.
#   SH     LINK minus every $(MULTI_TARGET_OBJS_<cpu>): the shared half.
#   LIB    definitions from libiberty/libcpp/libdecnumber/libbacktrace and
#          from libc/libstdc++/libm.  Needed for the same reason: the
#          {i386,aarch64} pair simply does not reference `strverscmp',
#          `sqrtf', `__memmove_chk' or `std::stringstream', so a
#          baseline-subtraction alone scores those as back-end blockers.
#          They are reported as EXTERNAL, not silently dropped.
#
#   BLOCKED-NOBJ  an object in MULTI_TARGET_OBJS_X was never built.  Read from
#                 the FILESYSTEM: under -k "never attempted" and "passed" are
#                 the same silence (PRINCIPLES section 1).
#   BLOCKED-MULTI defs(X) intersect defs(SH) + defs(i386) + defs(aarch64),
#                 strong (nm T/D/B/R) only.
#   BLOCKED-UNDEF undefs(triple) minus defs(triple) minus LIB, and minus the
#                 baseline the known-good {i386,aarch64} link already leaves
#                 open.
#
# BLIND SPOTS, stated per PRINCIPLES section 4 rule 5:
#   - COMDAT/weak (`W',`V') definitions are NOT scored as collisions.  The
#     linker keeps one body by link order and says nothing; #52 is exactly
#     this shape and no symbol sweep can see it.  Counted separately so the
#     number is visible rather than absent.
#   - libbackend.a is an ARCHIVE: `ld' diagnoses only collisions whose members
#     are both pulled in.  This sweep OVER-counts what ld prints and accurately
#     counts what is actually duplicated.
#   - Macros expanding to option state (`global_options.x_*') are invisible to
#     nm by construction (PRINCIPLES section 4).  Nothing here sees them.
#   - This reads ONE 48-base build.  Anything that only appears when the base
#     set changes the GENERATED files -- the selector, the unioned mode
#     numbering, gengtype markers -- is invisible to it.  The riscv ICE and
#     segfault recorded for the {i386,aarch64,riscv} build are exactly that,
#     and this predictor says riscv LINKS, which is what that build also said.
#     LINK IS NOT WORKS.  The table's verdict is about the linker only.
#
# usage: t160-map.sh <builddir> <buildtag>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
TAG=${2:?build tag whose .rc stamp authorises scoring}
G="$B/gcc"
O="$B/t160"

# ---------------------------------------------------------------- arm 0
# NON-VACUITY FIRST -- refuse before reading anything, not after.

[ -f "$B/build-$TAG.rc" ] || {
  echo "REFUSING TO SCORE: no $B/build-$TAG.rc stamp."
  echo "  A log being written looks exactly like a log that finished; the"
  echo "  stamp is written only after make returns."; exit 9; }
echo "arm 0a ok: build-$TAG.rc present, make rc=$(cat "$B/build-$TAG.rc")"

[ -d "$G" ] || { echo "REFUSING TO SCORE: no $G"; exit 9; }
srcdir=$(awk '/^  \$ .*\/configure/ {sub(/^  \$ /,""); sub(/\/configure.*/,""); print; exit}' "$B/config.log")
[ -n "$srcdir" ] || { echo "REFUSING TO SCORE: config.log names no srcdir"; exit 9; }
anch=$(grep -c MULTI_TARGET "$srcdir/gcc/Makefile.in" 2>/dev/null || echo 0)
WANT=${WANT_ANCHOR:-48}
[ "$anch" = "$WANT" ] || {
  echo "REFUSING TO SCORE: $B was configured from $srcdir, anchor=$anch, want exactly $WANT"; exit 9; }
echo "arm 0b ok: the build's own testimony -- srcdir $srcdir anchor=$anch"

# nm/make are NOT on PATH outside the nix-shell (DEVSHELL.md), and a
# tool-not-found piped into grep -c scores 0 in the direction that makes the
# answer look clean.  Re-exec once, then assert.
if [ "${T160_INSHELL:-}" != "1" ]; then
  exec sh "$S/eb-shell.sh" "T160_INSHELL=1 sh $S/t160-map.sh $B $TAG"
fi
command -v nm >/dev/null || { echo "REFUSING TO SCORE: no nm"; exit 9; }
command -v make >/dev/null || { echo "REFUSING TO SCORE: no make"; exit 9; }

rm -rf "$O"; mkdir -p "$O"
mk() { make -C "$G" --no-print-directory --eval='t160-p-%: ; @echo $($*)' "t160-p-$1" 2>/dev/null; }

bases=$(grep -o '^MULTI_TARGET_OBJS_[a-z0-9_]* ' "$G/multi-target-md.mk" \
        | sed 's/MULTI_TARGET_OBJS_//' | tr -d ' ' | sort -u)
nb=$(printf '%s\n' "$bases" | grep -c . || true)
[ "$nb" -ge 3 ] || { echo "REFUSING TO SCORE: only $nb bases in multi-target-md.mk"; exit 9; }
echo "arm 0c ok: $nb bases"

for b in $bases; do
  mk "MULTI_TARGET_OBJS_$b" | tr ' ' '\n' | grep '\.o$' | sort -u > "$O/objs-$b.txt"
  [ -s "$O/objs-$b.txt" ] || { echo "REFUSING TO SCORE: base $b resolved to 0 objects"; exit 9; }
done
{ mk OBJS; mk OBJS-libcommon-target; mk OBJS-libcommon; mk C_OBJS; mk EXTRA_BACKEND_OBJS; echo main.o; } \
  | tr ' ' '\n' | grep '\.o$' | sort -u > "$O/objs-LINK.txt"
cat $(for b in $bases; do echo "$O/objs-$b.txt"; done) | sort -u > "$O/objs-anybase.txt"
comm -23 "$O/objs-LINK.txt" "$O/objs-anybase.txt" > "$O/objs-SH.txt"
ns=$(grep -c . "$O/objs-SH.txt")
[ "$ns" -gt 500 ] || { echo "REFUSING TO SCORE: only $ns shared objects; a make variable did not resolve"; exit 9; }
# The omission that produced 46 false blockers, asserted by name so it cannot
# come back silently.
grep -qx 'hooks.o' "$O/objs-SH.txt" || { echo "REFUSING TO SCORE: hooks.o not in the shared link set"; exit 9; }
echo "arm 0d ok: $ns shared objects, $(grep -c . "$O/objs-anybase.txt") per-base objects, hooks.o present"

# ------------------------------------------------------------------ nm
# MANGLED names throughout.  Demangling is for the report only: `awk '$0 ~ f''
# on a demangled C++ name matches nothing, because `()' is an empty regex
# group (PRINCIPLES section 7).
syms() {   # $1 = object list, $2 = out prefix
  while read -r f; do [ -f "$G/$f" ] && echo "$f"; done < "$1" > "$2-ex.txt"
  if [ -s "$2-ex.txt" ]; then
    ( cd "$G" && xargs -a "$2-ex.txt" nm --defined-only ) 2>/dev/null > "$2-nmd.txt"
    ( cd "$G" && xargs -a "$2-ex.txt" nm -u ) 2>/dev/null \
      | awk '$1=="U"{print $2}' | grep . | sort -u > "$2-undef.txt"
  else : > "$2-nmd.txt"; : > "$2-undef.txt"; fi
  awk '$2 ~ /^[TDBR]$/ {print $3}' "$2-nmd.txt" | grep . | sort -u > "$2-def.txt"
  awk '$2 ~ /^[WViu]$/ {print $3}' "$2-nmd.txt" | grep . | sort -u > "$2-weak.txt"
}
syms "$O/objs-SH.txt" "$O/SH"
[ -s "$O/SH-def.txt" ] || { echo "REFUSING TO SCORE: nm read no definitions from the shared objects"; exit 9; }
echo "arm 0e ok: nm read $(wc -l < "$O/SH-def.txt") shared definitions"
for b in $bases; do syms "$O/objs-$b.txt" "$O/$b"; done

# ---------------------------------------------------------------- LIB
# Everything cc1 links that is not a gcc/ object.  Without this, library
# symbols the i386+aarch64 pair happens never to reference score as back-end
# blockers -- `strverscmp' for microblaze, `sqrtf' for xtensa.
: > "$O/LIB-def.txt"
for a in "$B/libiberty/libiberty.a" "$B/libcpp/libcpp.a" \
         "$B/libdecnumber/libdecnumber.a" "$B/libbacktrace/.libs/libbacktrace.a" \
         "$B/libcody/libcody.a" "$B/zlib/libz.a"; do
  [ -f "$a" ] && nm --defined-only "$a" 2>/dev/null | awk '$2 ~ /^[TDBRWViu]$/ {print $3}' >> "$O/LIB-def.txt"
done
for l in libc.so.6 libm.so.6 libstdc++.so libgcc_s.so.1; do
  p=$(g++ -print-file-name=$l 2>/dev/null)
  # Shared-library symbols carry `@@GLIBC_2.2.5' version suffixes.  Left on,
  # every comparison against an object-file name misses, and the whole LIB
  # universe silently rescues nothing -- the witness names below are what
  # caught this.
  [ -f "$p" ] && nm -D --defined-only "$p" 2>/dev/null | awk '{print $NF}' | sed 's/@.*//' >> "$O/LIB-def.txt"
done
sort -u -o "$O/LIB-def.txt" "$O/LIB-def.txt"
nl=$(grep -c . "$O/LIB-def.txt")
[ "$nl" -gt 5000 ] || { echo "REFUSING TO SCORE: LIB universe is only $nl symbols; a library was not found"; exit 9; }
# Non-vacuity by NAME, not by count: these are the four that produced false
# blockers before LIB existed.  If the universe stops containing them the
# instrument has silently gone back to its broken state.
for w in strverscmp sqrtf fputs_unlocked; do
  grep -qx "$w" "$O/LIB-def.txt" || { echo "REFUSING TO SCORE: LIB universe lacks $w"; exit 9; }
done
echo "arm 0f ok: LIB universe $nl symbols, witnesses present"

# ------------------------------------------------------- ATTRIBUTION
#
# THE DEFECT THIS BLOCK EXISTS TO FIX, FOUND BY THE VALIDATION ARM AND NOT BY
# ANY AMOUNT OF RE-READING.  The first version of this script predicted `mips'
# LINKS.  The real {i386,aarch64,mips} build does not link:
# `insn_mips::unspecv_strings' and `..._len' are undefined.
#
# Cause: in a 48-base build `multi-target-select.o' -- a SHARED object --
# references `insn_<be>::' symbols for ALL 48 back ends.  Those references
# therefore land in the {i386,aarch64} BASELINE, which is then subtracted from
# every back end.  92 `unspecv_strings' references were being hidden that way,
# and the one that mattered was hidden with them.
#
# So every symbol must be ATTRIBUTED to the base it belongs to, by two routes:
#   - it is DEFINED by that base's objects, or
#   - its mangled name lies in that base's `insn_<be>' namespace.
# A symbol attributable to a base OUTSIDE the triple is dropped: a real 3-base
# build's selector would never name it.  A symbol attributable to a base
# INSIDE the triple is never absorbed into the baseline.
: > "$O/attrib.txt"
for b in $bases; do awk -v b="$b" '{print b, $0}' "$O/$b-def.txt" >> "$O/attrib.txt"; done
cat "$O"/*-undef.txt | sort -u > "$O/ALLUNDEF.txt"
# Parse the Itanium mangling by its LENGTH PREFIX, not by a character class.
# `_ZN9insn_mips15unspecv_stringsE': the 9 is the length of `insn_mips'.  A
# regex like `insn_\([a-z0-9_]*\)[0-9]' is greedy and swallows the following
# length digits -- it attributed the symbol above to a base called
# `mips10gen_absdf', and the witness assert below is what caught it.  Back-end
# names contain digits (`i386', `h8300', `c6x'), so no character class can do
# this job.
awk '/^_ZN[0-9]+insn_/ {
       n = 0; i = 4;
       while (substr($0, i, 1) ~ /[0-9]/) { n = n * 10 + substr($0, i, 1); i++ }
       ns = substr($0, i, n);
       if (substr(ns, 1, 5) == "insn_") print substr(ns, 6), $0;
     }' "$O/ALLUNDEF.txt" >> "$O/attrib.txt"
sort -u -o "$O/attrib.txt" "$O/attrib.txt"
# Non-vacuity BY NAME on the symbol that exposed the defect.
grep -q '^mips _ZN9insn_mips15unspecv_stringsE$' "$O/attrib.txt" \
  || { echo "REFUSING TO SCORE: attribution does not place insn_mips::unspecv_strings under mips"; exit 9; }
echo "arm 0g ok: $(grep -c . "$O/attrib.txt") symbol/base attributions, mips witness present"

# ------------------------------------------------------------- baseline
sort -u "$O/SH-def.txt" "$O/i386-def.txt" "$O/aarch64-def.txt" > "$O/PAIR-strong.txt"
sort -u "$O/PAIR-strong.txt" "$O/SH-weak.txt" "$O/i386-weak.txt" "$O/aarch64-weak.txt" \
        "$O/LIB-def.txt" > "$O/PAIR-def.txt"
sort -u "$O/SH-undef.txt" "$O/i386-undef.txt" "$O/aarch64-undef.txt" > "$O/PAIR-undef.txt"
# The baseline is what the KNOWN-GOOD pair cannot resolve for reasons that
# belong to nobody -- so anything attributable to any base is excluded from it.
awk '{print $2}' "$O/attrib.txt" | sort -u > "$O/attrib-syms.txt"
comm -23 "$O/PAIR-undef.txt" "$O/PAIR-def.txt" | comm -23 - "$O/attrib-syms.txt" > "$O/BASELINE-undef.txt"
nbl=$(grep -c . "$O/BASELINE-undef.txt" || true)
echo "arm 0h ok: the known-good {i386,aarch64} link leaves $nbl unattributable symbols"

# ------------------------------------------------------------- per base X
printf '%-12s %5s %5s %5s %5s  %s\n' BASE NOBJ MULTI UNDEF EXTRN CAUSE > "$O/TABLE.txt"
for b in $bases; do
  [ "$b" = i386 ] && continue
  [ "$b" = aarch64 ] && continue
  comm -23 "$O/objs-$b.txt" "$O/$b-ex.txt" > "$O/missing-$b.txt"
  nobj=$(grep -c . "$O/missing-$b.txt" || true)

  comm -12 "$O/$b-def.txt" "$O/PAIR-strong.txt" > "$O/multi-$b.txt"
  nm_=$(grep -c . "$O/multi-$b.txt" || true)

  # Symbols belonging to a base OUTSIDE this triple: a real 3-base build's
  # selector never names them, so they are not this triple's problem.
  # A name attributable to a base in the triple as well as to one outside it
  # must NOT be dropped -- otherwise a symbol X genuinely needs disappears
  # because some unrelated back end also defines it.
  awk -v x="$b" '$1 != x && $1 != "i386" && $1 != "aarch64" {print $2}' "$O/attrib.txt" \
    | sort -u > "$O/o1.txt"
  awk -v x="$b" '$1 == x || $1 == "i386" || $1 == "aarch64" {print $2}' "$O/attrib.txt" \
    | sort -u > "$O/o2.txt"
  comm -23 "$O/o1.txt" "$O/o2.txt" > "$O/others-$b.txt"
  sort -u "$O/PAIR-undef.txt" "$O/$b-undef.txt" | comm -23 - "$O/others-$b.txt" > "$O/tu.txt"
  sort -u "$O/PAIR-def.txt" "$O/$b-def.txt" "$O/$b-weak.txt" > "$O/td.txt"
  comm -23 "$O/tu.txt" "$O/td.txt" | comm -23 - "$O/BASELINE-undef.txt" > "$O/raw-undef-$b.txt"
  # LIB is already inside PAIR-def, so what survives here is genuinely
  # undefined by anything in the link.  EXTRN counts what LIB rescued, kept
  # visible rather than silently dropped.
  comm -12 "$O/raw-undef-$b.txt" "$O/LIB-def.txt" > "$O/extrn-$b.txt"
  cp "$O/raw-undef-$b.txt" "$O/undef-$b.txt"
  nu=$(grep -c . "$O/undef-$b.txt" || true)
  ne=$(grep -c . "$O/extrn-$b.txt" || true)

  if   [ "$nobj" -gt 0 ]; then c="NOBJ $(head -3 "$O/missing-$b.txt" | tr '\n' ' ')"
  elif [ "$nm_" -gt 0 ]; then  c="MULTI $(head -4 "$O/multi-$b.txt" | c++filt | tr '\n' ' ')"
  elif [ "$nu" -gt 0 ]; then   c="UNDEF $(head -4 "$O/undef-$b.txt" | c++filt | tr '\n' ' ')"
  else                          c="predicted LINKS"
  fi
  printf '%-12s %5s %5s %5s %5s  %s\n' "$b" "$nobj" "$nm_" "$nu" "$ne" "$c" >> "$O/TABLE.txt"
done
rm -f "$O/tu.txt" "$O/td.txt"
cat "$O/TABLE.txt"
echo
echo "predicted LINKS: $(grep -c 'predicted LINKS' "$O/TABLE.txt") of $(($(grep -c . "$O/TABLE.txt") - 1)) third bases"
echo "artefacts in $O"
