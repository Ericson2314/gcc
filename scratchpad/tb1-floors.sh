#!/bin/sh
# #163 -- rewrite the seven DEAD `#ifndef HAVE_AS_TLS / #define HAVE_AS_TLS 0'
# floors into the GENERATOR-ONLY form the branch already uses for the rs6000
# assembler capabilities (config/rs6000/rs6000.h, `#if defined (GENERATOR_FILE)
# || defined (USED_FOR_TARGET)').
#
# WHY THE VALUE FLIPS FROM 0 TO 1, WHICH LOOKS LIKE MOVING A NUMBER TO MAKE
# SOMETHING PASS AND IS THE OPPOSITE.  The floors never fired: auto-host.h's
# unconditional `#define HAVE_AS_TLS 1' was read first, so what gencondmd and
# every other generator have ALWAYS seen is 1.  Writing 0 into the new block
# would be a silent change of value -- it would fold every TLS insn condition
# in alpha.md, frv.md, loongarch.md, mips.md, rs6000.md, sparc.md and
# xtensa.md to false at BUILD time, deleting the patterns from the compiler
# where today they are kept and decided at run time.  1 restates what was
# already true.
#
# APPLIED BY SCRIPT rather than by hand because it is the same edit seven
# times and a missed one is silent in exactly that direction.  Idempotent, and
# it REFUSES if it does not find all seven.
set -e
cd "$(dirname "$0")/../gcc"

FILES="config/alpha/alpha.h config/frv/frv.h config/mips/mips.h \
config/rs6000/rs6000.h config/sparc/sparc.h config/xtensa/xtensa.h \
config/loongarch/loongarch-opts.h"

n=0
for f in $FILES; do
  [ -f "$f" ] || { echo "FATAL: $f absent"; exit 9; }
  grep -q '^#ifndef HAVE_AS_TLS$' "$f" || { echo "SKIP (already converted?) $f"; continue; }
  awk '
    /^#ifndef HAVE_AS_TLS$/ && !done {
      print "/* GENERATORS ONLY -- the generated tm.h includes defaults.h only under"
      print "   `!GENERATOR_FILE'"'"', so build/gencondmd*.o never sees the targ_caps"
      print "   redirect and this back end'"'"'s .md conditions would not compile without"
      print "   something here.  For the compiler proper defaults.h #undef'"'"'s this and"
      print "   redefines it as `targ_caps.as_tls'"'"'."
      print ""
      print "   THE VALUE IS 1, AND THE `#ifndef ... 0'"'"' FLOOR THAT USED TO BE HERE WAS"
      print "   DEAD.  auto-host.h carried an unconditional `#define HAVE_AS_TLS 1'"'"' and"
      print "   was read first, so the floor never fired and 1 is what every generator"
      print "   has always seen.  Writing 0 here would delete this back end'"'"'s TLS insn"
      print "   patterns at build time -- see the note beside the same name in"
      print "   defaults.h.  */"
      print "#if defined (GENERATOR_FILE) || defined (USED_FOR_TARGET)"
      print "#define HAVE_AS_TLS 1"
      print "#endif"
      done = 1
      skip = 3      # the old #ifndef / #define / #endif
    }
    skip > 0 { skip--; next }
    { print }
  ' "$f" > "$f.tb1" && mv "$f.tb1" "$f"
  # The old block was exactly three lines; assert we consumed the right ones.
  grep -q '^#ifndef HAVE_AS_TLS$' "$f" && { echo "FATAL: $f still has a floor"; exit 9; }
  grep -q '^#define HAVE_AS_TLS 1$' "$f" || { echo "FATAL: $f has no generator define"; exit 9; }
  n=$((n+1))
  echo "converted $f"
done
[ "$n" = 7 ] || { echo "FATAL: converted $n of 7"; exit 9; }
