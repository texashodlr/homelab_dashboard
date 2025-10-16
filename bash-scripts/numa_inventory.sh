#!/bin/bash

if command -v numactl >/dev/null; then
  nodes=$(numactl --hardware | awk '/available:/ {print $2}')
else
  nodes=1
fi
mem_wb=$(awk '/MemTotal:/ {printf "%.0f\n", $2/1024}' /proc/meminfo)
echo -e "Nodes: $nodes,\\nMemory $mem_wb"
