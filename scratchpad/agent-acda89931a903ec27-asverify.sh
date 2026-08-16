#!/bin/sh
# ARM 4 -- does this `<triple>-as' actually answer for ITS OWN target?
#
# THIS IS THE BLOCKING GUARD.  `as --version' succeeding is NOT the bar:
# PRINCIPLES records riscv64 passing "a real cross assembler accepts the
# output and readelf reports the right machine" while emitting 32-bit code,
# and this project has already shipped a LITTLE-endian powerpc assembler under
# a BIG-endian name.  A tool that runs is not a tool answering for your target.
#
# WHAT IT CHECKS, and each is a defect this project has actually had:
#   e_machine  != EM_X86_64 (62)  -- the host `as' fallback, worth ~10,000
#                                    results per target (GUARD 3c)
#   e_machine  != 0               -- EM_NONE, i.e. the assembler produced an
#                                    object that names no architecture
#   EI_DATA                       -- endianness, against the expected table
#                                    below.  This is the wrong-endian-powerpc
#                                    defect, and the ONLY arm that catches it.
#   EI_CLASS                      -- 32 vs 64 bit, the riscv64 defect.
#   consistency                   -- the same triplet from two different
#                                    inputs, so a one-off is not banked.
#
# HOW THE ELF HEADER IS READ.  With `od', not `readelf'.  A host `readelf'
# cannot be assumed present, and `readelf' missing would pipe into a grep and
# score 0 -- PRINCIPLES' "a missing tool looks exactly like a zero result",
# which on this project was a `strings' that did not exist.  `od' is coreutils.
#     e_ident[4] = EI_CLASS   1=ELF32 2=ELF64
#     e_ident[5] = EI_DATA    1=LSB   2=MSB
#     e_machine  = bytes 18..19, byte order per EI_DATA
#
# NEGATIVE CONTROL is mandatory and runs FIRST: the host `as' is fed the same
# input and MUST be scored FAIL-HOST-AS.  If the control does not fire, the
# instrument cannot distinguish a target assembler from the host one and it
# refuses to score anything.  An instrument that cannot fail is not evidence.
#
# BLIND SPOT, stated: this reads the assembler's TARGET CONFIGURATION out of
# an object it produced.  It does NOT prove the assembler accepts that
# target's full instruction set -- for that the input would have to be 45
# hand-written per-target snippets, which is its own error surface.  It
# catches wrong-target, wrong-endian, wrong-width and host-fallback, which are
# the four failures this project has actually recorded.
set -u

BIN=${1:?directory of <triple>-as}
WORK=${WORK:-/tmp/asverify-$$}
mkdir -p "$WORK"

# Expected endianness per triple, READ FROM GCC'S OWN BACK END.
#
# The first version of this function was a hand-written table from memory and
# it was WRONG for ft32 (asserted MSB; `ft32.h:277' says `BYTES_BIG_ENDIAN 0').
# The guard fired, which is the good outcome -- but the lesson is that a
# hand-written expectation is the same error surface the guard exists to
# remove, and editing it to match the observation would have been the
# test-harness floor, PRINCIPLES 2a.
#
# So the authority is `gcc/config/<backend>/<backend>.h', which is also the
# RIGHT authority: what we need is for the assembler to agree with the
# compiler that will feed it.  Where the macro is option-dependent
# (`m32r', `moxie', `mcore' -- `(! TARGET_LITTLE_ENDIAN)') no static answer
# exists and the arm reports `?' rather than inventing one.
GCCSRC=${GCCSRC:-gcc}
be_for_triple () {
  case $1 in
    hppa64-*) echo pa ;;   tic6x-*) echo c6x ;;
    powerpc*) echo rs6000 ;; nds32*) echo nds32 ;;
    v850*)    echo v850 ;;
    *)        echo "${1%%-*}" ;;
  esac
}
expect_for () {
  be=$(be_for_triple "$1")
  h="$GCCSRC/config/$be/$be.h"
  cls=?; end=?
  case $1 in
    hppa64-*|ia64-*|powerpc64-*|bpf-*) cls=64 ;;
    vax-*|bfin-*|cris-*|csky-*|epiphany-*|fr30-*|frv-*|ft32-*|h8300-*) cls=32 ;;
    iq2000-*|lm32-*|m32r-*|mcore-*|mn10300-*|moxie-*|pru-*|rl78-*) cls=32 ;;
    tic6x-*|v850*|visium-*|xstormy16-*|xtensa-*|nds32*) cls=32 ;;
  esac
  if [ -f "$h" ]; then
    v=$(grep -h 'define[[:space:]]*BYTES_BIG_ENDIAN' "$h" | head -1 \
        | sed 's/.*BYTES_BIG_ENDIAN[[:space:]]*//')
    case $v in
      1) end=MSB ;;
      0) end=LSB ;;
      *) end=? ;;          # option-dependent: no static answer
    esac
  fi
  echo "$cls $end"
}

# --- the two inputs.  Directives only: valid for every gas target. ---
printf '\t.text\n' > "$WORK/a.s"
printf '\t.text\n\t.align 2\n\t.byte 0\n' > "$WORK/b.s"

read_elf () {           # $1 = object -> "CLASS ENDIAN MACHINE" or "NOTELF"
  o=$1
  [ -s "$o" ] || { echo NOTELF; return; }
  magic=$(od -An -tx1 -N4 "$o" | tr -d ' ')
  [ "$magic" = "7f454c46" ] || { echo NOTELF; return; }
  cls=$(od -An -tu1 -j4 -N1 "$o" | tr -d ' ')
  dat=$(od -An -tu1 -j5 -N1 "$o" | tr -d ' ')
  b1=$(od -An -tu1 -j18 -N1 "$o" | tr -d ' ')
  b2=$(od -An -tu1 -j19 -N1 "$o" | tr -d ' ')
  if [ "$dat" = 2 ]; then m=$((b1*256+b2)); en=MSB; else m=$((b2*256+b1)); en=LSB; fi
  case $cls in 1) c=32 ;; 2) c=64 ;; *) c=? ;; esac
  echo "$c $en $m"
}

# ---------- NEGATIVE CONTROL: the host assembler must be caught ----------
HOSTAS=$(command -v as || true)
if [ -z "$HOSTAS" ]; then
  echo "FATAL: no host 'as' -- the negative control cannot run, refusing to score"
  exit 9
fi
"$HOSTAS" "$WORK/a.s" -o "$WORK/host.o" 2>/dev/null || true
HOSTTRIP=$(read_elf "$WORK/host.o")
HOSTM=$(echo "$HOSTTRIP" | awk '{print $3}')
if [ "$HOSTM" != "62" ]; then
  echo "FATAL: host 'as' gave e_machine '$HOSTM', expected 62 (EM_X86_64)."
  echo "       The control did not fire, so a host-'as' fallback would not be"
  echo "       detected.  Refusing to score."
  exit 9
fi
echo "control: host as -> $HOSTTRIP  (EM_X86_64=62, control FIRES)"
echo

npass=0; nfail=0
printf '%-30s %-4s %-4s %-6s %s\n' TRIPLE CLS END MACH VERDICT
for as in "$BIN"/*-as; do
  [ -x "$as" ] || continue
  t=$(basename "$as"); t=${t%-as}
  "$as" "$WORK/a.s" -o "$WORK/1.o" 2>/dev/null || true
  "$as" "$WORK/b.s" -o "$WORK/2.o" 2>/dev/null || true
  r1=$(read_elf "$WORK/1.o"); r2=$(read_elf "$WORK/2.o")
  cls=$(echo "$r1" | awk '{print $1}')
  end=$(echo "$r1" | awk '{print $2}')
  mach=$(echo "$r1" | awk '{print $3}')
  v=""
  if [ "$r1" = NOTELF ]; then
    # a.out / COFF targets (pdp11) are legitimate, but this arm cannot
    # verify them -- say so rather than passing or failing them silently.
    v="NOT-ELF-UNVERIFIED"
  elif [ "$r1" != "$r2" ]; then
    v="INCONSISTENT($r1 vs $r2)"
  elif [ "$mach" = 62 ]; then
    v="FAIL-HOST-AS"
  elif [ "$mach" = 0 ]; then
    v="FAIL-EM-NONE"
  else
    set -- $(expect_for "$t"); ec=$1; ee=$2
    if [ "$ec" != "?" ] && [ "$ec" != "$cls" ]; then
      v="FAIL-CLASS(want $ec got $cls)"
    elif [ "$ee" != "?" ] && [ "$ee" != "$end" ]; then
      v="FAIL-ENDIAN(want $ee got $end)"
    else
      v=OK
    fi
  fi
  case $v in
    OK) npass=$((npass+1)) ;;
    NOT-ELF-UNVERIFIED) ;;
    *)  nfail=$((nfail+1)) ;;
  esac
  printf '%-30s %-4s %-4s %-6s %s\n' "$t" "$cls" "$end" "$mach" "$v"
done

echo
echo "OK=$npass FAIL=$nfail"
[ $((npass+nfail)) -gt 0 ] || { echo "FATAL: scored zero assemblers"; exit 9; }
[ "$nfail" -eq 0 ] || exit 1
