#!/bin/sh
# TASK #111, ARM D v2 -- the existence-predicate arm, with the two corrections
# v1 needed.  See t111-armD.sh for the rationale and the blind-spot list; this
# script supersedes it and both are kept so the corrections are auditable.
#
# CORRECTION 1 -- v1's "shared" set was WRONG BY SEVEN FILES.
#   target-{addr,asm-ops,cdata,c-ops,cumargs,regs}.cc and
#   multi-target-reg-probe.cc are compiled ONCE PER BASE (gen-multi-target-md.awk
#   emits `target-<x>-<cpu>.o ... -I<cpu>-inc'), so an `#ifdef' in them sees that
#   base's own headers and is CORRECT BY CONSTRUCTION.  v1 scored their guards as
#   leaks.  Likewise target-def.h and target-asm-ops.h are included by
#   config/*/*.cc, i.e. compiled per back end.  And gcc/common/config/ is
#   back-end code that v1's `not config/' filter let straight through.
#   This is PRINCIPLES 4 rule 5: v1's blind spot was that it had no notion of
#   which TUs are already per-base, which is exactly the mechanism under test.
#
# CORRECTION 2 -- the count is not the finding; the SHAPE is.
#   An `#ifdef X' with an `#else' degrades to a WRONG ANSWER when X is absent:
#   some code still runs, and it tends to fail loudly and near the cause.
#   An `#ifdef X' with NO `#else' degrades to NO CODE AT ALL: nothing is
#   mis-set, and the failure surfaces arbitrarily far away.  INIT_EXPANDERS is
#   the second kind and that is why it presents as a null dereference inside
#   aarch64_set_current_function rather than as a bad value.
#   So every row is classified SILENT (no #else) or WRONG (has #else).
#   SILENT is the actionable subset.
set -u
G=${G:-/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa0b6da0fbac13315/gcc}
O=${O:-/tmp/t112-armD2}
PRIMARY=${PRIMARY:-i386}
rm -rf "$O"; mkdir -p "$O"
[ -d "$G/config" ] || { echo "FATAL: no $G/config"; exit 9; }

# ---- 1. per-base / back-end-side sources, EXCLUDED from "shared" ------------
cat > "$O/perbase.txt" <<'EOF'
target-addr.cc
target-asm-ops.cc
target-cdata.cc
target-c-ops.cc
target-cumargs.cc
target-regs.cc
multi-target-reg-probe.cc
gen-target-specs.cc
target-def.h
target-asm-ops.h
target-frame.h
EOF
# Assert the exclusion list is not stale: every name must still exist, and the
# .cc ones must still be named by the per-base rule generator.  A silently
# stale exclusion list would hide rows, in the direction that flatters us.
while read -r f; do
  [ -e "$G/$f" ] || { echo "FATAL: exclusion list names missing file $f"; exit 9; }
done < "$O/perbase.txt"
for f in target-addr target-asm-ops target-cdata target-c-ops target-cumargs target-regs; do
  grep -q "srcdir)/$f.cc" "$G/gen-multi-target-md.awk" \
    || { echo "FATAL: $f.cc no longer has a per-base rule -- exclusion list stale"; exit 9; }
done

# ---- 2. D: macro -> back ends defining it -----------------------------------
find "$G/config" -name '*.h' -print \
| while read -r f; do
    rel=${f#"$G/config/"}
    case $rel in */*) be=${rel%%/*} ;; *) be=_common ;; esac
    sed -n 's/^[ \t]*#[ \t]*define[ \t][ \t]*\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' "$f" \
    | while read -r m; do echo "$m $be"; done
  done | sort -u > "$O/defines.txt"
[ -s "$O/defines.txt" ] || { echo "FATAL: defines.txt empty"; exit 9; }

# ---- 3. C: existence tests in genuinely shared TUs --------------------------
find "$G" -name '*.cc' -o -name '*.h' -o -name '*.c' \
| grep -v "^$G/config/" \
| grep -v "^$G/common/config/" \
| grep -v "^$G/testsuite/" \
| grep -v "^$G/ada/gcc-interface/" \
| while read -r f; do
    b=${f#"$G/"}
    grep -qx "$b" "$O/perbase.txt" || echo "$f"
  done > "$O/shared-files.txt"
n=$(wc -l < "$O/shared-files.txt"); [ "$n" -gt 500 ] || { echo "FATAL: only $n shared files"; exit 9; }

# Per-file preprocessor walk: emit  macro <TAB> file:line <TAB> SILENT|WRONG
# for every #ifdef/#if defined guard, by tracking the conditional nesting and
# noting whether the block that guard opened ever sees an #else/#elif.
: > "$O/guards.txt"
while read -r f; do
  awk -v F="$f" '
    function flush(i,  s) {
      if (name[i] != "") {
        s = haselse[i] ? "WRONG" : "SILENT";
        print name[i] "\t" F ":" ln[i] "\t" s;
      }
    }
    /^[ \t]*#[ \t]*(if|ifdef|ifndef)/ {
      d++; name[d]=""; haselse[d]=0; ln[d]=NR;
      t=$0;
      if (match(t, /^[ \t]*#[ \t]*ifdef[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
        s=substr(t,RSTART,RLENGTH); sub(/.*[ \t]/,"",s); name[d]=s;
      } else if (match(t, /^[ \t]*#[ \t]*if[ \t].*defined/)) {
        # a bare "#if defined (X)" is a clean existence predicate; a compound
        # one is recorded too but is a weaker claim.  (No apostrophes here:
        # one inside this single-quoted awk body ended the shell quote and
        # produced a syntax error 40 lines further down.)
        if (match(t, /defined[ \t]*\(?[ \t]*[A-Za-z_][A-Za-z0-9_]*/)) {
          s=substr(t,RSTART,RLENGTH); sub(/^defined[ \t]*\(?[ \t]*/,"",s); name[d]=s;
        }
      }
      next;
    }
    /^[ \t]*#[ \t]*(else|elif)/ { if (d>0) haselse[d]=1; next }
    /^[ \t]*#[ \t]*endif/ { if (d>0) { flush(d); d--; } next }
    END { while (d>0) { flush(d); d--; } }
  ' "$f" >> "$O/guards.txt"
done < "$O/shared-files.txt"
[ -s "$O/guards.txt" ] || { echo "FATAL: no guards"; exit 9; }

# ---- 4. shared-header floors ------------------------------------------------
find "$G" -maxdepth 1 -name '*.h' > "$O/sharedh.txt"
xargs -a "$O/sharedh.txt" sed -n 's/^[ \t]*#[ \t]*define[ \t][ \t]*\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' \
  | sort -u > "$O/floored.txt"

# ---- 5. classify ------------------------------------------------------------
cut -f1 "$O/guards.txt" | grep -v '^$' | sort -u > "$O/guarded-names.txt"
awk '{print $1}' "$O/defines.txt" | sort -u > "$O/defined-names.txt"
comm -12 "$O/guarded-names.txt" "$O/defined-names.txt" > "$O/population.txt"

: > "$O/report.txt"
while read -r m; do
  bes=$(awk -v m="$m" '$1==m && $2!="_common" {print $2}' "$O/defines.txt" | sort -u | grep -c .)
  prim=NO; awk -v m="$m" '$1==m && $2=="i386"' "$O/defines.txt" | grep -q . && prim=YES
  fl=NO;   grep -qx "$m" "$O/floored.txt" && fl=YES
  # a macro is SILENT if ANY of its shared guards has no #else
  sh=WRONG; awk -F'\t' -v m="$m" '$1==m && $3=="SILENT"' "$O/guards.txt" | grep -q . && sh=SILENT
  sites=$(awk -F'\t' -v m="$m" '$1==m {sub(/.*\/gcc\//,"",$2); printf "%s ", $2}' "$O/guards.txt")
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$m" "$bes" "$prim" "$fl" "$sh" "$sites" >> "$O/report.txt"
done < "$O/population.txt"

awk -F'\t' '$2>0 && $3=="NO" && $4=="NO"' "$O/report.txt" | sort -t"$(printf '\t')" -k2 -rn > "$O/actionable.txt"
awk -F'\t' '$5=="SILENT"' "$O/actionable.txt" > "$O/silent.txt"
awk -F'\t' '$5=="WRONG"'  "$O/actionable.txt" > "$O/wrong.txt"

echo "shared TUs scanned:                                        $(wc -l < "$O/shared-files.txt")"
echo "population (config macro, existence-tested in a shared TU): $(wc -l < "$O/population.txt")"
echo "  i386 (the base shared code compiles against) defines it:  $(grep -c '	YES	' "$O/report.txt")"
echo "ACTIONABLE (>=1 back end has it, i386 does NOT, no floor):   $(wc -l < "$O/actionable.txt")"
echo "  of which SILENT (no #else -- absence produces NO code):    $(wc -l < "$O/silent.txt")"
echo "  of which WRONG  (#else -- absence produces a wrong answer):$(wc -l < "$O/wrong.txt")"
echo
echo "=== SILENT, the actionable subset, by back ends defining ==="
printf '%-32s %3s  %s\n' MACRO nbe SITES
awk -F'\t' '{printf "%-32s %3s  %s\n", $1, $2, $6}' "$O/silent.txt"
