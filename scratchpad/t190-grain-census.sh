#!/bin/sh
# #190 -- THE GRAIN of every remaining `${target}'-family variable: is its
# value a property of the BACK END or of the TRIPLE?
#
# This is the question that decides whether the #189 template applies at all.
# #189 could put `extra_headers' in `include-<cpu_type>/' because all 188
# triples of a back end install the same intrinsics.  `use_gcc_stdint' is not
# like that -- ten back ends' triples disagree with each other -- so no
# per-back-end artefact can express it and choosing one would be picking a
# winner, the `mm_malloc.h' shape #189 refused to guess.
#
# So for each variable, over all 188 triples of contrib/config-list.mk:
#   CONSTANT  every triple of every back end agrees   -> per-back-end artefact
#   VARIES-N  N back ends disagree with themselves    -> needs the triple
#
# The values are compared as SETS OF WORDS, sorted, so an ordering difference
# between two triples is not scored as a divergence.
#
# Non-vacuity: refuses if fewer than 100 triples were read, and prints the
# per-variable population so a variable nobody sets cannot read as CONSTANT
# agreement.
S=$1
: ${S:?srcdir}
OUT=${2:?outfile}
VARS="use_gcc_stdint user_headers_inc_next_pre user_headers_inc_next_post
      extra_programs inhibit_libc TM_MULTILIB_EXCEPTIONS_CONFIG
      d_target_objs fortran_target_objs rust_target_objs jit_target_objs
      tm_d_file tm_rust_file cxx_target_objs c_target_objs extra_headers"
LIST=`sed -n '/^LIST = /,/^ *$/p' $S/contrib/config-list.mk \
      | sed -e 's/^LIST = //' | tr -d '\134' | tr ' ' '\012' \
      | sed -e 's/OPT.*$//' | grep . | sort -u`
: > $OUT
for t in $LIST; do
  (
    cd $S/gcc
    srcdir=.
    target=`../config.sub $t 2>/dev/null` || exit 0
    test x"$target" = x && exit 0
    tm_defines= cpu_type= target_cpu_default=
    tm_file= tm_p_file= tmake_file= extra_objs= extra_options=
    out_file= md_file= target_gtfiles= common_out_file=
    target_has_targetm_common= dwarf2= extra_modes= extra_gcc_objs=
    extra_parts= TM_MULTILIB_CONFIG=
    for v in $VARS; do eval "$v="; done
    . ./config.gcc > /dev/null 2>&1 || exit 0
    for v in $VARS; do
      eval "val=\$$v"
      val=`echo $val | tr ' ' '\012' | sort -u | tr '\012' ' '`
      echo "$v $cpu_type [$val]"
    done
  ) >> $OUT
done
n=`awk '$1 == "use_gcc_stdint"' $OUT | grep -c .`
if test "$n" -lt 100; then
  echo "REFUSE: read only $n triples; the census did not run" >&2
  exit 9
fi
echo "triples $n"
printf '%-32s %-9s %s\n' VARIABLE GRAIN 'back ends that set it / that disagree with themselves'
for v in $VARS; do
  awk -v want="$v" '
    $1 == want {
      cpu = $2; val = "";
      for (i = 3; i <= NF; i++) val = val $i " ";
      # The empty value arrives as "[ ]", not "[]": echo of an empty string
      # through tr/sort emits one blank line, which becomes a single space.
      # NO APOSTROPHE ANYWHERE IN THIS BLOCK: the awk program is inside single
      # quotes, so one ends it and the rest of the program is handed to the
      # SHELL -- which is the same trap gen-target-manifest.sh records twice,
      # and it fired here on the first run.  The first draft
      # tested against "[] " and therefore scored EVERY variable as set by all
      # 48 back ends -- a column that agreed with itself for every row, which
      # is what an always-true test looks like.  Recorded rather than quietly
      # swapped: the GRAIN column was unaffected (it compares values with each
      # other, not with a literal), which is why the wrong column was
      # believable next to a right one.
      if (val !~ /^\[ *\] *$/) set[cpu] = 1;
      if (!(cpu in seen)) { seen[cpu] = val; next }
      if (seen[cpu] != val) bad[cpu] = 1;
    }
    END {
      ns = 0; for (c in set) ns++;
      nb = 0; names = "";
      for (c in bad) { nb++; names = names " " c }
      printf "%-32s %-9s set-by=%d  disagree=%d %s\n", want,
             (nb ? "TRIPLE" : "BACKEND"), ns, nb, names;
    }' $OUT
done
