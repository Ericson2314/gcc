#!/bin/sh
# The `.type' / `.align' directives a multi-target compiler ACTUALLY EMITS,
# and whether that target's OWN assembler accepts them.
#
# WHY A `.s' DIFF AND NOT A BOARD.  A660907426E03E4E9-ARM-BOARD.md 5 records
# `ASM_OUTPUT_ALIGN' as costing ZERO test results while being wrong: the wrong
# directive assembles cleanly into a correct-machine object and every test
# passes.  A PASS/FAIL board cannot see that class at all, so the instrument
# has to read the assembly.  `TYPE_OPERAND_FMT' is only visible to a board
# because ONE of the five measured assemblers happens to object.
#
# BOTH-SIDED BY CONSTRUCTION.  Every target is compiled with BOTH compilers and
# the two `.s' are compared, so the output is always "N changed, M
# byte-identical, K differ-but-unexpected" and never a bare list of what the
# new compiler did.  A run in which NOTHING changed is a legitimate result and
# prints as such; it is the one thing a single-sided probe cannot express.
#
# `as' IS NAMED, NEVER DEFAULTED.  A target with no cross assembler in $TOOLS
# is listed as SKIPPED-NO-AS by name.  Falling back to the host `as' is GUARD
# 3c's own failure mode: x86_64's assembler accepts `@object' and would score
# every target green.
#
# usage: OLD=<builddir> NEW=<builddir> TOOLS=<toolsdir> sh ...-tdprobe.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
if [ "${MT_INSHELL:-}" != 1 ]; then
  exec sh "$S/eb-shell.sh" "MT_INSHELL=1 OLD='${OLD:?}' NEW='${NEW:?}' TOOLS='${TOOLS:?}' sh '$0'"
fi
OLD=${OLD:?set OLD to the before build dir}
NEW=${NEW:?set NEW to the after build dir}
TOOLS=${TOOLS:?set TOOLS to the cross-tools dir}
W=/tmp/tdprobe-$$; mkdir -p "$W"

cat > "$W/t.c" <<'EOF'
int gvar = 1;
static int svar = 2;
int *use (void) { return &svar; }
int fn (int x) { return x + 1; }
EOF

# The targets that HAVE a `specs-config' in both build dirs.  Read from the
# build, not typed: a target listed here that the build never configured would
# be compiled by the wrong specs and the row would be a fiction.
TGTS=$(cd "$OLD/lib/gcc" 2>/dev/null && ls */ -d 2>/dev/null >/dev/null; \
       find "$OLD/lib/gcc" -name specs-config 2>/dev/null \
         | sed 's|.*/\([^/]*\)/specs-config|\1|' | sort -u)
[ -n "$TGTS" ] || { echo "FATAL: no specs-config under $OLD/lib/gcc"; exit 9; }

changed=0; same=0; skipped=0; failed=0
for T in $TGTS; do
  CFGO="$OLD/lib/gcc/17.0.0/$T/specs-config"
  CFGN="$NEW/lib/gcc/17.0.0/$T/specs-config"
  if [ ! -f "$CFGN" ]; then
    echo "$T  SKIPPED-NO-SPECS-CONFIG-IN-NEW"; skipped=$((skipped+1)); continue
  fi
  for side in old new; do
    case $side in
      old) B=$OLD; C=$CFGO ;;
      new) B=$NEW; C=$CFGN ;;
    esac
    "$B/gcc/xgcc" -B"$B/gcc/" -ftarget-config="$C" -O0 -S "$W/t.c" \
        -o "$W/$T.$side.s" > "$W/$T.$side.err" 2>&1 || echo "COMPILE-FAIL $T $side"
  done
  if [ ! -s "$W/$T.old.s" ] || [ ! -s "$W/$T.new.s" ]; then
    echo "$T  COMPILE-FAILED (see $W/$T.*.err)"; failed=$((failed+1)); continue
  fi
  if cmp -s "$W/$T.old.s" "$W/$T.new.s"; then
    verdict=IDENTICAL; same=$((same+1))
  else
    verdict=CHANGED; changed=$((changed+1))
  fi
  told=$(grep -m1 '\.type' "$W/$T.old.s" | sed 's/^[ \t]*//')
  tnew=$(grep -m1 '\.type' "$W/$T.new.s" | sed 's/^[ \t]*//')
  aold=$(grep -m1 '\.p2align\|\.balign\|\.align' "$W/$T.old.s" | sed 's/^[ \t]*//')
  anew=$(grep -m1 '\.p2align\|\.balign\|\.align' "$W/$T.new.s" | sed 's/^[ \t]*//')

  # THE ASSEMBLER IS CHOSEN BY NAME, INCLUDING THE HOST'S.
  # x86_64-pc-linux-gnu IS the build machine's target, so `as' from the dev
  # shell is that target's own assembler and not a fallback -- but it is
  # spelled out for x86_64 ALONE.  Letting any other target reach a bare `as'
  # is GUARD 3c's failure mode: x86_64's assembler accepts `@object', so a
  # silent fallback would score arm ASSEMBLES and delete the entire finding.
  # amdgcn/nvptx are named as having no assembler here rather than defaulted.
  case $T in
    x86_64-pc-linux-gnu) AS=$(command -v as || echo /nonexistent) ;;
    *amdgcn*|*nvptx*)    AS=/nonexistent-by-name ;;
    *)                   AS=$TOOLS/bin/$T-as ;;
  esac
  if [ -x "$AS" ]; then
    "$AS" -o "$W/$T.new.o" "$W/$T.new.s" 2> "$W/$T.as.err" && asv=ASSEMBLES \
      || asv="AS-REJECTS: $(grep -m1 -i 'error' "$W/$T.as.err" | sed 's|.*\.s:||')"
    "$AS" -o "$W/$T.old.o" "$W/$T.old.s" 2> "$W/$T.asold.err" && asvo=ASSEMBLES \
      || asvo="AS-REJECTS: $(grep -m1 -i 'error' "$W/$T.asold.err" | sed 's|.*\.s:||')"
  elif [ "$AS" = /nonexistent-by-name ]; then
    asv="SKIPPED-NO-ASSEMBLER-BY-NAME ($T)"; asvo=$asv
  else
    asv="SKIPPED-NO-AS ($AS)"; asvo=$asv
  fi
  echo "== $T  $verdict"
  echo "     .type   old: ${told:-<none>}"
  echo "     .type   new: ${tnew:-<none>}"
  echo "     .align  old: ${aold:-<none>}"
  echo "     .align  new: ${anew:-<none>}"
  echo "     as old: $asvo"
  echo "     as new: $asv"
done
echo "-- $changed changed, $same byte-identical, $failed compile-failed, $skipped skipped"
echo "-- artefacts kept in $W"
