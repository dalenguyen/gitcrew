#!/usr/bin/env bash
#
# gitcrew hooks — Install git hooks for agent safety
#

set -euo pipefail

AGENT_DIR=".agent"

print_hooks_usage() {
    echo -e "${GITCREW_BOLD}USAGE${GITCREW_NC}"
    echo "    gitcrew hooks [options]"
    echo ""
    echo -e "${GITCREW_BOLD}OPTIONS${GITCREW_NC}"
    echo "    --remove        Remove git hooks"
    echo "    -h, --help      Show this help"
    echo ""
    echo -e "${GITCREW_BOLD}DESCRIPTION${GITCREW_NC}"
    echo "    Installs a pre-push hook that runs tests before allowing pushes."
    echo "    This prevents agents from pushing broken code to the shared repo."
    echo ""
}

REMOVE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --remove)   REMOVE=true ;;
        -h|--help)  print_hooks_usage; exit 0 ;;
        *)
            echo -e "${GITCREW_RED}Error: Unknown option '$1'${GITCREW_NC}"
            print_hooks_usage
            exit 1
            ;;
    esac
    shift
done

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${GITCREW_RED}Error: Not a git repository.${GITCREW_NC}"
    exit 1
fi

HOOKS_DIR=".githooks"

if [ "$REMOVE" = true ]; then
    echo -e "${GITCREW_YELLOW}Removing git hooks...${GITCREW_NC}"
    git config --unset core.hooksPath 2>/dev/null || true
    echo -e "  ${GITCREW_GREEN}+${GITCREW_NC} Unset core.hooksPath"
    echo ""
    echo "Note: Hook files in .githooks/ were not deleted."
    echo "Remove them manually if desired: rm -rf .githooks/"
    exit 0
fi

# Create hooks directory
mkdir -p "$HOOKS_DIR"

# Copy pre-push hook
TEMPLATES_DIR="${GITCREW_DIR}/templates"
if [ -f "${TEMPLATES_DIR}/githooks/pre-push" ]; then
    cp "${TEMPLATES_DIR}/githooks/pre-push" "${HOOKS_DIR}/pre-push"
else
    # Inline fallback
    cat > "${HOOKS_DIR}/pre-push" << 'HOOKEOF'
#!/bin/bash
# Pre-push hook — blocks pushes if tests fail or branch is behind main
# Installed by gitcrew

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
    echo "[gitcrew] Checking if branch is up to date with main..."
    git fetch origin main --quiet 2>/dev/null || true
    if git rev-parse --verify origin/main &>/dev/null; then
        if ! git merge-base --is-ancestor origin/main HEAD; then
            echo ""
            echo "PUSH BLOCKED — Branch is behind main."
            echo "Run: git pull --rebase origin main"
            echo ""
            exit 1
        fi
        echo "[gitcrew] Branch is up to date with main."
    fi
fi

echo "[gitcrew] Running pre-push validation..."

if [ -f ".agent/run-tests.sh" ]; then
    bash .agent/run-tests.sh fast
    EXIT_CODE=$?
else
    echo "[gitcrew] Warning: .agent/run-tests.sh not found. Skipping test validation."
    exit 0
fi

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "PUSH BLOCKED — Tests are failing."
    echo "Fix the failing tests and try again."
    exit 1
fi

echo "[gitcrew] All tests passed. Pushing..."
HOOKEOF
fi

chmod +x "${HOOKS_DIR}/pre-push"

# Configure git to use our hooks
git config core.hooksPath "$HOOKS_DIR"

echo -e "${GITCREW_GREEN}Git hooks installed.${GITCREW_NC}"
echo ""
echo -e "  ${GITCREW_GREEN}+${GITCREW_NC} ${HOOKS_DIR}/pre-push"
echo -e "  ${GITCREW_GREEN}+${GITCREW_NC} core.hooksPath set to ${HOOKS_DIR}/"
echo ""
echo "Pushes will now be blocked if tests fail."
