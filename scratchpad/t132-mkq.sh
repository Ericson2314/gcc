#!/bin/sh
# #125 -- ask make itself what it read, rather than reading the Makefile.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b132}
cat > "$B/q.mk" <<'EOF'
include Makefile
q:
	@echo "MULTI_TARGET_OBJS words: $(words $(MULTI_TARGET_OBJS))"
	@echo "MULTI_TARGET_INC_DIRS words: $(words $(MULTI_TARGET_INC_DIRS))"
	@echo "MULTI_TARGET_INC_STEMS set: $(if $(MULTI_TARGET_INC_STEMS),yes,NO)"
EOF
sh "$S/eb-shell.sh" "cd $B/gcc && make -f $B/q.mk q"
