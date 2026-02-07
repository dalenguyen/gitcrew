#!/usr/bin/env bash
#
# gitcrew log — Append entries to .agent/LOG.md
#

set -euo pipefail

AGENT_DIR=".agent"
LOG_FILE="${AGENT_DIR}/LOG.md"

print_log_usage() {
    echo -e "${GITCREW_BOLD}USAGE${GITCREW_NC}"
    echo "    gitcrew log <agent-name> <message>"
    echo "    gitcrew log show"
    echo ""
    echo -e "${GITCREW_BOLD}SUBCOMMANDS${GITCREW_NC}"
    echo -e "    ${GITCREW_GREEN}show${GITCREW_NC}                    Show recent log entries"
    echo -e "    ${GITCREW_GREEN}<agent> <message>${GITCREW_NC}       Append a log entry"
    echo ""
    echo -e "${GITCREW_BOLD}OPTIONS${GITCREW_NC}"
    echo "    -n <count>      Number of lines to show (default: 20)"
    echo "    -h, --help      Show this help"
    echo ""
    echo -e "${GITCREW_BOLD}EXAMPLES${GITCREW_NC}"
    echo "    gitcrew log Agent-A \"Refactored auth module, all tests pass\""
    echo "    gitcrew log Agent-B \"Don't touch config/db.ts — breaks on format change\""
    echo "    gitcrew log show"
    echo "    gitcrew log show -n 50"
    echo ""
}

ensure_log_file() {
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${GITCREW_RED}Error: ${LOG_FILE} not found.${GITCREW_NC}"
        echo "Run 'gitcrew init' first."
        exit 1
    fi
}

show_log() {
    ensure_log_file

    local count=20
    shift || true  # remove 'show'
    while [ $# -gt 0 ]; do
        case "$1" in
            -n) count="$2"; shift ;;
            *)  ;;
        esac
        shift
    done

    echo -e "${GITCREW_BOLD}Recent Agent Log${GITCREW_NC} (last ${count} lines)"
    echo ""
    tail -"$count" "$LOG_FILE"
}

append_log() {
    ensure_log_file

    local agent_name="$1"
    shift
    local message="$*"

    if [ -z "$agent_name" ] || [ -z "$message" ]; then
        echo -e "${GITCREW_RED}Error: Agent name and message required.${GITCREW_NC}"
        echo "Usage: gitcrew log <agent-name> <message>"
        exit 1
    fi

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M')

    cat >> "$LOG_FILE" << EOF

### ${timestamp} — ${agent_name}
- ${message}
EOF

    echo -e "${GITCREW_GREEN}+${GITCREW_NC} Logged by ${agent_name}: ${message}"
}

# --- Main dispatch ---

SUBCMD="${1:-}"

case "$SUBCMD" in
    ""|--help|-h) print_log_usage ;;
    show)         show_log "$@" ;;
    *)            append_log "$@" ;;
esac
