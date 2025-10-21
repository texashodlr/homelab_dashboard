#!/bin/bash

DIR_DATE=$(date +"%Y%m%d_%H%M%S")

LOG_DIR="validated-base-hw-$DIR_DATE"

mkdir "$LOG_DIR"

if [ $? -eq 0 ]; then
  echo "Directory '$LOG_DIR' created successfully in the current working directory."
else
  echo "Failed to create directory '$LOG_DIR'."
fi

exit 0