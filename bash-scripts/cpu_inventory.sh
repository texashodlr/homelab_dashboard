#!/bin/bash

model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')
threads=$(grep -c '^processor' /proc/cpuinfo)
cores=$(lscpu | awk -F: '/^Core\(s\) per socket|^Socket\(s\)/{gsub(/ /,"",$1); gsub(/^ /,"",$2); print $2}' | paste -sd'*' - | bc 2>/dev/null || echo "$threads")
echo -e "Model: $model\\nCore Count: $cores\\nThreads:$threads"
