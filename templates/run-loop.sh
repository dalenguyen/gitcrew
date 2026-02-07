#!/bin/bash
# .agent/run-loop.sh — continuous agent loop
#
# Restarts the agent after each session, pulling latest changes between runs.
# Works with any CLI-based agent: Claude Code, Aider, Codex CLI, etc.
#
# Usage:
#   .agent/run-loop.sh <agent-name> [role-prompt-file] [--cli claude|aider|codex] [--model model-name] [--once]
#
# Examples:
#   .agent/run-loop.sh Agent-A
#   .agent/run-loop.sh Agent-A .agent/roles/feature.md
#   .agent/run-loop.sh Agent-B .agent/roles/bugfix.md --cli aider
#   .agent/run-loop.sh Agent-A feature --once   # run one session then exit (e.g. in Docker)

set -euo pipefail

AGENT_NAME=${1:?"Usage: ./run-loop.sh <agent-name> [role-prompt-file] [--cli tool] [--model model] [--once]"}
ROLE_FILE=${2:-""}
CLI_TOOL="claude"
MODEL="claude-opus-4-6-20250219"
RUN_ONCE=false

# Parse optional flags
shift 2 2>/dev/null || shift $# 2>/dev/null || true
while [ $# -gt 0 ]; do
    case "$1" in
        --cli)   CLI_TOOL="$2"; shift ;;
        --model) MODEL="$2"; shift ;;
        --once)  RUN_ONCE=true ;;
        *)       ;;
    esac
    shift
done

# Build the prompt
PROMPT=$(cat .agent/PROMPT.md)
if [ -n "$ROLE_FILE" ] && [ -f "$ROLE_FILE" ]; then
    PROMPT="${PROMPT}

$(cat "$ROLE_FILE")"
fi

# Replace placeholder with actual agent name
PROMPT=$(echo "$PROMPT" | sed "s/AGENT_NAME/$AGENT_NAME/g")

mkdir -p .agent/logs

echo "========================================"
echo "  gitcrew agent loop"
echo "  Agent:  ${AGENT_NAME}"
echo "  CLI:    ${CLI_TOOL}"
echo "  Model:  ${MODEL}"
echo "  Role:   ${ROLE_FILE:-base prompt only}"
echo "========================================"
echo ""

while true; do
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    COMMIT=$(git rev-parse --short=6 HEAD 2>/dev/null || echo "000000")
    LOGFILE=".agent/logs/${AGENT_NAME}_${TIMESTAMP}_${COMMIT}.log"

    echo "[$(date)] Starting session for ${AGENT_NAME} at ${COMMIT}"

    case "$CLI_TOOL" in
        claude)
            claude --dangerously-skip-permissions \
                   -p "$PROMPT" \
                   --model "$MODEL" \
                   2>&1 | tee "$LOGFILE"
            ;;
        aider)
            aider --message "$PROMPT" \
                  --yes --auto-commits \
                  2>&1 | tee "$LOGFILE"
            ;;
        cursor)
            agent -p "$PROMPT" \
                  2>&1 | tee "$LOGFILE"
            ;;
        codex)
            codex --prompt "$PROMPT" \
                  2>&1 | tee "$LOGFILE"
            ;;
        *)
            echo "ERROR: Unknown CLI tool '${CLI_TOOL}'. Supported: claude, cursor, aider, codex"
            exit 1
            ;;
    esac

    # Pull latest between sessions (unless --once)
    if [ "$RUN_ONCE" = true ]; then
        echo "[$(date)] Session complete (--once). Exiting."
        exit 0
    fi
    git pull origin main --rebase 2>/dev/null || true

    echo "[$(date)] Session complete. Restarting in 5s..."
    sleep 5
done
