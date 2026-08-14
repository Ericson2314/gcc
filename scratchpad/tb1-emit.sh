#!/bin/sh
# Per-target: does the compiler EMIT, does the target's REAL cross assembler
# accept it, and is the result the right ELF machine AND the right word size.
#
# The last arm is not decoration: PRINCIPLES records riscv64 passing
# "assembles, right ELF machine" while emitting 32-bit code (`sw' for a long,
# no `sd' anywhere).  An assembler validates syntax for a machine, not that the
# compiler meant that machine.  So the word-size arm reads the emitted asm for
# a 64-bit store on a `long', which is what that defect got wrong.
set -u
B=${B:?build dir}; TOOLS=${TOOLS:?tools dir}
VER=17.0.0
W=$B/emit; rm -rf "$W"; mkdir -p "$W"
cat > "$W/t.c" <<'EOF'
long mt_shift (long a, int b) { return (a << b) + (a >> 7); }
EOF
for T in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  C="$B/lib/gcc/$VER/$T/specs-config"
  printf '%-28s ' "$T"
  if ! "$B/gcc/cc1" -quiet -nostdinc -O2 -ftarget-config="$C" "$W/t.c" \
        -o "$W/$T.s" > "$W/$T.out" 2> "$W/$T.err"; then
    echo "EMIT: FAIL -- $(head -1 "$W/$T.err")"
    continue
  fi
  printf 'EMIT ok (%s bytes)  ' "$(wc -c < "$W/$T.s")"
  AS="$TOOLS/bin/$T-as"; RE="$TOOLS/bin/$T-readelf"
  [ -x "$AS" ] || AS=$(command -v as)
  [ -x "$RE" ] || RE=$(command -v readelf)
  if "$AS" -o "$W/$T.o" "$W/$T.s" > "$W/$T.as.out" 2> "$W/$T.as.err"; then
    m=$("$RE" -h "$W/$T.o" | sed -n 's/^ *Machine: *//p')
    cl=$("$RE" -h "$W/$T.o" | sed -n 's/^ *Class: *//p')
    printf 'AS ok  %s / %s' "$cl" "$m"
  else
    printf 'AS FAIL: %s' "$(sed -n '2p' "$W/$T.as.err")"
  fi
  echo
  # the semantic arm: a 64-bit `long' shift must not be done in 32-bit
  # instructions.  Printed for every target so the reader can compare.
  printf '%30s word-size witness: %s\n' '' \
    "$(grep -oE '\b(sd|ld|sw|lw|str|ldr|stg|lg|st|l)\b' "$W/$T.s" | sort -u | tr '\n' ' ')"
done
