#!/bin/bash

lsblk -b -d -o NAME,SIZE,TYPE -n | awk '$3!="loop"{print $1", "$2", "$3}'
