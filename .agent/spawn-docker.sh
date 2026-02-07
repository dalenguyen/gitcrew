#!/bin/bash
# .agent/spawn-docker.sh — spin up an isolated agent container
#
# Usage: .agent/spawn-docker.sh <agent-name> [role] [--cli tool] [--model m] [--once]
#
# Each agent gets its own filesystem. They share only through
# git push/pull to a bare upstream repo.
#
# Requires: gitcrew docker build (run once to create the image)

set -euo pipefail

AGENT_NAME=${1:?"Usage: spawn-docker.sh <agent-name> [role] [--cli tool] [--model m] [--once]"}
ROLE=${2:-feature}
AGENT_CLI="claude"
AGENT_MODEL=""
AGENT_ONCE="false"

shift 2 2>/dev/null || shift $# 2>/dev/null || true
while [ $# -gt 0 ]; do
    case "$1" in
        --cli)   AGENT_CLI="$2"; shift ;;
        --model) AGENT_MODEL="$2"; shift ;;
        --once)  AGENT_ONCE="true" ;;
        *)       ;;
    esac
    shift
done

IMAGE_NAME="gitcrew-agent"

# Check image exists
if ! docker image inspect "${IMAGE_NAME}" &>/dev/null; then
    echo "Error: Image '${IMAGE_NAME}' not found."
    echo "Run: gitcrew docker build"
    exit 1
fi

# Create bare upstream repo if it doesn't exist
UPSTREAM="/tmp/gitcrew-upstream.git"
if [ ! -d "$UPSTREAM" ]; then
    echo "Creating bare upstream repo at ${UPSTREAM}..."
    git clone --bare . "$UPSTREAM"
fi

echo "Spawning ${AGENT_NAME} (role: ${ROLE}, cli: ${AGENT_CLI}) in Docker..."
[ "$AGENT_ONCE" = "true" ] && echo "  (--once: container will exit after one session)"

docker run -d \
    --name "gitcrew-${AGENT_NAME}" \
    -v "${UPSTREAM}":/upstream:rw \
    -e AGENT_NAME="$AGENT_NAME" \
    -e AGENT_ROLE="$ROLE" \
    -e AGENT_CLI="$AGENT_CLI" \
    -e AGENT_MODEL="$AGENT_MODEL" \
    -e AGENT_ONCE="$AGENT_ONCE" \
    "${IMAGE_NAME}" \
    bash -c '
        git clone /upstream /workspace
        cd /workspace

        git config user.name "$AGENT_NAME"
        git config user.email "${AGENT_NAME}@gitcrew.local"
        git remote set-url origin /upstream

        RUN_ARGS="--cli ${AGENT_CLI:-claude}"
        [ -n "${AGENT_MODEL:-}" ] && RUN_ARGS="$RUN_ARGS --model $AGENT_MODEL"
        [ "$AGENT_ONCE" = "true" ] && RUN_ARGS="$RUN_ARGS --once"

        exec bash .agent/run-loop.sh "$AGENT_NAME" ".agent/roles/${AGENT_ROLE}.md" $RUN_ARGS
    '

echo ""
echo "Container 'gitcrew-${AGENT_NAME}' started."
echo ""
echo "Useful commands:"
echo "  gitcrew docker logs ${AGENT_NAME}      # Follow agent output"
echo "  gitcrew docker stop ${AGENT_NAME}      # Stop agent"
echo "  gitcrew docker ps                      # List all agent containers"
echo "  gitcrew docker clean                   # Remove all containers"
