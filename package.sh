#!/usr/bin/env bash
# Use fpm to build a package for jdump
TYPE=${1:-"rpm"}
fpm \
-t $TYPE \
-v 0.0.1 \
-d "bash" \
-a "all" \
-s dir \
--name jdump \
--description "A tool to aid in debugging a broken JVM at 3AM" \
--url "https://github.com/datasift/jdump" \
jdump.sh=/usr/bin/jdump
