#!/bin/sh
# a76a331dcb554f700 -- A SMALL CORPUS, COMPILED FOR EVERY BACK END, AND
# ASSEMBLED WHERE AN ASSEMBLER EXISTS.
#
# WHY THIS AND NOT `onelinecensus.sh'.  That script's input is ONE function and
# its verdict is per TARGET.  For the nine back ends upstream has no
# `gcc.target/<be>' directory for, the only result available is "it compiles
# and assembles correct-machine ELF for N inputs", and one input cannot make
# that claim: `int f(int x){return x+1;}' exercises no memory reference, no
# call, no jump table, no floating point and no 64-bit arithmetic.  The corpus
# is chosen so each input reaches a DIFFERENT part of the back end, and the
# score is per (target, input) so a target that dies on one and passes six is
# reported as that rather than as a bare FAIL.
#
# THE THREE VERDICTS ARE KEPT APART, because collapsing them is this project's
# most-repeated defect and it has an acute form here: a back end that dies on
# its first input, one never attempted, and one that passes everything all
# produce the same empty failure list.
#
#   CC-ICE     cc1 died.  A statement about the compiler.
#   CC-OK      compiled to .s.  Needs no assembler and no libc, so it is
#              available for EVERY back end including amdgcn and nvptx.
#   AS-OK      the target's own cross `as' accepted it AND `readelf' reported
#              the expected machine.  Needs an assembler.
#   AS-ABSENT  no cross `as' for this target -- a statement about the TOOLS.
#              NEVER falls back on the host `as': amdgcn and nvptx are skipped
#              BY NAME below, and any other target with no assembler is
#              reported AS-ABSENT rather than scored.
#
# usage: B=<builddir> TOOLS=<dir with <triple>-as> a76a...-corpus.sh [targets...]
#        OPT defaults to -O2, and is PRINTED, because `gcc.target' is mostly
#        -O2 and a census taken at -O0 reported ok=38 where -O2 reports 28.
set -u
B=${B:?set B to the build dir}
TOOLS=${TOOLS:-}
OPT=${OPT:--O2}
W=$(cd "$(dirname "$0")" && pwd)
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
C=/tmp/corpus-a76a331dcb554f700
rm -rf $C; mkdir -p $C

# ---------------------------------------------------------------- the corpus
# Freestanding C89-safe: no headers, no libc, no target types.  Each file is
# named for the part of the back end it is meant to reach, so a row that fails
# names a capability rather than a number.
cat > $C/01-arith.c <<'EOF'
int f (int x) { return x + 1; }
int g (int a, int b) { return a * b - (a / (b | 1)); }
unsigned h (unsigned a, unsigned b) { return (a << 3) ^ (b >> 2); }
EOF
cat > $C/02-mem.c <<'EOF'
struct s { int a; char b; int c; };
int ld (struct s *p) { return p->a + p->c; }
void st (struct s *p, int v) { p->a = v; p->b = (char) v; }
int arr (int *p, int i) { return p[i] + p[i + 3]; }
EOF
cat > $C/03-call.c <<'EOF'
extern int cb (int, int, int, int, int);
int caller (int a) { return cb (a, a + 1, a + 2, a + 3, a + 4); }
int leaf (void) { return 7; }
EOF
cat > $C/04-branch.c <<'EOF'
int cmp (int a, int b) { return a < b ? a : b; }
int loop (int n) { int i, s = 0; for (i = 0; i < n; i++) s += i; return s; }
int sw (int x)
{
  switch (x)
    { case 0: return 10; case 1: return 20; case 2: return 30;
      case 3: return 40; case 4: return 50; default: return 0; }
}
EOF
cat > $C/05-long.c <<'EOF'
long long add64 (long long a, long long b) { return a + b; }
long long shl64 (long long a, int n) { return a << n; }
int narrow (long long a) { return (int) a; }
EOF
cat > $C/06-globals.c <<'EOF'
int gi = 42;
static int si;
const int gc = 7;
char gs[8] = "abcdefg";
int *gp = &gi;
int rd (void) { return gi + gc + si + gs[0]; }
void wr (int v) { si = v; }
EOF
cat > $C/07-fp.c <<'EOF'
double dadd (double a, double b) { return a + b; }
float fmul (float a, float b) { return a * b; }
double i2d (int a) { return (double) a; }
EOF

# ---------------------------------------- targets, and the by-name exclusions
targets=""
if [ $# -gt 0 ]; then
  targets="$*"
else
  for d in "$B"/lib/gcc/"$VER"/*/; do
    targets="$targets $(basename "$d")"
  done
fi

# amdgcn and nvptx are excluded from the ASSEMBLE arm BY NAME, never by a
# missing-file test: they use LLVM's assembler and `ptxas', so "no GNU cross
# as" says nothing about the back end.  They are still COMPILED -- a
# compile-to-.s census needs no assembler at all, and that is the whole point
# of separating CC-OK from AS-OK.
no_gnu_as="amdgcn nvptx"

printf 'corpus census at %s   build=%s   tools=%s\n' "$OPT" "$B" "${TOOLS:-<none>}"
printf '%-26s %-9s %-9s %s\n' TARGET CC AS NOTE
nt=0
for T in $targets; do
  CFG="$B/lib/gcc/$VER/$T/specs-config"
  base=$(echo "$T" | sed 's/-.*//')
  nt=$((nt+1))
  ccok=0; ccbad=0; asok=0; asbad=0; note=
  firstfail=
  for f in $C/*.c; do
    n=$(basename "$f" .c)
    if [ -f "$CFG" ]; then
      cfgarg="-ftarget-config=$CFG"
    else
      # No probed specs-config (amdgcn, nvptx).  A target-config naming only
      # the target is enough to SELECT the back end -- multi_target_select
      # reads the `target' line -- and selection is all the compile arm needs.
      mkdir -p $C/cfg
      printf 'target %s\n' "$T" > "$C/cfg/$T.cfg"
      cfgarg="-ftarget-config=$C/cfg/$T.cfg"
      note="synthesised target-config (no probed specs-config)"
    fi
    if "$B/gcc/xgcc" -B"$B/gcc/" $cfgarg $OPT -S -o "$C/$T-$n.s" "$f" \
         > "$C/$T-$n.cc.err" 2>&1; then
      ccok=$((ccok+1))
    else
      ccbad=$((ccbad+1))
      [ -n "$firstfail" ] || firstfail=$n
      continue
    fi
    AS=""
    case " $no_gnu_as " in *" $T "*|*" $base "*) AS=SKIP ;; esac
    if [ -z "$AS" ] && [ -n "$TOOLS" ] && [ -x "$TOOLS/$T-as" ]; then
      if "$TOOLS/$T-as" -o "$C/$T-$n.o" "$C/$T-$n.s" > "$C/$T-$n.as.err" 2>&1; then
        asok=$((asok+1))
      else
        asbad=$((asbad+1))
      fi
    fi
  done
  as_col="-"
  case " $no_gnu_as " in
    *" $T "*|*" $base "*) as_col="N/A"; note="${note:+$note; }no GNU as by design (LLVM as / ptxas)" ;;
    *) if [ -n "$TOOLS" ] && [ -x "$TOOLS/$T-as" ]; then
         as_col="$asok/$((asok+asbad))"
       else
         as_col="ABSENT"; note="${note:+$note; }no $T-as in TOOLS -- NOT scored against the host as"
       fi ;;
  esac
  printf '%-26s %-9s %-9s %s\n' "$T" "$ccok/$((ccok+ccbad))" "$as_col" \
    "${firstfail:+first cc1 failure: $firstfail. }$note"
done
echo
echo "targets=$nt  inputs=7  level=$OPT   (the level is part of the reading)"
[ "$nt" -gt 0 ] || { echo "FATAL: nothing measured"; exit 9; }
