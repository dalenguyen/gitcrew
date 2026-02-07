#!/usr/bin/env bash
#
# gitcrew worktree — List or clean up agent worktrees
#

set -euo pipefail

AGENT_DIR=".agent"

print_worktree_usage() {
    echo -e "${GITCREW_BOLD}USAGE${GITCREW_NC}"
    echo "    gitcrew worktree <subcommand> [options]"
    echo ""
    echo -e "${GITCREW_BOLD}SUBCOMMANDS${GITCREW_NC}"
    echo -e "    ${GITCREW_GREEN}list${GITCREW_NC}    List agent worktrees under .agent/workspaces/"
    echo -e "    ${GITCREW_GREEN}cleanup${GITCREW_NC} Remove all agent worktrees (run from main repo; use after PR merged)"
    echo ""
    echo -e "${GITCREW_BOLD}EXAMPLES${GITCREW_NC}"
    echo "    gitcrew worktree list"
    echo "    gitcrew worktree cleanup   # Remove .agent/workspaces/* so main repo is clean"
    echo ""
}

# Resolve repo root (works from main repo or from inside a worktree)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
    echo -e "${GITCREW_RED}Error: Not in a git repository.${GITCREW_NC}"
    exit 1
fi
# Main repo root (where worktrees are registered); from a worktree, --git-common-dir points to main .git
MAIN_REPO="$REPO_ROOT"
if [ -f "$REPO_ROOT/.git" ]; then
    common_dir="$(git rev-parse --git-common-dir 2>/dev/null)"
    [ -n "$common_dir" ] && MAIN_REPO="$(cd "$REPO_ROOT" && cd "$common_dir" 2>/dev/null && pwd | sed 's|/.git$||')"
fi
[ -z "$MAIN_REPO" ] && MAIN_REPO="$REPO_ROOT"

cmd_list() {
    echo -e "${GITCREW_BOLD}Agent worktrees${GITCREW_NC}"
    echo ""
    local found=0
    while IFS= read -r line; do
        local path branch
        path=$(echo "$line" | awk '{print $1}')
        branch=$(echo "$line" | sed -n 's/.*\[\(.*\)\]$/\1/p')
        case "$path" in
            */.agent/workspaces/*)
                found=1
                echo -e "  ${path} ${GITCREW_DIM}[${branch}]${GITCREW_NC}"
                ;;
        esac
    done < <(git -C "$MAIN_REPO" worktree list 2>/dev/null)
    if [ "$found" = 0 ]; then
        echo -e "  ${GITCREW_DIM}None (no worktrees under .agent/workspaces/)${GITCREW_NC}"
    fi
}

cmd_cleanup() {
    # Remove all agent worktrees; avoid removing the worktree we're in
    local current_toplevel
    current_toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || true
    local removed=0
    while IFS= read -r line; do
        local path
        path=$(echo "$line" | awk '{print $1}')
        case "$path" in
            */.agent/workspaces/*)
                if [ -n "$current_toplevel" ] && [ "$(cd "$path" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" = "$current_toplevel" ]; then
                    echo -e "${GITCREW_YELLOW}Skipping ${path} (current worktree)${GITCREW_NC}"
                    continue
                fi
                if git -C "$MAIN_REPO" worktree remove "$path" 2>/dev/null; then
                    echo -e "${GITCREW_GREEN}Removed ${path}${GITCREW_NC}"
                    removed=$((removed + 1))
                elif git -C "$MAIN_REPO" worktree remove --force "$path" 2>/dev/null; then
                    echo -e "${GITCREW_GREEN}Removed ${path} (--force)${GITCREW_NC}"
                    removed=$((removed + 1))
                else
                    echo -e "${GITCREW_YELLOW}Could not remove ${path} (in use or locked?)${GITCREW_NC}"
                fi
                ;;
        esac
    done < <(git -C "$MAIN_REPO" worktree list 2>/dev/null)
    if [ "$removed" -eq 0 ]; then
        echo -e "${GITCREW_DIM}No agent worktrees to remove.${GITCREW_NC}"
    fi
}

# --- Main ---
SUBCMD="${1:-}"
case "$SUBCMD" in
    list)    cmd_list ;;
    cleanup) cmd_cleanup ;;
    -h|--help) print_worktree_usage; exit 0 ;;
    "")
        print_worktree_usage
        exit 0
        ;;
    *)
        echo -e "${GITCREW_RED}Error: Unknown subcommand '${SUBCMD}'. Use 'list' or 'cleanup'.${GITCREW_NC}"
        print_worktree_usage
        exit 1
        ;;
esac
