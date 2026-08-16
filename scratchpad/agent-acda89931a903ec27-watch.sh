#!/bin/sh
# Progress emitter for the overnight run.  One line per interval so a long
# silent `make' is not mistaken for a hang -- from outside they are identical,
# which is the same shape as everything else this project keeps meeting.
#
# It reports DRIVE-GONE when the driver has exited WITHOUT writing its stamp,
# because "still building" and "died twenty minutes ago" otherwise look the
# same.  That is not hypothetical here: the first launch of this build failed
# `mt_assert_builddir' instantly and sat looking like a slow configure.
B=/tmp/b-acda89931a903ec27
GAS=/tmp/gasbin-agent-acda89931a903ec27
while true; do
  if [ -f "$B/all-gcc.rc" ]; then
    cc1=NO; [ -x "$B/gcc/cc1" ] && cc1=yes
    echo "BUILD-FINISHED rc=$(cat "$B/all-gcc.rc") cc1=$cc1 load=$(cut -d' ' -f1 /proc/loadavg)"
    break
  fi
  alive=$(pgrep -cf 'acda89931a903ec27-drive' 2>/dev/null || true)
  [ -n "$alive" ] || alive=0
  if [ "$alive" -eq 0 ]; then
    echo "DRIVE-GONE without stamp; tail: $(tail -1 /tmp/drive-agent-acda89931a903ec27.log)"
    break
  fi
  n=$(find "$B/gcc" -name '*.o' 2>/dev/null | wc -l)
  g=$(ls "$GAS" 2>/dev/null | grep -c -- '-as$')
  if [ -f "$B/conf.rc" ]; then
    echo "building conf=$(cat "$B/conf.rc") objs=$n gas=$g load=$(cut -d' ' -f1 /proc/loadavg) avail=$(free -g | awk '/Mem:/{print $7}')G"
  else
    echo "configuring gas=$g load=$(cut -d' ' -f1 /proc/loadavg)"
  fi
  sleep 480
done
