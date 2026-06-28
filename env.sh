#!/bin/bash
# Source this file in your shell profile (~/.zshrc or ~/.bashrc):
#   source /path/to/container-docker/env.sh

MACHINE_NAME="${CONTAINER_DOCKER_MACHINE:-docker-vm}"

if command -v container >/dev/null 2>&1 && container machine inspect "$MACHINE_NAME" >/dev/null 2>&1; then
  MACHINE_IP=$(container machine inspect "$MACHINE_NAME" 2>/dev/null \
    | grep '"ipAddress"' \
    | head -1 \
    | sed 's/.*: *"//;s/".*//')

  if [ -n "$MACHINE_IP" ]; then
    export DOCKER_HOST="tcp://${MACHINE_IP}:2375"
  fi
fi
