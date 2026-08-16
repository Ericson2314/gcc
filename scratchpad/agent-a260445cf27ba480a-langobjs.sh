#!/bin/sh
# agent-a260445cf27ba480a -- the SIBLING per-language object lists, both shapes.
#
# `MT_CXX_OBJS_<base>' was empty for 32 of 48 back ends (491713a900a) because
# an assignment sat inside a loop that most bases never entered.  This branch's
# rule is that one instance of a shape is never one instance, so this script
# asks the two questions the C and C++ lists were caught by, of EVERY
# per-language list `config.gcc' sets:
#
#   SHAPE A -- is the list carried per back end at all, or does it reach the
#              build through the ONE legacy ${target} pass?  (`d_target_objs',
#              `fortran_target_objs', `rust_target_objs', `jit_target_objs'
#              have no manifest record, so gen-multi-target-md.awk cannot see
#              them and gcc/Makefile.in gets @<lang>_target_objs@ = the
#              PRIMARY's list alone.)
#
#   SHAPE B -- FIRST-RECORD-WINS.  These variables are set by TRIPLE, not by
#              back end, so two triples of one cpu_type can disagree; anything
#              read from only the first record for a cpu_type then depends on
#              command-line order.  This is what #191 fixed for `c_target_objs'
#              and what `accumulate_c_target_objs' exists for.
#
# It sources config.gcc once per triple exactly as gen-target-manifest.sh does,
# over EVERY triple in contrib/config-list.mk -- not the 47 configured ones,
# because with one triple per back end shape B is invisible by construction.
#
# NON-VACUITY: refuses to score unless it read a plausible number of records
# AND saw at least one non-empty value for c_target_objs, which is the control
# -- an all-empty read looks exactly like "no back end sets any of these".
set -eu
S=${1:?srcdir}
OUT=${2:?outfile}
S=$(cd "$S" && pwd)
: > "$OUT"

TRIPLES=$(awk '/^LIST = /{f=1} f{print} f&&!/\\$/{exit}' "$S/contrib/config-list.mk" \
	  | sed 's/^LIST = //; s/\\$//' | tr ' \t' '\n\n' | grep -e '[a-z0-9]-' | sort -u)
n_in=$(printf '%s\n' "$TRIPLES" | grep -c .)
[ "$n_in" -ge 100 ] || { echo "REFUSE: only $n_in triples read from config-list.mk" >&2; exit 9; }

for t in $TRIPLES; do
  (
    # `set +u' IS LOAD-BEARING: config.gcc reads dozens of unset `with_*'
    # variables, so under `set -u' every subshell dies before assigning
    # anything and the census reads ZERO records -- which looks exactly like
    # "no back end sets any of these", the null-result-as-a-pass shape.  The
    # refusal below is what turned that into a stop rather than a finding.
    set +eu
    cd "$S/gcc"
    srcdir=.
    target=$(../config.sub "${t%%OPT*}" 2>/dev/null) || exit 0
    [ -n "$target" ] || exit 0
    tm_defines= cpu_type= target_cpu_default=
    tm_file= tm_p_file= tmake_file=
    extra_objs= extra_options= extra_headers= c_target_objs=
    cxx_target_objs= d_target_objs= fortran_target_objs= rust_target_objs=
    jit_target_objs=
    extra_gcc_objs= extra_parts= extra_modes=
    out_file= md_file= target_gtfiles=
    common_out_file= target_has_targetm_common= dwarf2=
    TM_MULTILIB_CONFIG=
    . ./config.gcc > /dev/null 2>&1 || exit 0
    [ -n "$cpu_type" ] || exit 0
    sq() { echo "$*" | tr -s ' ' | sed 's/^ //;s/ $//'; }
    echo "$cpu_type|$target|c=$(sq $c_target_objs)|cxx=$(sq $cxx_target_objs)|d=$(sq $d_target_objs)|f=$(sq $fortran_target_objs)|rust=$(sq $rust_target_objs)|jit=$(sq $jit_target_objs)|extra_objs=$(sq $extra_objs)|tm_defines=$(sq $tm_defines)|extra_options=$(sq $extra_options)|common_out_file=$(sq $common_out_file)|extra_modes=$(sq $extra_modes)|tm_p_file=$(sq $tm_p_file)"
  ) >> "$OUT" || true
done

n=$(grep -c . "$OUT" || true)
[ "$n" -ge 100 ] || { echo "REFUSE: only $n records sourced" >&2; exit 9; }
grep -q 'c=[a-z]' "$OUT" || { echo "REFUSE: control failed -- not one non-empty c_target_objs" >&2; exit 9; }
echo "records $n  (triples read $n_in)"

echo
echo "== SHAPE A: which back ends set a per-language list at all =="
for k in c cxx d f rust jit; do
  printf '%-5s back ends with a non-empty list: %s\n' "$k" \
    "$(awk -F'|' -v k="$k=" '{for(i=3;i<=NF;i++) if (index($i,k)==1 && length($i)>length(k)) {print $1; break}}' "$OUT" | sort -u | tr '\n' ' ')"
done

echo
echo "== SHAPE B: keys whose value DIFFERS between triples of ONE cpu_type =="
echo "   (anything read from the first record alone is order-dependent here)"
awk -F'|' '
{ cpu=$1
  for (i=3;i<=NF;i++) {
    split($i, kv, "=")
    k=kv[1]; v=substr($i, length(k)+2)
    key=cpu SUBSEP k
    if (!(key in seen)) { seen[key]=1; val[key]=v; ntr[key]=1 }
    else if (val[key] != v) { diff[k]=diff[k] " " cpu; val[key]=v }
  }
}
END { for (k in diff) {
        nn=split(diff[k], a, " "); u=""
        for (j=1;j<=nn;j++) if (index(" " u " ", " " a[j] " ")==0) u=u " " a[j]
        printf "%-16s %s\n", k, u } }' "$OUT" | sort
