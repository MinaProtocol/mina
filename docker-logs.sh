#!/bin/bash

# Directory to store logs
LOG_DIR="./container_logs"
mkdir -p "$LOG_DIR"

# Iterate over all running container IDs
for CONTAINER_ID in $(docker ps -q); do
    # Get container name (without leading /)
    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$CONTAINER_ID" | sed 's|^/||')

    LOG_FILE="$LOG_DIR/${CONTAINER_ID}_${CONTAINER_NAME}.log"
    
    echo "Logging container $CONTAINER_ID ($CONTAINER_NAME) to $LOG_FILE"
    
    # Capture stdout/stderr
    docker logs "$CONTAINER_ID" &> "$LOG_FILE"
done
