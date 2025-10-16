#!/bin/bash

host=$(hostname)
kern=$(uname -r)
up=$(cut -d' ' -f1 /proc/uptime)
printf "%s,%s,%.0f\n" "$host" "$kern" "$up"

# This just prints the hostname, kernel and the nodes uptime in seconds
