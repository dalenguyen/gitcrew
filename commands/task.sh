#!/usr/bin/env bash
#
# gitcrew task — Manage the agent task board
#

set -euo pipefail

AGENT_DIR=".agent"
TASKS_FILE="${AGENT_DIR}/TASKS.md"

print_task_usage() {
    echo -e "${GITCREW_BOLD}USAGE${GITCREW_NC}"
    echo "    gitcrew task <subcommand> [options]"
    echo ""
    echo -e "${GITCREW_BOLD}SUBCOMMANDS${GITCREW_NC}"
    echo -e "    ${GITCREW_GREEN}list${GITCREW_NC}                    Show all tasks by status"
    echo -e "    ${GITCREW_GREEN}add${GITCREW_NC} <description>       Add a task to the backlog"
    echo -e "    ${GITCREW_GREEN}lock${GITCREW_NC} <n> <agent-name>   Lock task #n for an agent"
    echo -e "    ${GITCREW_GREEN}done${GITCREW_NC} <n> [summary]      Mark task #n as completed"
    echo -e "    ${GITCREW_GREEN}unlock${GITCREW_NC} <n>              Move task #n back to backlog"
    echo -e "    ${GITCREW_GREEN}import${GITCREW_NC} <file>           Import tasks from a file (one per line)"
    echo -e "    ${GITCREW_GREEN}clear-done${GITCREW_NC}              Archive completed tasks"
    echo ""
    echo -e "${GITCREW_BOLD}EXAMPLES${GITCREW_NC}"
    echo "    gitcrew task add \"Fix: login redirect fails on expired tokens\""
    echo "    gitcrew task add \"Feature: add CSV export to reports page\""
    echo "    gitcrew task list"
    echo "    gitcrew task lock 1 Agent-A"
    echo "    gitcrew task done 1 \"Fixed by adding token refresh logic\""
    echo ""
}

ensure_tasks_file() {
    if [ ! -f "$TASKS_FILE" ]; then
        echo -e "${GITCREW_RED}Error: ${TASKS_FILE} not found.${GITCREW_NC}"
        echo "Run 'gitcrew init' first."
        exit 1
    fi
}

# Extract lines from a specific section of TASKS.md
# Usage: get_section "Locked" | grep "^- \["
# Uses state-machine approach that works regardless of emojis in headers
get_section() {
    local section_keyword="$1"
    local in_section=false

    while IFS= read -r line; do
        if echo "$line" | grep -q "^## .*${section_keyword}"; then
            in_section=true
            continue
        fi
        if [ "$in_section" = true ] && echo "$line" | grep -q "^## "; then
            break
        fi
        if [ "$in_section" = true ]; then
            echo "$line"
        fi
    done < "$TASKS_FILE"
}

list_tasks() {
    ensure_tasks_file

    echo -e "${GITCREW_BOLD}Agent Task Board${GITCREW_NC}"
    echo ""

    # Locked tasks
    echo -e "${GITCREW_YELLOW}Locked (In Progress):${GITCREW_NC}"
    local locked_tasks
    locked_tasks=$(get_section "Locked" | grep "^- \[" || true)
    if [ -n "$locked_tasks" ]; then
        while IFS= read -r line; do
            echo "  ${line}"
        done <<< "$locked_tasks"
    else
        echo "  (none)"
    fi
    echo ""

    # Backlog tasks (numbered for easy reference)
    echo -e "${GITCREW_BLUE}Backlog (Available):${GITCREW_NC}"
    local backlog_tasks
    backlog_tasks=$(get_section "Backlog" | grep "^- \[ \]" || true)
    if [ -n "$backlog_tasks" ]; then
        local i=1
        while IFS= read -r line; do
            local desc="${line#- \[ \] }"
            echo -e "  ${GITCREW_DIM}#${i}${GITCREW_NC}  ${desc}"
            i=$((i + 1))
        done <<< "$backlog_tasks"
    else
        echo "  (none — add tasks with 'gitcrew task add')"
    fi
    echo ""

    # Done tasks
    echo -e "${GITCREW_GREEN}Done:${GITCREW_NC}"
    local done_tasks
    done_tasks=$(get_section "Done" | grep "^- \[x\]" || true)
    if [ -n "$done_tasks" ]; then
        local count
        count=$(echo "$done_tasks" | wc -l | tr -d ' ')
        echo "  ${count} task(s) completed"
        echo "$done_tasks" | tail -5 | while IFS= read -r line; do
            echo "  ${line}"
        done
        if [ "$count" -gt 5 ]; then
            echo "  ... and $((count - 5)) more"
        fi
    else
        echo "  (none yet)"
    fi
    echo ""
}

add_task() {
    ensure_tasks_file

    local description="$*"

    if [ -z "$description" ]; then
        echo -e "${GITCREW_RED}Error: Task description is required.${GITCREW_NC}"
        echo "Usage: gitcrew task add <description>"
        exit 1
    fi

    # Insert task into Backlog section
    local tmpfile
    tmpfile=$(mktemp)
    local in_backlog=false
    local added=false

    while IFS= read -r line; do
        echo "$line" >> "$tmpfile"

        # Detect backlog section header
        if echo "$line" | grep -q "^## .*Backlog"; then
            in_backlog=true
        fi

        # Add task after first comment line or empty line in backlog section
        if [ "$in_backlog" = true ] && [ "$added" = false ]; then
            if echo "$line" | grep -q "^<!--" || [ -z "$line" ]; then
                echo "- [ ] ${description}" >> "$tmpfile"
                added=true
                in_backlog=false
            fi
        fi
    done < "$TASKS_FILE"

    if [ "$added" = false ]; then
        # Fallback: append before Done section
        local tmpfile2
        tmpfile2=$(mktemp)
        local found_done=false
        while IFS= read -r line; do
            if echo "$line" | grep -q "^## .*Done" && [ "$found_done" = false ]; then
                echo "- [ ] ${description}" >> "$tmpfile2"
                echo "" >> "$tmpfile2"
                found_done=true
            fi
            echo "$line" >> "$tmpfile2"
        done < "$TASKS_FILE"

        if [ "$found_done" = true ]; then
            mv "$tmpfile2" "$TASKS_FILE"
        else
            echo "- [ ] ${description}" >> "$TASKS_FILE"
        fi
        rm -f "$tmpfile"
    else
        mv "$tmpfile" "$TASKS_FILE"
    fi

    echo -e "${GITCREW_GREEN}+${GITCREW_NC} Added task: ${description}"
}

lock_task() {
    ensure_tasks_file

    local task_num="${1:-}"
    local agent_name="${2:-}"

    if [ -z "$task_num" ] || [ -z "$agent_name" ]; then
        echo -e "${GITCREW_RED}Error: Task number and agent name required.${GITCREW_NC}"
        echo "Usage: gitcrew task lock <number> <agent-name>"
        exit 1
    fi

    # Get the nth backlog task
    local task_line
    task_line=$(get_section "Backlog" | grep "^- \[ \]" | sed -n "${task_num}p" || true)

    if [ -z "$task_line" ]; then
        echo -e "${GITCREW_RED}Error: Task #${task_num} not found in backlog.${GITCREW_NC}"
        exit 1
    fi

    local task_desc="${task_line#- \[ \] }"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M')
    local locked_line="- [ ] ${task_desc} — locked by **${agent_name}** at ${timestamp}"

    # Remove from backlog
    local tmpfile
    tmpfile=$(mktemp)
    local removed=false
    local count=0
    local in_backlog=false

    while IFS= read -r line; do
        if echo "$line" | grep -q "^## .*Backlog"; then
            in_backlog=true
        elif echo "$line" | grep -q "^## " && [ "$in_backlog" = true ]; then
            in_backlog=false
        fi

        if [ "$in_backlog" = true ] && echo "$line" | grep -q "^- \[ \]" && [ "$removed" = false ]; then
            count=$((count + 1))
            if [ "$count" -eq "$task_num" ]; then
                removed=true
                continue
            fi
        fi

        echo "$line" >> "$tmpfile"
    done < "$TASKS_FILE"

    # Add to locked section
    local tmpfile2
    tmpfile2=$(mktemp)
    local added=false

    while IFS= read -r line; do
        echo "$line" >> "$tmpfile2"
        if echo "$line" | grep -q "^## .*Locked" && [ "$added" = false ]; then
            added=true
        elif [ "$added" = true ]; then
            if echo "$line" | grep -q "^<!--" || [ -z "$line" ]; then
                echo "$locked_line" >> "$tmpfile2"
                added=false
            fi
        fi
    done < "$tmpfile"

    mv "$tmpfile2" "$TASKS_FILE"
    rm -f "$tmpfile"

    echo -e "${GITCREW_YELLOW}Locked${GITCREW_NC} task #${task_num}: ${task_desc}"
    echo -e "  Assigned to: ${agent_name}"
}

complete_task() {
    ensure_tasks_file

    local task_num="${1:-}"
    shift || true
    local summary="$*"

    if [ -z "$task_num" ]; then
        echo -e "${GITCREW_RED}Error: Task number required.${GITCREW_NC}"
        echo "Usage: gitcrew task done <number> [summary]"
        exit 1
    fi

    # Get the nth locked task
    local task_line
    task_line=$(get_section "Locked" | grep "^- \[" | sed -n "${task_num}p" || true)

    if [ -z "$task_line" ]; then
        echo -e "${GITCREW_RED}Error: Locked task #${task_num} not found.${GITCREW_NC}"
        exit 1
    fi

    local task_desc
    task_desc=$(echo "$task_line" | sed 's/^- \[ \] //' | sed 's/ — locked by .*//')

    local done_line="- [x] ${task_desc}"
    if [ -n "$summary" ]; then
        done_line="${done_line} — ${summary}"
    fi
    done_line="${done_line} ($(date '+%Y-%m-%d'))"

    # Remove from locked section
    local tmpfile
    tmpfile=$(mktemp)
    local removed=false
    local count=0
    local in_locked=false

    while IFS= read -r line; do
        if echo "$line" | grep -q "^## .*Locked"; then
            in_locked=true
        elif echo "$line" | grep -q "^## " && [ "$in_locked" = true ]; then
            in_locked=false
        fi

        if [ "$in_locked" = true ] && echo "$line" | grep -q "^- \[" && [ "$removed" = false ]; then
            count=$((count + 1))
            if [ "$count" -eq "$task_num" ]; then
                removed=true
                continue
            fi
        fi

        echo "$line" >> "$tmpfile"
    done < "$TASKS_FILE"

    # Add to done section
    local tmpfile2
    tmpfile2=$(mktemp)
    local added=false

    while IFS= read -r line; do
        echo "$line" >> "$tmpfile2"
        if echo "$line" | grep -q "^## .*Done" && [ "$added" = false ]; then
            added=true
        elif [ "$added" = true ]; then
            if echo "$line" | grep -q "^<!--" || [ -z "$line" ]; then
                echo "$done_line" >> "$tmpfile2"
                added=false
            fi
        fi
    done < "$tmpfile"

    mv "$tmpfile2" "$TASKS_FILE"
    rm -f "$tmpfile"

    echo -e "${GITCREW_GREEN}Completed${GITCREW_NC} task: ${task_desc}"
}

unlock_task() {
    ensure_tasks_file

    local task_num="${1:-}"

    if [ -z "$task_num" ]; then
        echo -e "${GITCREW_RED}Error: Task number required.${GITCREW_NC}"
        echo "Usage: gitcrew task unlock <number>"
        exit 1
    fi

    local task_line
    task_line=$(get_section "Locked" | grep "^- \[" | sed -n "${task_num}p" || true)

    if [ -z "$task_line" ]; then
        echo -e "${GITCREW_RED}Error: Locked task #${task_num} not found.${GITCREW_NC}"
        exit 1
    fi

    local task_desc
    task_desc=$(echo "$task_line" | sed 's/^- \[ \] //' | sed 's/ — locked by .*//')

    # Remove from locked section
    local tmpfile
    tmpfile=$(mktemp)
    local removed=false
    local count=0
    local in_locked=false

    while IFS= read -r line; do
        if echo "$line" | grep -q "^## .*Locked"; then
            in_locked=true
        elif echo "$line" | grep -q "^## " && [ "$in_locked" = true ]; then
            in_locked=false
        fi

        if [ "$in_locked" = true ] && echo "$line" | grep -q "^- \[" && [ "$removed" = false ]; then
            count=$((count + 1))
            if [ "$count" -eq "$task_num" ]; then
                removed=true
                continue
            fi
        fi

        echo "$line" >> "$tmpfile"
    done < "$TASKS_FILE"

    # Add back to backlog
    local tmpfile2
    tmpfile2=$(mktemp)
    local added=false

    while IFS= read -r line; do
        echo "$line" >> "$tmpfile2"
        if echo "$line" | grep -q "^## .*Backlog" && [ "$added" = false ]; then
            added=true
        elif [ "$added" = true ]; then
            if echo "$line" | grep -q "^<!--" || [ -z "$line" ]; then
                echo "- [ ] ${task_desc}" >> "$tmpfile2"
                added=false
            fi
        fi
    done < "$tmpfile"

    mv "$tmpfile2" "$TASKS_FILE"
    rm -f "$tmpfile"

    echo -e "${GITCREW_BLUE}Unlocked${GITCREW_NC} task: ${task_desc} (moved back to backlog)"
}

import_tasks() {
    ensure_tasks_file

    local file="${1:-}"

    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo -e "${GITCREW_RED}Error: File '${file}' not found.${GITCREW_NC}"
        echo "Usage: gitcrew task import <file>"
        exit 1
    fi

    local count=0
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        [ -z "$line" ] && continue
        [ "${line:0:1}" = "#" ] && continue
        line=$(echo "$line" | sed 's/^- \[ \] //' | sed 's/^- //')
        add_task "$line"
        count=$((count + 1))
    done < "$file"

    echo ""
    echo -e "${GITCREW_GREEN}Imported ${count} task(s).${GITCREW_NC}"
}

clear_done() {
    ensure_tasks_file

    local archive_file="${AGENT_DIR}/TASKS-archive-$(date '+%Y%m%d').md"

    local done_tasks
    done_tasks=$(get_section "Done" | grep "^- \[x\]" || true)

    if [ -z "$done_tasks" ]; then
        echo "No completed tasks to archive."
        exit 0
    fi

    local count
    count=$(echo "$done_tasks" | wc -l | tr -d ' ')

    echo "# Archived Tasks — $(date '+%Y-%m-%d')" >> "$archive_file"
    echo "" >> "$archive_file"
    echo "$done_tasks" >> "$archive_file"

    # Remove done tasks from TASKS.md
    local tmpfile
    tmpfile=$(mktemp)
    local in_done=false

    while IFS= read -r line; do
        if echo "$line" | grep -q "^## .*Done"; then
            in_done=true
            echo "$line" >> "$tmpfile"
            continue
        fi

        if [ "$in_done" = true ] && echo "$line" | grep -q "^- \[x\]"; then
            continue
        fi

        echo "$line" >> "$tmpfile"
    done < "$TASKS_FILE"

    mv "$tmpfile" "$TASKS_FILE"

    echo -e "${GITCREW_GREEN}Archived ${count} completed task(s)${GITCREW_NC} to ${archive_file}"
}

# --- Main dispatch ---

SUBCMD="${1:-list}"

case "$SUBCMD" in
    list)       list_tasks ;;
    add)        shift; add_task "$@" ;;
    lock)       shift; lock_task "$@" ;;
    done)       shift; complete_task "$@" ;;
    unlock)     shift; unlock_task "$@" ;;
    import)     shift; import_tasks "$@" ;;
    clear-done) clear_done ;;
    -h|--help)  print_task_usage ;;
    *)
        echo -e "${GITCREW_RED}Error: Unknown subcommand '${SUBCMD}'${GITCREW_NC}"
        print_task_usage
        exit 1
        ;;
esac
