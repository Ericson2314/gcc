#!/bin/sh
# #139 -- build the THROUGHPUT corpus.
#
# `scratchpad/big.c' is 150 lines.  It is the right input for the byte-identity
# bars and the wrong input for a timing question: a run of it is dominated by
# cc1 start-up (option processing, the target-config read, the mode tables),
# which is paid once per process and is exactly the part a per-site call cost
# does NOT scale with.  A "+3%" measured on big.c is therefore mostly a
# measurement of start-up, in the direction that HIDES a per-site cost.
#
# So: real C source, preprocessed ONCE with the host compiler into `.i', so
# both cc1s under test consume byte-identical input and neither is charged for
# header I/O.  Everything here is real code that ships in this tree.
#
# Non-vacuity, all fatal:
#   * at least 8 TUs
#   * at least 40000 total lines
#   * every .i non-empty
set -u
SRC=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:?outdir}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
rm -rf "$OUT"; mkdir -p "$OUT" || exit 9

# Real C TUs from this tree: compression, backtrace/DWARF parsing, and the
# support library.  Chosen for size and for being ordinary integer/pointer
# code -- the kind where UNITS_PER_WORD and Pmode are actually consulted.
set -- \
  "zlib/deflate.c            -I$SRC/zlib" \
  "zlib/inflate.c            -I$SRC/zlib" \
  "zlib/trees.c              -I$SRC/zlib" \
  "zlib/infback.c            -I$SRC/zlib" \
  "libbacktrace/dwarf.c      -I$SRC/libbacktrace -I$OUT/bt -I$SRC/include" \
  "libbacktrace/elf.c        -I$SRC/libbacktrace -I$OUT/bt" \
  "libdecnumber/decNumber.c  -I$SRC/libdecnumber -I$OUT/bt" \
  "libdecnumber/decBasic.c   -I$SRC/libdecnumber -I$OUT/bt" \
  "libdecnumber/decContext.c -I$SRC/libdecnumber -I$OUT/bt" \
  "libiberty/cp-demangle.c   -I$SRC/include -I$OUT/bt" \
  "libiberty/simple-object-elf.c -I$SRC/include -I$OUT/bt" \
  "libiberty/dyn-string.c    -I$SRC/include -I$OUT/bt" \
  "libiberty/fibheap.c       -I$SRC/include -I$OUT/bt" \
  "libiberty/splay-tree.c    -I$SRC/include -I$OUT/bt" \
  "libiberty/regex.c         -I$SRC/include -I$OUT/bt" \
  "libiberty/cplus-dem.c     -I$SRC/include -I$OUT/bt" \
  "libiberty/hashtab.c       -I$SRC/include -I$OUT/bt" \
  "libiberty/md5.c           -I$SRC/include -I$OUT/bt" \
  "libiberty/sha1.c          -I$SRC/include -I$OUT/bt" \
  "libiberty/dwarfnames.c    -I$SRC/include -I$OUT/bt" \
  "libgcc/config/libbid/bid128_fma.c     -I$SRC/libgcc/config/libbid -I$SRC/libgcc -I$SRC/include" \
  "libgcc/config/libbid/bid128.c         -I$SRC/libgcc/config/libbid -I$SRC/libgcc -I$SRC/include" \
  "libgcc/config/libbid/bid128_add.c     -I$SRC/libgcc/config/libbid -I$SRC/libgcc -I$SRC/include" \
  "libgcc/config/libbid/bid128_compare.c -I$SRC/libgcc/config/libbid -I$SRC/libgcc -I$SRC/include" \
  "libgcc/config/libbid/bid64_compare.c  -I$SRC/libgcc/config/libbid -I$SRC/libgcc -I$SRC/include" \
  "libgcc/config/libbid/bid128_to_int64.c -I$SRC/libgcc/config/libbid -I$SRC/libgcc -I$SRC/include" \
  "libffi/src/dlmalloc.c                 -I$SRC/libffi/include -I$SRC/libffi" \
  "libdecnumber/bid/bid2dpd_dpd2bid.c    -I$SRC/libdecnumber -I$SRC/libdecnumber/bid -I$OUT/bt" \
  "libdecnumber/bid/host-ieee128.c       -I$SRC/libdecnumber -I$SRC/libdecnumber/bid -I$OUT/bt"

mkdir -p "$OUT/bt"
# libbacktrace needs a generated config header; a minimal one is enough to
# preprocess, and it is written here rather than taken from a build dir so the
# corpus does not depend on anyone's build.
cat > "$OUT/bt/config.h" <<'EOF'
#define HAVE_DECL_STRNLEN 1
#define HAVE_DL_ITERATE_PHDR 1
#define BACKTRACE_ELF_SIZE 64
#define HAVE_FCNTL 1
#define HAVE_STDINT_H 1
#define HAVE_UNISTD_H 1
#define HAVE_LINK_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_LIMITS_H 1
#define HAVE_ALLOCA_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_MMAN_H 1
#define HAVE_ERRNO_H 1
#define HAVE_MEMCPY 1
#define HAVE_MEMSET 1
#define HAVE_STRCHR 1
#define HAVE_MALLOC 1
#define HAVE_REALLOC 1
#define HAVE_FREE 1
EOF
# libdecnumber's decContext.h includes "gstdint.h", a configure-generated
# shim for <stdint.h>.  Supplying it here keeps the corpus independent of any
# build dir, per the same rule as config.h above.
echo '#include <stdint.h>' > "$OUT/bt/gstdint.h"

n=0
for spec in "$@"; do
  f=$(echo "$spec" | awk '{print $1}')
  inc=$(echo "$spec" | cut -d' ' -f2-)
  [ -f "$SRC/$f" ] || { echo "skip (absent): $f"; continue; }
  b=$(echo "$f" | tr '/' '_' | sed 's/\.c$//')
  nix-shell -I "nixpkgs=$NP" -p gcc --run \
    "gcc -E -P -std=gnu17 $inc '$SRC/$f' -o '$OUT/$b.i'" \
    > "$OUT/$b.pp.log" 2> "$OUT/$b.pp.err"
  if [ -s "$OUT/$b.i" ]; then
    # A .i that PREPROCESSES but does not COMPILE is worse than no TU at all:
    # cc1 spends its time in the diagnostic path, the timing arm still reports
    # seconds, and the equal-work check silently has nothing to compare.  The
    # first run of this corpus had 10 of 19 TUs in exactly that state and the
    # only thing that noticed was the output comparison.  So each TU must
    # compile with the HOST compiler, at the same -std the timing arm uses,
    # before it is admitted.
    if nix-shell -I "nixpkgs=$NP" -p gcc --run \
         "gcc -S -std=gnu17 -O2 -o /dev/null '$OUT/$b.i'" \
         > "$OUT/$b.cc.log" 2> "$OUT/$b.cc.err"; then
      n=$((n+1))
      echo "ok   $b  $(wc -l < "$OUT/$b.i") lines"
    else
      echo "DROP $b -- preprocesses but does not compile; see $OUT/$b.cc.err"
      rm -f "$OUT/$b.i"
    fi
  else
    echo "FAIL $b -- preprocessing produced nothing; see $OUT/$b.pp.err"
    rm -f "$OUT/$b.i"
  fi
done

tot=$(cat "$OUT"/*.i | wc -l)
echo "corpus: $n TUs, $tot lines"
[ "$n" -ge 8 ]      || { echo "FATAL: only $n TUs, refusing to time on a thin corpus"; exit 9; }
[ "$tot" -ge 40000 ] || { echo "FATAL: only $tot lines, refusing"; exit 9; }
