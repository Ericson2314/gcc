#!/bin/sh
# OPTION VARIABLES WHOSE NAME IS ALSO A TYPE NAME IN ANOTHER BACK END.
#
# opth-gen emits, for every option variable, an object-like macro
#     #define <name> global_options.x_<name>
# and the union header carries every back end's.  If ANOTHER back end uses the
# same identifier as an `enum' TYPE, the macro expands inside that type's own
# declaration:
#
#     bpf.opt:99    Target ... Var(asm_dialect) Enum(bpf_asm_dialect)
#     i386.opt:117  enum asm_dialect x_ix86_asm_dialect
#
#   -> #define asm_dialect global_options.x_asm_dialect
#      enum global_options.x_asm_dialect x_ix86_asm_dialect;
#      error: expected unqualified-id before "." token
#
# A variable in one back end and a type in another. Neither is wrong; they are
# only wrong TOGETHER, which is why no single-target build can see it and why
# it appears in every back end at once -- the header is shared.
#
# usage: mtN-varvstype.sh <gcc-srcdir>
set -e
S=${1:-$(cd "$(dirname "$0")/../gcc" && pwd)}
[ -d "$S/config" ] || { echo "FATAL: $S/config is not a directory"; exit 9; }

tmp=${TMPDIR:-/tmp}/mtN-varvstype.$$
trap 'rm -f "$tmp".*' 0

# Every option variable name, with the back end that declares it.
for f in "$S"/config/*/*.opt; do
  [ -f "$f" ] || continue
  cpu=$(basename "$(dirname "$f")")
  sed -n 's/.*[^_a-zA-Z0-9]Var(\([a-zA-Z_][a-zA-Z_0-9]*\)).*/\1/p' "$f" \
    | sort -u | sed "s|^|$cpu |"
done > "$tmp".vars

# Every enum TYPE name defined under config/, with its back end.
grep -rhn "" /dev/null > /dev/null 2>&1 || true
for f in "$S"/config/*/*.h "$S"/config/*/*.opt; do
  [ -f "$f" ] || continue
  cpu=$(basename "$(dirname "$f")")
  sed -n 's/^[ \t]*enum[ \t]\{1,\}\([a-zA-Z_][a-zA-Z_0-9]*\)[ \t]*{.*/\1/p;s/^[ \t]*enum[ \t]\{1,\}\([a-zA-Z_][a-zA-Z_0-9]*\)[ \t]*$/\1/p' "$f" \
    | sort -u | sed "s|^|$cpu |"
done > "$tmp".types

[ -s "$tmp".vars ]  || { echo "FATAL: no option variables read"; exit 9; }
[ -s "$tmp".types ] || { echo "FATAL: no enum types read"; exit 9; }

echo "=== identifier is an option Var() in one back end and an enum TYPE in another"
n=0
while read -r vcpu v; do
  owners=$(awk -v n="$v" '$2 == n {print $1}' "$tmp".types | sort -u | grep -v "^$vcpu\$" | tr '\n' ' ')
  if [ -n "$owners" ]; then
    printf 'Var(%s) in %-10s  enum %s in: %s\n' "$v" "$vcpu" "$v" "$owners"
    n=$((n + 1))
  fi
done < "$tmp".vars
echo
printf 'option variables read: %s   enum types read: %s   collisions: %s\n' \
  "$(wc -l < "$tmp".vars)" "$(wc -l < "$tmp".types)" "$n"
