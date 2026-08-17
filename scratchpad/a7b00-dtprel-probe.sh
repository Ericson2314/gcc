#!/bin/sh
# Does aarch64 gas accept `%dtprel(sym)' in a .xword -- the exact text
# aarch64_output_dwarf_dtprel emits (gcc/config/aarch64/aarch64.cc:1600)?
#
# This is upstream's HAVE_AS_DTPREL_RELOC probe, which target-specs/configure.ac
# does NOT run: it hardcodes `ts_as_dtprel_reloc=yes' with a comment saying a
# real probe is still owed.
set -u
AS=${1:?assembler}
d=$(mktemp -d)
cat > "$d/t.s" <<'EOF'
	.section	.tdata,"awT",%progbits
x:	.word	1
	.section	.debug_info,"",%progbits
	.xword	%dtprel(x)
EOF
echo "--- %dtprel(x):"
"$AS" -o "$d/t.o" "$d/t.s" && echo "  ACCEPTED" || echo "  REJECTED"
cat > "$d/u.s" <<'EOF'
	.section	.tdata,"awT",%progbits
x:	.word	1
	.section	.debug_info,"",%progbits
	.xword	x+0
EOF
echo "--- control (plain symbol, proves the rest of the file is legal):"
"$AS" -o "$d/u.o" "$d/u.s" && echo "  ACCEPTED" || echo "  REJECTED"
rm -rf "$d"
