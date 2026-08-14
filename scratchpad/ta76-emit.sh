#!/bin/sh
# "Emits real code a real assembler accepts, FOR THE MACHINE IT MEANT."
#
# Derived from t170-emit.sh.  Five arms, scored INDEPENDENTLY because they
# fail for different reasons and a single verdict would hide which:
#
#   1 emits?    does cc1 exit 0 and write a non-empty .s
#   2 x86-leak? does that .s contain x86 register/mnemonic tokens
#   3 asm?      does THAT TARGET'S OWN real assembler accept it
#   4 machine?  is the resulting object's ELF machine the right one
#   5 WORD?     does the compiler agree with the target about sizeof(long)
#
# ARM 5 IS THE ONE THIS SCRIPT ADDS, AND THE REASON IS RECORDED IN PRINCIPLES:
# riscv64 passed arms 1-4 while emitting 32-bit code into an ELF64 object.
# Arms 3 and 4 are a floor, not a proof -- an assembler validates syntax for a
# machine, not that the compiler meant that machine.  Arm 5 reads the size of
# `char mt_word_long[sizeof (long)]' straight out of the emitted `.s' (see
# ta9f-word.c), which needs no assembler and therefore covers the four back
# ends that have none anywhere in this nixpkgs.
#
# Arm 5 also runs at -O0 deliberately: it is a question about the target, not
# about optimisation, and a back end that only emits at -O0 can still answer.
#
# usage: ta9f-emit.sh <builddir> <snapshot-srcdir> <toolroot>
set -u
D=${1:?build dir}
SRC=${2:?snapshot srcdir}
ROOT=${3:?tool root}
S=$(cd "$(dirname "$0")" && pwd)
case "$D" in
  */b-a76e996f6ef44dca5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D not configured from $SRC"; exit 9; }
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = "${WANT_ANCHOR:-55}" ] \
  || { echo "FATAL: snapshot anchor is not ${WANT_ANCHOR:-55}"; exit 9; }
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1"; exit 9; }
[ -f "$S/ta9f-word.c" ] || { echo "FATAL: no ta9f-word.c"; exit 9; }

# THE EXPECTED sizeof(long) PER TRIPLE, from the triple's own ABI and not from
# anything this compiler produced.  A scorer that derived the expectation from
# the artefact under test would be unable to fail.
want_long () {
  case "$1" in
    x86_64-*|aarch64-*|powerpc64-*|s390x-*|riscv64-*|mips64-*|sparc64-*|ia64-*) echo 8 ;;
    arm-*|visium-*|xtensa-*) echo 4 ;;
    *) echo "?" ;;
  esac
}

OUT=$D/ta9f-emit; mkdir -p "$OUT"
TRIPLES=$(grep -v '^#' "$S/t170-bases11.txt" | awk 'NF{print $2}')

printf '%-28s %-6s %-7s %-9s %-11s %-14s %s\n' \
  TARGET EMITS X86LEAK ASSEMBLES MACHINE 'WORD(long)' INPUT
: > "$OUT/TABLE"
for t in $TRIPLES; do
  cfg=$(ls "$D"/lib/gcc/*/"$t"/specs-config 2>/dev/null | head -1)
  if [ -z "$cfg" ]; then
    printf '%-28s %-6s %-7s %-9s %-11s %-14s %s\n' "$t" NO-CFG - - - - "no specs-config"
    echo "$t|NO-CFG|-|-|-|-|no specs-config" >> "$OUT/TABLE"
    continue
  fi

  # ---- ARM 5 first, at -O0, because it is the arm that can answer for a back
  # end that never reaches -O2, and because a back end wrong about its own
  # word size makes every later arm's green meaningless.
  wl=UNKNOWN
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O0 -ftarget-config="$cfg" \
      "$S/ta9f-word.c" -o "$OUT/$t.word.s" ) \
      > "$OUT/$t.word.out" 2> "$OUT/$t.word.err"
  if [ -s "$OUT/$t.word.s" ]; then
    # `.comm mt_word_long,8,8' or `.size mt_word_long, 8' -- target-neutral text.
    got=$(grep -E '(\.comm|\.size|\.zero|\.space|\.skip)[^;]*mt_word_long|mt_word_long[^:]*,' \
            "$OUT/$t.word.s" \
          | grep -oE '[0-9]+' | head -1)
    w=$(want_long "$t")
    if [ -z "$got" ]; then
      # fall back to the .size line that FOLLOWS the label
      got=$(awk '/^mt_word_long:/{f=1} f&&/\.size[ \t]+mt_word_long/{print;exit}' \
              "$OUT/$t.word.s" | grep -oE '[0-9]+$')
    fi
    if [ -z "$got" ]; then wl="NOSYM"
    elif [ "$got" = "$w" ]; then wl="ok:$got"
    else wl="WRONG:$got/$w"; fi
  else
    wl="NO-EMIT"
  fi

  # ---- arms 1-4, on big.c first, the portable file only if big.c does not fit.
  emit=FAIL; input=; sfile=
  for in in "$SRC/scratchpad/big.c" "$SRC/scratchpad/t170-small.c"; do
    tag=$t.$(basename "$in" .c)
    ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$cfg" \
        "$in" -o "$OUT/$tag.s" ) > "$OUT/$tag.out" 2> "$OUT/$tag.err"
    r=$?
    if [ $r = 0 ] && [ -s "$OUT/$tag.s" ]; then
      emit=OK; input=$(basename "$in"); sfile=$OUT/$tag.s; break
    fi
  done
  if [ "$emit" != OK ]; then
    c=$(head -3 "$OUT/$t.t170-small.err" | tr '\n' ' ' | cut -c1-80)
    printf '%-28s %-6s %-7s %-9s %-11s %-14s %s\n' "$t" FAIL - - - "$wl" "$c"
    echo "$t|FAIL|-|-|-|$wl|$c" >> "$OUT/TABLE"
    continue
  fi

  if [ "$t" = x86_64-pc-linux-gnu ]; then
    leak=n/a
  elif grep -Eqw '%rsp|%rbp|%rax|%eax|%edi|leaq|movq|pushq' "$sfile"; then
    leak=YES
  else
    leak=no
  fi

  d="$ROOT/$t"
  if [ ! -x "$d/$t-as" ]; then
    printf '%-28s %-6s %-7s %-9s %-11s %-14s %s\n' "$t" OK "$leak" NO-AS UNKNOWN "$wl" "$input"
    echo "$t|OK|$leak|NO-AS|UNKNOWN|$wl|$input" >> "$OUT/TABLE"
    continue
  fi
  if "$d/$t-as" -o "$OUT/$t.o" "$sfile" > "$OUT/$t.asout" 2> "$OUT/$t.aserr"; then
    asm=OK
    mach=$("$d/$t-readelf" -h "$OUT/$t.o" | sed -n 's/^ *Machine: *//p')
  else
    asm=FAIL; mach=-
  fi
  printf '%-28s %-6s %-7s %-9s %-11s %-14s %s\n' "$t" OK "$leak" "$asm" "$mach" "$wl" "$input"
  echo "$t|OK|$leak|$asm|$mach|$wl|$input" >> "$OUT/TABLE"
done

# NON-VACUITY FOR ARM 5.  An all-UNKNOWN word column looks exactly like "no
# back end has this bug"; PRINCIPLES section 7 requires the harness to refuse
# to score when it cannot show it read anything.
n_ok=$(grep -c '|ok:' "$OUT/TABLE" || true)
echo
echo "arm-5 non-vacuity: $n_ok target(s) answered the word-size question correctly"
[ "$n_ok" -ge 1 ] || { echo "FATAL: arm 5 read nothing anywhere -- not scoring"; exit 9; }

echo
echo "== sizes / md5 of each .s (quote WITH the input path; -S emits .file)"
for f in "$OUT"/*.s; do
  [ -f "$f" ] || continue
  echo "  $(basename "$f")  $(wc -c < "$f") bytes  md5 $(md5sum < "$f" | cut -c1-12)"
done
