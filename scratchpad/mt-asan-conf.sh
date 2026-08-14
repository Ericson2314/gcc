#!/bin/sh
# mt-asan-conf.sh -- configure a build dir whose `cc1' is built with
# AddressSanitizer + UBSan.
#
# TWO LOAD-BEARING OPTIONS, BOTH FOUND THE HARD WAY AND NEITHER OPTIONAL:
#
#   ASAN_OPTIONS=detect_leaks=0   is needed to BUILD AT ALL.  GCC's generators
#     (genhooks, genmodes, gengtype) leak by design -- they allocate and exit --
#     so LSan reports at exit and they terminate with status 23, which make
#     reads as a failed generator.  It is exported here rather than left to the
#     caller because a build that dies in `genmodes' reads as a broken tree.
#
#   handle_segv=2:allow_user_segv_handler=0   is needed to RUN.  `toplev.cc:329'
#     installs GCC's own SIGSEGV handler, which wins over ASAN's unless ASAN is
#     told to keep control.  Without it a heap-buffer-overflow that faults
#     produces an EMPTY ASAN log beside a crashing cc1 -- indistinguishable
#     from a clean run.  A clean-looking log without this option is a NULL
#     RESULT, not a pass.  It belongs on the RUN, not here; see mt-asan-run.sh.
#
# Everything else is mt-conf.sh, whose guards this reuses by delegation rather
# than by copying (INSTRUMENTS.md: extend, do not fork).
#
# usage: SRC=<srcdir> WANT_ANCHOR=<n> mt-asan-conf.sh <builddir> <triples>
set -eu
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)

SAN='-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=undefined'
export ASAN_OPTIONS=detect_leaks=0
MT_CONFIGURE_FLAGS="${MT_CONFIGURE_FLAGS:-} CFLAGS='$SAN' CXXFLAGS='$SAN'" \
  exec sh "$MT_LIB_DIR/mt-conf.sh" "$@"
