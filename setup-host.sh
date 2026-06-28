#!/bin/bash
set -euo pipefail

MACHINE_NAME="${1:-devel}"
DOCKER_PORT=2375

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    green "  ✓ $label"
    return 0
  else
    red "  ✗ $label"
    return 1
  fi
}

bold "Checking prerequisites..."

if ! check "container CLI installed" command -v container; then
  red "  Install Apple Container: https://github.com/apple/container/releases"
  exit 1
fi

if ! check "container system running" container system status; then
  red "  Run: container system start"
  exit 1
fi

if ! check "Docker CLI installed" command -v docker; then
  red "  Run: brew install docker docker-compose"
  exit 1
fi

if ! container machine inspect "$MACHINE_NAME" >/dev/null 2>&1; then
  red "  ✗ Machine '$MACHINE_NAME' not found"
  red "  Run: make setup"
  exit 1
fi

echo ""
bold "Resolving Docker host..."

MACHINE_IP=$(container machine inspect "$MACHINE_NAME" 2>/dev/null \
  | grep '"ipAddress"' \
  | head -1 \
  | sed 's/.*: *"//;s/".*//')

if [ -z "$MACHINE_IP" ]; then
  red "  Cannot determine machine IP address"
  red "  Is the machine running? Try: make run"
  exit 1
fi

DOCKER_HOST_VALUE=""
if host "${MACHINE_NAME}.test" >/dev/null 2>&1; then
  DOCKER_HOST_VALUE="tcp://${MACHINE_NAME}.test:${DOCKER_PORT}"
  green "  Using DNS: ${MACHINE_NAME}.test (${MACHINE_IP})"
else
  DOCKER_HOST_VALUE="tcp://${MACHINE_IP}:${DOCKER_PORT}"
  green "  Using IP: ${MACHINE_IP} (DNS for ${MACHINE_NAME}.test not available)"
fi

export DOCKER_HOST="$DOCKER_HOST_VALUE"

echo ""
bold "Verifying Docker connectivity..."

if check "Docker daemon reachable" docker info; then
  :
else
  red "  Docker daemon not responding at $DOCKER_HOST"
  red "  Ensure the machine is running: make run (then exit the shell)"
  exit 1
fi

echo ""
bold "Testing volume mount..."

TMPFILE=$(mktemp "$HOME/.container-docker-test-XXXXXX")
echo "container-docker-volume-test" > "$TMPFILE"
TMPNAME=$(basename "$TMPFILE")

if docker run --rm -v "$HOME:/host:ro" alpine cat "/host/$TMPNAME" 2>/dev/null | grep -q "container-docker-volume-test"; then
  green "  ✓ Volume mount works — macOS home directory is accessible inside containers"
else
  red "  ✗ Volume mount test failed"
  red "  Docker containers cannot see your macOS home directory"
fi

rm -f "$TMPFILE"

echo ""
bold "Add this to your shell profile (.zshrc / .bashrc):"
echo ""
echo "  export DOCKER_HOST=$DOCKER_HOST_VALUE"
echo ""
green "Done."
