#!/bin/bash
# .agent/spawn-docker.sh — spin up an isolated agent container
#
# Usage: .agent/spawn-docker.sh <agent-name> [role]
#
# Each agent gets its own filesystem. They share only through
# git push/pull to a bare upstream repo.

set -euo pipefail

AGENT_NAME=${1:?"Usage: spawn-docker.sh <agent-name> [role]"}
ROLE=${2:-feature}

# Create bare upstream repo if it doesn't exist
UPSTREAM="/tmp/gitcrew-upstream.git"
if [ ! -d "$UPSTREAM" ]; then
    echo "Creating bare upstream repo at ${UPSTREAM}..."
    git clone --bare . "$UPSTREAM"
fi

echo "Spawning ${AGENT_NAME} (role: ${ROLE}) in Docker..."

docker run -d \
    --name "gitcrew-${AGENT_NAME}" \
    -v "${UPSTREAM}":/upstream \
    -e AGENT_NAME="$AGENT_NAME" \
    -e AGENT_ROLE="$ROLE" \
    ubuntu:24.04 \
    bash -c '
        apt-get update -qq && apt-get install -y -qq git curl > /dev/null 2>&1

        # Install your language runtime, test tools, and agent CLI here
        # Examples:
        #   curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs
        #   apt-get install -y python3 python3-pip
        #   curl -fsSL https://sh.rustup.rs | sh -s -- -y

        git clone /upstream /workspace
        cd /workspace

        # Configure git for this agent
        git config user.name "$AGENT_NAME"
        git config user.email "${AGENT_NAME}@gitcrew.local"
        git remote set-url origin /upstream

        # Run the agent loop
        exec bash .agent/run-loop.sh "$AGENT_NAME" ".agent/roles/${AGENT_ROLE}.md"
    '

echo ""
echo "Container 'gitcrew-${AGENT_NAME}' started."
echo ""
echo "Useful commands:"
echo "  docker logs -f gitcrew-${AGENT_NAME}    # Follow agent output"
echo "  docker stop gitcrew-${AGENT_NAME}       # Stop agent"
echo "  docker rm gitcrew-${AGENT_NAME}         # Remove container"
