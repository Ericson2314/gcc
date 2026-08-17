#!/bin/sh
# agent-ae59966cf819d72ef-jtfamily.sh -- rank the JUMP-TABLE EMISSION family of
# `final.cc:2476-2600', the six macros that decide how a case vector is written.
#
# `ADDR_VEC_ALIGN' (converted on `agent-a4568de8f522450d3-mt') is the ALIGNMENT
# of that table.  These six are the table's CONTENTS.  They sit in the same
# `#ifdef' block, they are read only by `final.cc', and every one of them is
# answered by whichever base compiles `final.cc' -- i.e. i386.
#
# WHAT THE RANKING NEEDS, per PRINCIPLES: is it READ in shared code and how
# often; does i386's answer DIFFER, and is the difference a VALUE or an
# EXISTENCE; is it on an `#if' line (so it cannot become a runtime value); does
# it produce WRONG code or merely worse.
#
# NEGATIVE CONTROL: `ASM_OUTPUT_ALIGN' must show a HIGH definer count and be
# defined by i386, i.e. the shape this scan must NOT flag as a leaked absence.
# Without it a scan that prints "i386=0" for everything looks identical to a
# correct one.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
cd "$W/gcc"

def_count () {
  git grep -lE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$1\b" -- config/ | grep -c .
}
i386_defines () {
  git grep -lE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$1\b" -- config/i386/ | grep -c .
}
shared_sites () {
  git grep -nE "\b$1\b" -- '*.cc' '*.h' ':(exclude)config' ':(exclude)doc' | grep -c .
}

printf '%-28s %8s %6s %7s  %s\n' MACRO DEFINERS i386 SITES SHAPE
for m in ASM_OUTPUT_ADDR_VEC ASM_OUTPUT_ADDR_DIFF_VEC \
         ASM_OUTPUT_ADDR_VEC_ELT ASM_OUTPUT_ADDR_DIFF_ELT \
         ASM_OUTPUT_CASE_LABEL ASM_OUTPUT_CASE_END \
         ASM_OUTPUT_ALIGN ; do
  d=$(def_count "$m"); i=$(i386_defines "$m"); s=$(shared_sites "$m")
  # SHAPE: does any shared site put the name on a preprocessor conditional?
  if git grep -nE "^[[:space:]]*#[[:space:]]*(if|ifdef|ifndef|elif).*\b$m\b" \
       -- '*.cc' '*.h' ':(exclude)config' ':(exclude)doc' | grep -q .; then
    sh_=IFDEF
  else
    sh_=PLAIN
  fi
  case "$i" in 0) leak='LEAKED-ABSENCE (i386 defines nothing)';;
               *) leak="LEAKED-VALUE (i386's own)";; esac
  printf '%-28s %8s %6s %7s  %s %s\n' "$m" "$d" "$i" "$s" "$sh_" "$leak"
done

echo
echo "== NEGATIVE CONTROL"
c=$(i386_defines ASM_OUTPUT_ALIGN)
if [ "$c" -gt 0 ]; then
  echo "  ok: ASM_OUTPUT_ALIGN is defined by i386 ($c files), so the 'i386=0'"
  echo "      rows above are a property of those macros, not of this scan."
else
  echo "  FATAL: the control reads 0 too -- the definer grep matches nothing"
  echo "         and every row above is meaningless."
  exit 9
fi

echo
echo "== WHICH BACK ENDS DEFINE THE WHOLE-TABLE FORM (the arm that never runs)"
for m in ASM_OUTPUT_ADDR_VEC ASM_OUTPUT_ADDR_DIFF_VEC; do
  echo "  $m:"
  git grep -lE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$m\b" -- config/ \
    | sed 's|^config/|    |'
done

echo
echo "== THE ELEMENT FORM: what i386 says, and two back ends that disagree"
git grep -nE "^[[:space:]]*#[[:space:]]*define[[:space:]]+ASM_OUTPUT_ADDR_VEC_ELT\b" \
  -- config/i386/ config/mips/ config/avr/ config/rs6000/ | sed 's/^/  /'
