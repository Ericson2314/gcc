#!/bin/sh
# #176 -- the two reproducers for the two named aarch64 ICE causes, run on
# BOTH configured targets.
#
# WHY THE x86_64 ARM IS NOT DECORATION.  Both fixes replace a value that WAS
# i386's with a per-base call.  If the call were wired to the wrong table, or
# if the thunk read the wrong headers, x86_64 would change too -- and it is
# the target whose bars this branch trusts.  So each case is compiled for both
# targets and the x86_64 output is diffed against a control taken from a
# compiler built before the change.
#
# WHY NOT A SYMBOL CHECK.  `nm' cannot answer this: `ix86_regmode_natural_size'
# and `aarch64_regmode_natural_size' are BOTH linked into cc1 either way, and
# so is `mt_regmode_natural_size'.  Every arrangement links.  The discriminator
# is what the compiler DOES -- an ICE or an object -- and, for casesi, WHICH
# RTL the jump table is (`ADDR_DIFF_VEC' vs `ADDR_VEC'), which is read out of
# the RTL dump rather than guessed from the assembly.  The assembly is blind
# here for the usual reason: `.word' is `.word' on both targets.
set -u
B=${B:?set B to the build dir}
W=${W:?set W to a writable scratch dir}
X=$B/gcc/xgcc
A64=$B/lib/gcc/17.0.0/aarch64-unknown-linux-gnu/specs-config
X86=$B/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config

[ -x "$X" ] || { echo "FATAL: no $X"; exit 9; }
for f in "$A64" "$X86"; do
  [ -f "$f" ] || { echo "FATAL: no $f -- run t176-specs.sh first"; exit 9; }
done
mkdir -p "$W"

cat > "$W/sve.c" <<'EOF'
typedef long v2di __attribute__((vector_size (16)));
v2di foo (v2di a, v2di b) { return a * b; }
EOF

awk 'BEGIN {
  print "extern void g (int);";
  print "void f (int x) {";
  print "  switch (x) {";
  for (i = 0; i < 24; i++)
    printf "    case %d: g (%d); g (%d); break;\n", i, i * 3, i * 7;
  print "  }";
  print "}";
}' > "$W/casesi.c"

run () {			# run <tag> <specs> <src> <flags...>
  tag=$1; cfg=$2; src=$3; shift 3
  "$X" -B"$B/gcc/" -ftarget-config="$cfg" "$src" "$@" -S -o "$W/$tag.s" \
    > "$W/$tag.out" 2> "$W/$tag.err"
  rc=$?
  ice=$(grep -c 'internal compiler error' "$W/$tag.err" || true)
  printf '%-22s rc=%s  ICE=%s  %s\n' "$tag" "$rc" "$ice" \
    "$(test -f "$W/$tag.s" && md5sum < "$W/$tag.s" | cut -c1-12 || echo NO-OUTPUT)"
}

echo "== REGMODE_NATURAL_SIZE  (gen_lowpart_general, rtlhooks.cc:57)"
run sve-aarch64 "$A64" "$W/sve.c" -O -march=armv8.2-a+sve
run sve-x86_64  "$X86" "$W/sve.c" -O

echo
echo "== CASE_VECTOR_PC_RELATIVE  (aarch64_output_casesi)"
run casesi-aarch64 "$A64" "$W/casesi.c" -O1
run casesi-x86_64  "$X86" "$W/casesi.c" -O1

echo
echo "== the discriminator: which jump-table RTL each target built"
# -da leaves the .final dump beside the OUTPUT file, so run from $W.
for t in aarch64 x86_64; do
  case $t in aarch64) c=$A64; o="-O1";; *) c=$X86; o="-O1";; esac
  ( cd "$W" && rm -f casesi-$t.c.*.final \
      && "$X" -B"$B/gcc/" -ftarget-config="$c" casesi.c $o -S \
	   -o casesi-dump-$t.s -fdump-rtl-final=casesi-$t.final \
	   > /dev/null 2>&1 )
  d=$W/casesi-$t.final
  if [ -f "$d" ]; then
    printf '%-10s ADDR_DIFF_VEC=%s  ADDR_VEC=%s\n' "$t" \
      "$(grep -c '(addr_diff_vec' "$d" || true)" \
      "$(grep -c '(addr_vec' "$d" || true)"	# `(' matters: `addr_vec' is a
						# SUBSTRING of `addr_diff_vec'
						# and an unanchored grep scores
						# the fixed case as broken.
  else
    printf '%-10s NO DUMP -- the compile did not reach final\n' "$t"
  fi
done
