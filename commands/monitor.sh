#!/usr/bin/env bash
#
# gitcrew monitor — Launch the team monitoring dashboard
#

set -euo pipefail

AGENT_DIR=".agent"

print_monitor_usage() {
    echo -e "${GITCREW_BOLD}USAGE${GITCREW_NC}"
    echo "    gitcrew monitor [options]"
    echo ""
    echo -e "${GITCREW_BOLD}OPTIONS${GITCREW_NC}"
    echo "    --interval <s>  Refresh interval in seconds (default: 15)"
    echo "    --once          Print dashboard once and exit"
    echo "    -h, --help      Show this help"
    echo ""
}

INTERVAL=15
ONCE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --interval) INTERVAL="$2"; shift ;;
        --once)     ONCE=true ;;
        -h|--help)  print_monitor_usage; exit 0 ;;
        *)
            echo -e "${GITCREW_RED}Error: Unknown option '$1'${GITCREW_NC}"
            print_monitor_usage
            exit 1
            ;;
    esac
    shift
done

if [ ! -d "$AGENT_DIR" ]; then
    echo -e "${GITCREW_RED}Error: .agent/ directory not found.${GITCREW_NC}"
    echo "Run 'gitcrew init' first."
    exit 1
fi

render_dashboard() {
    echo "=========================================="
    echo "  GITCREW AGENT MONITOR — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""

    # Task status
    echo "--- Task Status ---"
    local LOCKED=0
    local BACKLOG=0
    local DONE=0

    if [ -f "${AGENT_DIR}/TASKS.md" ]; then
        # Use state-machine section parsing (works with emoji headers)
        local section=""
        while IFS= read -r line; do
            if echo "$line" | grep -q "^## .*Locked"; then section="locked"
            elif echo "$line" | grep -q "^## .*Backlog"; then section="backlog"
            elif echo "$line" | grep -q "^## .*Done"; then section="done"
            elif echo "$line" | grep -q "^## "; then section=""
            elif echo "$line" | grep -q "^- \["; then
                case "$section" in
                    locked)  LOCKED=$((LOCKED + 1)) ;;
                    backlog) BACKLOG=$((BACKLOG + 1)) ;;
                    done)    DONE=$((DONE + 1)) ;;
                esac
            fi
        done < "${AGENT_DIR}/TASKS.md"
    fi

    echo "  In Progress: ${LOCKED}  |  Backlog: ${BACKLOG}  |  Done: ${DONE}"
    echo ""

    # Active branches
    echo "--- Active Agent Branches ---"
    local agent_branches
    agent_branches=$(git branch -a 2>/dev/null | grep -i "agent" || true)
    if [ -n "$agent_branches" ]; then
        while IFS= read -r branch; do
            branch=$(echo "$branch" | sed 's/^[* ]*//')
            local LAST
            LAST=$(git log -1 --format="%ar — %s" "$branch" 2>/dev/null || echo "unknown")
            echo "  ${branch} (${LAST})"
        done <<< "$agent_branches"
    else
        echo "  (no agent branches found)"
    fi
    echo ""

    # Recent commits
    echo "--- Recent Commits (all branches) ---"
    git log --oneline --all -10 2>/dev/null || echo "  (no commits yet)"
    echo ""

    # Agent log tail
    if [ -f "${AGENT_DIR}/LOG.md" ]; then
        local LOG_LINES
        LOG_LINES=$(wc -l < "${AGENT_DIR}/LOG.md")
        if [ "$LOG_LINES" -gt 3 ]; then
            echo "--- Recent Agent Log ---"
            tail -15 "${AGENT_DIR}/LOG.md"
            echo ""
        fi
    fi

    # Active log files (running agents)
    if [ -d "${AGENT_DIR}/logs" ]; then
        local RECENT_LOGS
        RECENT_LOGS=$(find "${AGENT_DIR}/logs" -name "*.log" -mmin -5 2>/dev/null | wc -l | tr -d ' ')
        if [ "$RECENT_LOGS" -gt 0 ]; then
            echo "--- Active Agents (logs updated < 5 min ago) ---"
            find "${AGENT_DIR}/logs" -name "*.log" -mmin -5 2>/dev/null | while IFS= read -r logfile; do
                local name
                name=$(basename "$logfile" | cut -d'_' -f1)
                local size
                size=$(wc -c < "$logfile" | tr -d ' ')
                echo "  ${name}: ${logfile} (${size} bytes)"
            done
            echo ""
        fi
    fi
}

if [ "$ONCE" = true ]; then
    render_dashboard
else
    # Check if 'watch' is available
    if command -v watch &>/dev/null; then
        # Export function for watch
        export -f render_dashboard 2>/dev/null || true
        export AGENT_DIR

        echo -e "${GITCREW_CYAN}Starting monitor (refresh every ${INTERVAL}s). Press Ctrl+C to stop.${GITCREW_NC}"
        echo ""

        # Use a temp script since 'watch' can't easily call exported functions on all platforms
        WATCH_SCRIPT=$(mktemp)
        cat > "$WATCH_SCRIPT" << 'WATCHEOF'
#!/usr/bin/env bash
AGENT_DIR=".agent"

echo "=========================================="
echo "  GITCREW AGENT MONITOR — $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

echo "--- Task Status ---"
BACKLOG=0; DONE=0; LOCKED=0
if [ -f "${AGENT_DIR}/TASKS.md" ]; then
    BACKLOG=$(awk '/## .* Backlog/,/^## /' "${AGENT_DIR}/TASKS.md" 2>/dev/null | grep -c "^- \[ \]" || echo 0)
    DONE=$(awk '/## .* Done/,/^## |$/' "${AGENT_DIR}/TASKS.md" 2>/dev/null | grep -c "^- \[x\]" || echo 0)
    LOCKED=$(awk '/## .* Locked/,/^## /' "${AGENT_DIR}/TASKS.md" 2>/dev/null | grep -c "^- \[" || echo 0)
fi
echo "  In Progress: ${LOCKED}  |  Backlog: ${BACKLOG}  |  Done: ${DONE}"
echo ""

echo "--- Active Agent Branches ---"
git branch -a 2>/dev/null | grep -i "agent" | while IFS= read -r b; do
    b=$(echo "$b" | sed 's/^[* ]*//')
    LAST=$(git log -1 --format="%ar — %s" "$b" 2>/dev/null || echo "unknown")
    echo "  ${b} (${LAST})"
done
echo ""

echo "--- Recent Commits ---"
git log --oneline --all -10 2>/dev/null || echo "  (no commits)"
echo ""

if [ -f "${AGENT_DIR}/LOG.md" ]; then
    echo "--- Recent Agent Log ---"
    tail -15 "${AGENT_DIR}/LOG.md"
fi
WATCHEOF
        chmod +x "$WATCH_SCRIPT"
        watch -n "$INTERVAL" bash "$WATCH_SCRIPT"
        rm -f "$WATCH_SCRIPT"
    else
        echo -e "${GITCREW_YELLOW}Warning: 'watch' not found. Falling back to manual refresh loop.${GITCREW_NC}"
        echo -e "Press Ctrl+C to stop."
        echo ""
        while true; do
            clear
            render_dashboard
            sleep "$INTERVAL"
        done
    fi
fi
