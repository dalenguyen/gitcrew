#!/usr/bin/env bash
#
# gitcrew monitor — Launch the team monitoring dashboard
#

set -euo pipefail

AGENT_DIR=".agent"
# Keep dashboard scannable: show only last N log lines (full log: gitcrew log show)
LOG_TAIL_LINES=5

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
        --interval) INTERVAL="$2"; shift 2; continue ;;
        --once)     ONCE=true ;;
        -h|--help)  print_monitor_usage; exit 0 ;;
        *)
            gitcrew_error_unknown_option "$1"
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

    # Active branches (newest first) — only show branches not merged into main so list stays short
    echo "--- Active Agent Branches ---"
    local merge_base=main
    if ! git rev-parse -q refs/heads/main >/dev/null 2>&1; then
        merge_base=origin/main
    fi
    if ! git rev-parse -q "$merge_base" >/dev/null 2>&1; then
        merge_base=""
    fi
    local agent_branches=""
    if [ -n "$merge_base" ]; then
        local merged
        merged=$(git branch --merged "$merge_base" --format='%(refname:short)' 2>/dev/null; git branch -r --merged "$merge_base" --format='%(refname:short)' 2>/dev/null)
        while IFS= read -r branch; do
            if echo "$merged" | grep -qFx "$branch"; then
                continue
            fi
            agent_branches="${agent_branches}${agent_branches:+$'\n'}${branch}"
        done < <(git for-each-ref --sort=-committerdate refs/heads refs/remotes/origin --format='%(refname:short)' 2>/dev/null | grep -i "agent" || true)
    else
        agent_branches=$(git for-each-ref --sort=-committerdate refs/heads refs/remotes/origin --format='%(refname:short)' 2>/dev/null | grep -i "agent" || true)
    fi
    if [ -n "$agent_branches" ]; then
        while IFS= read -r branch; do
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

    # Agent log tail (short so dashboard stays scannable)
    if [ -f "${AGENT_DIR}/LOG.md" ]; then
        local LOG_LINES
        LOG_LINES=$(wc -l < "${AGENT_DIR}/LOG.md")
        if [ "$LOG_LINES" -gt 3 ]; then
            echo "--- Recent Agent Log ---"
            tail -${LOG_TAIL_LINES} "${AGENT_DIR}/LOG.md"
            echo "  (full log: gitcrew log show)"
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
        # Use same binary the user invoked so watch runs the single code path (render_dashboard via --once)
        if [ -n "${GITCREW_DIR:-}" ] && [ -x "${GITCREW_DIR}/gitcrew" ]; then
            GITCREW_BIN="${GITCREW_DIR}/gitcrew"
        else
            GITCREW_BIN="gitcrew"
        fi

        echo -e "${GITCREW_CYAN}Starting monitor (refresh every ${INTERVAL}s). Press Ctrl+C to stop.${GITCREW_NC}"
        echo ""

        watch -n "$INTERVAL" "$GITCREW_BIN" monitor --once
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
