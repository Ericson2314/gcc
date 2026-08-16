#!/bin/sh
# Thin driver: run agent-acda89931a903ec27-specs.sh over all 47 triples with
# the gathered single tools dir.  Exists only so the triple list comes from the
# committed back-end map rather than a command line -- one authority, not two.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?build dir}
TOOLS=${TOOLS:?gathered tools dir}
TARGETS=$(cut -d: -f2 "$S/agent-acda89931a903ec27-backends.txt" | paste -sd, -)
export B TOOLS TARGETS
exec sh "$S/agent-acda89931a903ec27-specs.sh"
