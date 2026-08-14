#!/bin/sh
# #190 -- for every remaining `${target}'-family variable on the queue, count
# BOTH channels, because #189 proved one channel is a partial answer that
# presents as a complete one:
#
#   channel 1  config.gcc  <var>=...            -> @<var>@ -> a make variable
#   channel 2  tmake fragments  <VAR> += ...    -> -include $(tmake_file)
#
# Column 1 is assignments in config.gcc (a lower bound on back ends, since one
# back end has many triples and one assignment can serve many).  Column 2 is
# files under gcc/config/ that mention the MAKE variable at all -- deliberately
# over-broad, because this column can only ADD work, never authorise skipping
# it (PRINCIPLES: "when an instrument can only take away, make it too eager").
cd "$(dirname "$0")/../gcc" || exit 1
printf '%-32s %8s %8s  %s\n' VARIABLE cfg.gcc frags 'files under config/ naming the MAKE variable'
for pair in \
  user_headers_inc_next_pre:USER_H_INC_NEXT_PRE \
  user_headers_inc_next_post:USER_H_INC_NEXT_POST \
  extra_programs:EXTRA_PROGRAMS \
  inhibit_libc:INHIBIT_LIBC \
  TM_MULTILIB_EXCEPTIONS_CONFIG:TM_MULTILIB_EXCEPTIONS_CONFIG \
  d_target_objs:D_TARGET_OBJS \
  fortran_target_objs:FORTRAN_TARGET_OBJS \
  rust_target_objs:RUST_TARGET_OBJS \
  jit_target_objs:JIT_TARGET_OBJS \
  tm_d_file:TM_D_H \
  tm_rust_file:TM_RUST_H \
  cxx_target_objs:CXX_TARGET_OBJS \
  c_target_objs:C_TARGET_OBJS \
  use_gcc_stdint:USE_GCC_STDINT ; do
  v=${pair%%:*}; V=${pair##*:}
  n=`grep -c "^[^#]*${v}=" config.gcc`
  f=`grep -rl "${V}" config/ | sort`
  m=`echo "$f" | grep -c .`
  printf '%-32s %8s %8s  %s\n' "$v" "$n" "$m" "`echo $f`"
done
