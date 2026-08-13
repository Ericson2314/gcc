#!/bin/sh
# #119 -- evidence for the libgcc.a bar and for the both-sided config content.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b119}
T1=aarch64-unknown-linux-gnu
T2=x86_64-pc-linux-gnu
A=$B/$T2/libgcc/libgcc.a

sh "$S/eb-shell.sh" "
  set -e
  echo '=== libgcc.a'
  ls -l $A
  echo \"members: \$(ar t $A | wc -l)\"
  echo \"i386-only member present (evidence it is x86_64 code, not an empty archive):\"
  ar t $A | grep -c -x -e 'cpuinfo.o' -e 'sse.o' -e 'avx_savms64_s.o' || true
  ar t $A | head -5
  echo '--- an object out of it must be x86-64 ELF'
  cd \$(mktemp -d) && ar x $A _muldi3.o && readelf -h _muldi3.o | grep -E 'Machine|Class'
"
