#!/usr/bin/env bash
#
# gitcrew spawn — Start an agent loop
#

set -euo pipefail

AGENT_DIR=".agent"

print_spawn_usage() {
    echo -e "${GITCREW_BOLD}USAGE${GITCREW_NC}"
    echo "    gitcrew spawn <agent-name> [role] [options]"
    echo ""
    echo -e "${GITCREW_BOLD}ARGUMENTS${GITCREW_NC}"
    echo "    agent-name      Name for this agent (e.g., Agent-A, Agent-B)"
    echo "    role            Role file from .agent/roles/ (default: feature)"
    echo "                    Options: feature, bugfix, quality, docs, integration"
    echo ""
    echo -e "${GITCREW_BOLD}OPTIONS${GITCREW_NC}"
    echo "    --cli <tool>    Agent CLI to use: claude, cursor, aider, codex (default: cursor, or last used)"
    echo "    --model <m>     Model to use (passed to claude/aider if supported)"
    echo "    --docker        Run agent in a Docker container"
    echo "    --no-lock-next  Do not assign the first backlog task (agent will pick from backlog when it runs)"
    echo "    --dry-run       Show what would run without executing"
    echo "    --once          Run a single session instead of looping"
    echo "    -h, --help      Show this help"
    echo ""
    echo "  By default, spawn assigns the first backlog task to this agent so it shows in progress immediately."
    echo ""
    echo -e "${GITCREW_BOLD}EXAMPLES${GITCREW_NC}"
    echo "    gitcrew spawn Agent-A feature"
    echo "    gitcrew spawn Agent-B bugfix --cli cursor"
    echo "    gitcrew spawn Agent-C quality --cli aider"
    echo "    gitcrew spawn Agent-D docs --docker"
    echo "    gitcrew spawn Agent-A feature --once --dry-run"
    echo "    gitcrew spawn Agent-B bugfix --no-lock-next   # agent picks a task when it runs"
    echo ""
}

# Defaults
AGENT_NAME=""
ROLE="feature"
CLI_TOOL="cursor"
CLI_EXPLICIT=false
MODEL="claude-opus-4-6-20250219"
USE_DOCKER=false
DRY_RUN=false
RUN_ONCE=false
# Default: assign first backlog task to this agent when spawning (use --no-lock-next to skip)
LOCK_NEXT=true

# Parse args
while [ $# -gt 0 ]; do
    case "$1" in
        --cli)         CLI_TOOL="$2"; CLI_EXPLICIT=true; shift ;;
        --model)       MODEL="$2"; shift ;;
        --docker)      USE_DOCKER=true ;;
        --no-lock-next) LOCK_NEXT=false ;;
        --dry-run)     DRY_RUN=true ;;
        --once)        RUN_ONCE=true ;;
        -h|--help)  print_spawn_usage; exit 0 ;;
        -*)
            gitcrew_error_unknown_option "$1"
            print_spawn_usage
            exit 1
            ;;
        *)
            if [ -z "$AGENT_NAME" ]; then
                AGENT_NAME="$1"
            else
                ROLE="$1"
            fi
            ;;
    esac
    shift
done

if [ -z "$AGENT_NAME" ]; then
    echo -e "${GITCREW_RED}Error: Agent name is required.${GITCREW_NC}"
    echo ""
    print_spawn_usage
    exit 1
fi

# --- Pre-flight checks ---

if [ ! -d "$AGENT_DIR" ]; then
    echo -e "${GITCREW_RED}Error: .agent/ directory not found.${GITCREW_NC}"
    echo "Run 'gitcrew init' first."
    exit 1
fi

# Use last-used CLI if no --cli was passed
if [ "$CLI_EXPLICIT" = false ] && [ -f "${AGENT_DIR}/agent.env" ]; then
    # shellcheck source=/dev/null
    source "${AGENT_DIR}/agent.env" 2>/dev/null || true
    case "${AGENT_CLI:-}" in
        claude|cursor|aider|codex) CLI_TOOL="$AGENT_CLI" ;;
    esac
fi

# Remember CLI for next time (when user passed --cli)
if [ "$CLI_EXPLICIT" = true ]; then
    echo "AGENT_CLI=${CLI_TOOL}" > "${AGENT_DIR}/agent.env"
fi

ROLE_FILE="${AGENT_DIR}/roles/${ROLE}.md"
if [ ! -f "$ROLE_FILE" ]; then
    echo -e "${GITCREW_YELLOW}Warning: Role file '${ROLE_FILE}' not found. Using base prompt only.${GITCREW_NC}"
    ROLE_FILE=""
fi

# --- Auto-assign first backlog task (default; skip with --no-lock-next) ---
LOCKED_THIS_SESSION=false
if [ "$LOCK_NEXT" = true ] && [ "$DRY_RUN" = false ]; then
    if "${GITCREW_DIR}/gitcrew" task lock 1 "$AGENT_NAME" 2>/dev/null; then
        echo -e "${GITCREW_GREEN}Assigned first backlog task to ${AGENT_NAME}.${GITCREW_NC}"
        LOCKED_THIS_SESSION=true
    else
        echo -e "${GITCREW_YELLOW}No backlog task. Agent will pick from the board when it runs.${GITCREW_NC}"
    fi
    echo ""
fi

# --- Docker spawn ---

if [ "$USE_DOCKER" = true ]; then
    if [ ! -f "${AGENT_DIR}/spawn-docker.sh" ]; then
        echo -e "${GITCREW_RED}Error: .agent/spawn-docker.sh not found.${GITCREW_NC}"
        exit 1
    fi

    echo -e "${GITCREW_CYAN}Spawning ${AGENT_NAME} in Docker container (role: ${ROLE})...${GITCREW_NC}"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${GITCREW_DIM}[dry-run] Would run: bash ${AGENT_DIR}/spawn-docker.sh ${AGENT_NAME} ${ROLE} --cli ${CLI_TOOL}${RUN_ONCE:+ --once}${GITCREW_NC}"
    else
        RUN_ARGS=("$AGENT_NAME" "$ROLE" --cli "$CLI_TOOL")
        [ -n "$MODEL" ] && RUN_ARGS+=(--model "$MODEL")
        [ "$RUN_ONCE" = true ] && RUN_ARGS+=(--once)
        bash "${AGENT_DIR}/spawn-docker.sh" "${RUN_ARGS[@]}"
    fi
    exit 0
fi

# --- Terminal spawn: run in per-agent Git worktree so main folder and main branch are untouched ---

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
WORKSPACE_DIR="${REPO_ROOT}/.agent/workspaces/${AGENT_NAME}"
WORKSPACE_BRANCH="${AGENT_NAME}/workspace"

create_or_sync_workspace() {
    if [ -d "$WORKSPACE_DIR" ]; then
        # If worktree is already on main (e.g. after PR merged and update_main_after_merge), remove it and recreate so we don't accumulate stale worktrees
        current_branch="$(cd "$WORKSPACE_DIR" && git branch --show-current 2>/dev/null)" || true
        if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
            if git -C "$REPO_ROOT" worktree remove "$WORKSPACE_DIR" 2>/dev/null || git -C "$REPO_ROOT" worktree remove --force "$WORKSPACE_DIR" 2>/dev/null; then
                git -C "$REPO_ROOT" branch -d "$WORKSPACE_BRANCH" 2>/dev/null || git -C "$REPO_ROOT" branch -D "$WORKSPACE_BRANCH" 2>/dev/null || true
                echo -e "${GITCREW_GREEN}Removed merged worktree for ${AGENT_NAME}; creating fresh.${GITCREW_NC}"
            fi
        fi
    fi
    if [ ! -d "$WORKSPACE_DIR" ]; then
        mkdir -p "$(dirname "$WORKSPACE_DIR")"
        # Use git worktree: one repo, shared objects, no duplicate clone. Branch per agent so main stays free.
        if git -C "$REPO_ROOT" worktree add -b "$WORKSPACE_BRANCH" "$WORKSPACE_DIR" origin/main 2>/dev/null; then
            :
        elif git -C "$REPO_ROOT" worktree add -b "$WORKSPACE_BRANCH" "$WORKSPACE_DIR" main 2>/dev/null; then
            :
        else
            echo -e "${GITCREW_RED}Error: Could not create git worktree for ${AGENT_NAME}. (Need 'main' or 'origin/main'.)${GITCREW_NC}"
            exit 1
        fi
        echo -e "${GITCREW_GREEN}Created worktree for ${AGENT_NAME} at .agent/workspaces/${AGENT_NAME}${GITCREW_NC}"
    else
        # Existing worktree: sync branch with main
        (cd "$WORKSPACE_DIR" && git fetch origin 2>/dev/null; git checkout "$WORKSPACE_BRANCH" 2>/dev/null; git merge origin/main 2>/dev/null || git merge main 2>/dev/null) || true
    fi
    # Sync task board and prompt from main repo so agent sees latest
    rsync -a --exclude=logs --exclude=workspaces "${REPO_ROOT}/.agent/" "${WORKSPACE_DIR}/.agent/" 2>/dev/null || {
        for f in TASKS.md LOG.md PROMPT.md agent.env; do
            [ -f "${REPO_ROOT}/.agent/$f" ] && cp "${REPO_ROOT}/.agent/$f" "${WORKSPACE_DIR}/.agent/$f" 2>/dev/null || true
        done
        [ -d "${REPO_ROOT}/.agent/roles" ] && cp -r "${REPO_ROOT}/.agent/roles" "${WORKSPACE_DIR}/.agent/" 2>/dev/null || true
    }
}

if [ "$DRY_RUN" = false ]; then
    create_or_sync_workspace
fi

echo -e "${GITCREW_CYAN}Starting ${AGENT_NAME} (role: ${ROLE}, cli: ${CLI_TOOL})...${GITCREW_NC}"
if [ "$DRY_RUN" = false ]; then
    echo -e "${GITCREW_DIM}For full automation (no human steps): allow your agent to run terminal commands (git, run-tests.sh, gitcrew).${GITCREW_NC}"
fi
if [ "$LOCK_NEXT" = false ] && [ "$DRY_RUN" = false ]; then
    echo -e "${GITCREW_DIM}No task pre-assigned. Agent will pick from the backlog when it runs.${GITCREW_NC}"
fi
echo ""

# Build prompt
PROMPT=$(cat "${AGENT_DIR}/PROMPT.md")
if [ -n "$ROLE_FILE" ] && [ -f "$ROLE_FILE" ]; then
    PROMPT="${PROMPT}

$(cat "$ROLE_FILE")"
fi

# Replace AGENT_NAME placeholder
PROMPT=$(echo "$PROMPT" | sed "s/AGENT_NAME/${AGENT_NAME}/g")

# If we assigned a task for this agent, tell them so they start working on it
if [ "$LOCKED_THIS_SESSION" = true ]; then
    PROMPT="${PROMPT}

---
**Assigned task:** A backlog task has been assigned to you. See the \"Locked (In Progress)\" section in \`.agent/TASKS.md\`. Do everything yourself in the terminal: create branch, implement, run tests, commit, push, then run \`gitcrew pr flow\`. No human steps."
fi

# Tell agent it runs in an isolated workspace so main folder and main branch stay untouched
if [ "$DRY_RUN" = false ] && [ -d "${WORKSPACE_DIR:-/nonexistent}" ]; then
    PROMPT="${PROMPT}

---
**Isolation:** You are running in your own Git worktree. The main repo folder and main branch are not touched. Work only in this directory. Never commit to main—use a feature branch and \`gitcrew pr flow\` to merge."
fi

mkdir -p "${AGENT_DIR}/logs"

run_session() {
    mkdir -p "${AGENT_DIR}/logs"
    local TIMESTAMP
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local COMMIT
    COMMIT=$(git rev-parse --short=6 HEAD 2>/dev/null || echo "000000")
    local LOGFILE="${AGENT_DIR}/logs/${AGENT_NAME}_${TIMESTAMP}_${COMMIT}.log"

    echo -e "[$(date)] ${GITCREW_GREEN}Starting session${GITCREW_NC} for ${AGENT_NAME} at ${COMMIT}"

    case "$CLI_TOOL" in
        claude)
            if [ "$DRY_RUN" = true ]; then
                echo -e "${GITCREW_DIM}[dry-run] claude --dangerously-skip-permissions -p \"<prompt>\" --model ${MODEL}${GITCREW_NC}"
            else
                claude --dangerously-skip-permissions \
                       -p "$PROMPT" \
                       --model "$MODEL" \
                       2>&1 | tee "$LOGFILE"
            fi
            ;;
        aider)
            if [ "$DRY_RUN" = true ]; then
                echo -e "${GITCREW_DIM}[dry-run] aider --message \"<prompt>\" --yes --auto-commits${GITCREW_NC}"
            else
                aider --message "$PROMPT" \
                      --yes --auto-commits \
                      2>&1 | tee "$LOGFILE"
            fi
            ;;
        cursor)
            if [ "$DRY_RUN" = true ]; then
                echo -e "${GITCREW_DIM}[dry-run] agent -p \"<prompt>\"${GITCREW_NC}"
            else
                agent -p "$PROMPT" \
                      2>&1 | tee "$LOGFILE"
            fi
            ;;
        codex)
            if [ "$DRY_RUN" = true ]; then
                echo -e "${GITCREW_DIM}[dry-run] codex --prompt \"<prompt>\"${GITCREW_NC}"
            else
                codex --prompt "$PROMPT" \
                      2>&1 | tee "$LOGFILE"
            fi
            ;;
        *)
            echo -e "${GITCREW_RED}Error: Unknown CLI tool '${CLI_TOOL}'${GITCREW_NC}"
            echo "Supported: claude, cursor, aider, codex"
            exit 1
            ;;
    esac

    # Pull latest between sessions
    git pull origin main --rebase 2>/dev/null || true
}

run_session_in_workspace() {
    if [ "$DRY_RUN" = false ] && [ -d "$WORKSPACE_DIR" ]; then
        (cd "$WORKSPACE_DIR" && run_session)
    else
        run_session
    fi
}

if [ "$RUN_ONCE" = true ]; then
    run_session_in_workspace
    echo -e "[$(date)] ${GITCREW_GREEN}Session complete.${GITCREW_NC}"
else
    while true; do
        run_session_in_workspace
        echo -e "[$(date)] ${GITCREW_YELLOW}Session complete. Restarting in 5s...${GITCREW_NC}"
        sleep 5
    done
fi
