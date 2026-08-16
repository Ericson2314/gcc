#!/bin/sh
# Gather every back end's cross tools into ONE dir under the CANONICAL triple.
#
# WHY THIS EXISTS.  The 47 back ends' assemblers are currently spread over ~6
# inherited directories built by five different agents by three different
# routes.  `agent-acda89931a903ec27-specs.sh' and the scorer each take a single
# $TOOLS, so without this the run silently covers whichever subset happens to
# be in the dir that was passed -- and a target whose tool is in ANOTHER dir is
# indistinguishable from a target that has none.
#
# THREE RULES, each paid for by a recorded failure:
#
#  1. **CANONICAL NAMES ONLY.**  The build's specs rule looks for `$(1)-as'
#     where $(1) is a member of MT_TARGET_SUBDIRS, i.e. the config.sub-canonical
#     spelling.  `astry2.sh' installed short spellings (`sh-elf-as') and
#     satisfied no rule at all, while an executable sh assembler sat in the
#     same directory under another name.
#  2. **COPY AND DEREFERENCE.**  Sources include `ln -sf' into `--no-out-link'
#     store paths, which have no GC root.  An inherited tools dir has already
#     been found to be entirely dangling symlinks; `ls' shows the names.
#  3. **EXECUTE-ASSERT AT THE DESTINATION NAME.**  Existence is not execution,
#     and the destination is what the harness runs.
#
# THE READELF COLUMN IS REPORTED SEPARATELY AND HONESTLY.  GUARD 3c needs a
# `$T-readelf'.  `agent-acda89931a903ec27-fulltools.sh' refuses in its header to
# drop one multi-arch readelf in under many target names -- and a later sweep
# did it anyway: the 45 `*-readelf' in the inherited gasbin dir have ONE md5
# between them.  Rather than silently inherit that, this script tags each
# readelf PER-TARGET (came with its own binutils build) or SHARED (the
# multi-arch binary under a target name) and prints the split.  The machine arm
# of GUARD 3c is still meaningful with a shared readelf -- reading EM_ back out
# of an object tests what the ASSEMBLER produced -- but "45 readelf" must never
# be quoted as 45 pieces of evidence.
set -u
S=$(cd "$(dirname "$0")" && pwd)
MAP="$S/agent-acda89931a903ec27-backends.txt"
OUT=${1:?output tools dir}
SRCLIST=${TOOLDIRS_FILE:?file listing candidate tool dirs, one per line}
mkdir -p "$OUT"

TOOLS="as ld nm ar ranlib objdump objcopy strip readelf size strings"
nas=0; noas=0
: > "$OUT/GATHER-REPORT.txt"
for row in $(cat "$MAP"); do
  be=$(echo "$row" | cut -d: -f1)
  T=$(echo "$row"  | cut -d: -f2)
  # already gathered and executable?
  if [ -x "$OUT/$T-as" ] && "$OUT/$T-as" --version 2>&1 | grep -q 'GNU assembler'; then
    nas=$((nas+1)); continue
  fi
  src=
  while read -r d; do
    [ -n "$d" ] || continue
    if [ -x "$d/$T-as" ] && "$d/$T-as" --version 2>&1 | grep -q 'GNU assembler'; then
      src=$d; break
    fi
  done < "$SRCLIST"
  if [ -z "$src" ]; then
    printf '%-12s %-30s NO-AS\n' "$be" "$T" >> "$OUT/GATHER-REPORT.txt"
    noas=$((noas+1)); continue
  fi
  for t in $TOOLS; do
    [ -e "$src/$T-$t" ] && cp -Lf "$src/$T-$t" "$OUT/$T-$t" 2>/dev/null
  done
  if "$OUT/$T-as" --version 2>&1 | grep -q 'GNU assembler'; then
    printf '%-12s %-30s OK  from %s\n' "$be" "$T" "$src" >> "$OUT/GATHER-REPORT.txt"
    nas=$((nas+1))
  else
    printf '%-12s %-30s COPY-BROKE from %s\n' "$be" "$T" "$src" >> "$OUT/GATHER-REPORT.txt"
    noas=$((noas+1))
  fi
done

# readelf: fill any gap from a multi-arch readelf, but SAY SO.
ref=$(ls "$OUT"/*-readelf 2>/dev/null | head -1)
nper=0; nshared=0; nnone=0
if [ -n "$ref" ]; then
  refmd5=$(md5sum < "$ref" | cut -d' ' -f1)
  for row in $(cat "$MAP"); do
    T=$(echo "$row" | cut -d: -f2)
    [ -x "$OUT/$T-as" ] || continue
    if [ ! -x "$OUT/$T-readelf" ]; then
      cp -Lf "$ref" "$OUT/$T-readelf" && nshared=$((nshared+1)) || nnone=$((nnone+1))
    elif [ "$(md5sum < "$OUT/$T-readelf" | cut -d' ' -f1)" = "$refmd5" ]; then
      nshared=$((nshared+1))
    else
      nper=$((nper+1))
    fi
  done
fi

echo "== gather report ($OUT/GATHER-REPORT.txt):"
cat "$OUT/GATHER-REPORT.txt"
echo
echo "AS-EXEC-OK=$nas  AS-MISSING=$noas  (of 47)"
echo "READELF: per-target=$nper  SHARED-MULTIARCH=$nshared  none=$nnone"
echo "  a SHARED readelf is one binary under many names -- real for the EM_"
echo "  machine arm, NOT 45 independent pieces of evidence."
[ "$nas" -gt 0 ] || { echo "FATAL: gathered nothing"; exit 9; }
