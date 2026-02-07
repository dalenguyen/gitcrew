#!/usr/bin/env bash
#
# gitcrew status — Quick project overview
#

set -euo pipefail

AGENT_DIR=".agent"

print_status_usage() {
    echo -e "${GITCREW_BOLD}USAGE${GITCREW_NC}"
    echo "    gitcrew status"
    echo ""
    echo "Shows a quick summary of the agent team state:"
    echo "task counts, active branches, last commit, and git status."
    echo ""
}

case "${1:-}" in
    -h|--help) print_status_usage; exit 0 ;;
esac

# --- Header ---
echo -e "${GITCREW_BOLD}gitcrew status${GITCREW_NC}"
echo ""

# --- Agent infrastructure ---
if [ ! -d "$AGENT_DIR" ]; then
    echo -e "  ${GITCREW_RED}Not initialized${GITCREW_NC} — run 'gitcrew init' first"
    exit 1
fi

# --- Task counts ---
LOCKED=0
BACKLOG=0
DONE=0

if [ -f "${AGENT_DIR}/TASKS.md" ]; then
    local_section=""
    while IFS= read -r line; do
        if echo "$line" | grep -q "^## .*Locked"; then local_section="locked"
        elif echo "$line" | grep -q "^## .*Backlog"; then local_section="backlog"
        elif echo "$line" | grep -q "^## .*Done"; then local_section="done"
        elif echo "$line" | grep -q "^## "; then local_section=""
        elif echo "$line" | grep -q "^- \["; then
            case "$local_section" in
                locked)  LOCKED=$((LOCKED + 1)) ;;
                backlog) BACKLOG=$((BACKLOG + 1)) ;;
                done)    DONE=$((DONE + 1)) ;;
            esac
        fi
    done < "${AGENT_DIR}/TASKS.md"
fi

echo -e "  ${GITCREW_BOLD}Tasks:${GITCREW_NC}  ${GITCREW_YELLOW}${LOCKED} in progress${GITCREW_NC}  ${GITCREW_BLUE}${BACKLOG} backlog${GITCREW_NC}  ${GITCREW_GREEN}${DONE} done${GITCREW_NC}"

# --- Active agent branches ---
AGENT_BRANCHES=$(git branch -a 2>/dev/null | grep -ic "agent" || true)
AGENT_BRANCHES="${AGENT_BRANCHES:-0}"
echo -e "  ${GITCREW_BOLD}Agent branches:${GITCREW_NC}  ${AGENT_BRANCHES}"

# --- Last commit ---
LAST_COMMIT=$(git log -1 --format="%h %s (%ar)" 2>/dev/null || echo "none")
echo -e "  ${GITCREW_BOLD}Last commit:${GITCREW_NC}  ${LAST_COMMIT}"

# --- Working tree ---
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRTY" -gt 0 ]; then
    echo -e "  ${GITCREW_BOLD}Working tree:${GITCREW_NC}  ${GITCREW_YELLOW}${DIRTY} uncommitted change(s)${GITCREW_NC}"
else
    echo -e "  ${GITCREW_BOLD}Working tree:${GITCREW_NC}  ${GITCREW_GREEN}clean${GITCREW_NC}"
fi

# --- Hooks ---
HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || echo "")
if [ -n "$HOOKS_PATH" ] && [ -f "${HOOKS_PATH}/pre-push" ]; then
    echo -e "  ${GITCREW_BOLD}Pre-push hook:${GITCREW_NC}  ${GITCREW_GREEN}active${GITCREW_NC}"
else
    echo -e "  ${GITCREW_BOLD}Pre-push hook:${GITCREW_NC}  ${GITCREW_YELLOW}not installed${GITCREW_NC}"
fi

# --- Roles available ---
ROLE_COUNT=0
if [ -d "${AGENT_DIR}/roles" ]; then
    ROLE_COUNT=$(find "${AGENT_DIR}/roles" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
fi
echo -e "  ${GITCREW_BOLD}Roles:${GITCREW_NC}  ${ROLE_COUNT} available"

echo ""
