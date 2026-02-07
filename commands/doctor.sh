#!/usr/bin/env bash
#
# gitcrew doctor — Diagnose project readiness for agents
#

set -euo pipefail

AGENT_DIR=".agent"

print_doctor_usage() {
    echo -e "${GITCREW_BOLD}USAGE${GITCREW_NC}"
    echo "    gitcrew doctor [options]"
    echo ""
    echo -e "${GITCREW_BOLD}OPTIONS${GITCREW_NC}"
    echo "    --fix           Attempt to auto-fix common issues"
    echo "    -h, --help      Show this help"
    echo ""
}

AUTO_FIX=false

while [ $# -gt 0 ]; do
    case "$1" in
        --fix)      AUTO_FIX=true ;;
        -h|--help)  print_doctor_usage; exit 0 ;;
        *)
            gitcrew_error_unknown_option "$1"
            print_doctor_usage
            exit 1
            ;;
    esac
    shift
done

PASS=0
WARN=0
FAIL=0

check_pass() {
    echo -e "  ${GITCREW_GREEN}[PASS]${GITCREW_NC} $1"
    PASS=$((PASS + 1))
}

check_warn() {
    echo -e "  ${GITCREW_YELLOW}[WARN]${GITCREW_NC} $1"
    WARN=$((WARN + 1))
}

check_fail() {
    echo -e "  ${GITCREW_RED}[FAIL]${GITCREW_NC} $1"
    FAIL=$((FAIL + 1))
}

echo -e "${GITCREW_BOLD}Gitcrew Doctor — Checking project readiness${GITCREW_NC}"
echo ""

# --- Git repo ---
echo -e "${GITCREW_BOLD}Git Repository:${GITCREW_NC}"
if git rev-parse --is-inside-work-tree &>/dev/null; then
    check_pass "Inside a git repository"
else
    check_fail "Not a git repository (run 'git init')"
fi

if git remote -v 2>/dev/null | grep -q "origin"; then
    check_pass "Remote 'origin' configured"
else
    check_warn "No 'origin' remote configured (agents need a shared remote)"
fi

if git log -1 &>/dev/null; then
    check_pass "Repository has commits"
else
    check_warn "No commits yet (agents need at least one commit)"
fi
echo ""

# --- .agent/ directory ---
echo -e "${GITCREW_BOLD}Agent Infrastructure:${GITCREW_NC}"
if [ -d "$AGENT_DIR" ]; then
    check_pass ".agent/ directory exists"
else
    check_fail ".agent/ directory missing (run 'gitcrew init')"
    echo ""
    echo -e "  ${GITCREW_DIM}Run 'gitcrew init' to bootstrap the agent directory.${GITCREW_NC}"
    echo ""
    # Can't check more without .agent/
    echo -e "${GITCREW_BOLD}Summary:${GITCREW_NC} ${GITCREW_GREEN}${PASS} passed${GITCREW_NC}, ${GITCREW_YELLOW}${WARN} warnings${GITCREW_NC}, ${GITCREW_RED}${FAIL} failed${GITCREW_NC}"
    exit 1
fi

# Core files
for f in TASKS.md LOG.md PROMPT.md detect-project.sh run-tests.sh run-loop.sh; do
    if [ -f "${AGENT_DIR}/${f}" ]; then
        check_pass "${f}"
    else
        check_fail "${f} missing"
    fi
done

# Check scripts are executable
for f in detect-project.sh run-tests.sh run-loop.sh; do
    if [ -f "${AGENT_DIR}/${f}" ] && [ -x "${AGENT_DIR}/${f}" ]; then
        check_pass "${f} is executable"
    elif [ -f "${AGENT_DIR}/${f}" ]; then
        check_warn "${f} exists but is not executable"
        if [ "$AUTO_FIX" = true ]; then
            chmod +x "${AGENT_DIR}/${f}"
            echo -e "    ${GITCREW_GREEN}Fixed:${GITCREW_NC} Made ${f} executable"
        fi
    fi
done
echo ""

# --- Role files ---
echo -e "${GITCREW_BOLD}Agent Roles:${GITCREW_NC}"
if [ -d "${AGENT_DIR}/roles" ]; then
    local_role_count=$(find "${AGENT_DIR}/roles" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$local_role_count" -gt 0 ]; then
        check_pass "${local_role_count} role file(s) found"
        find "${AGENT_DIR}/roles" -name "*.md" 2>/dev/null | while IFS= read -r rf; do
            echo -e "    ${GITCREW_DIM}$(basename "$rf" .md)${GITCREW_NC}"
        done
    else
        check_warn "No role files in .agent/roles/"
    fi
else
    check_warn ".agent/roles/ directory missing"
fi
echo ""

# --- Task board ---
echo -e "${GITCREW_BOLD}Task Board:${GITCREW_NC}"
if [ -f "${AGENT_DIR}/TASKS.md" ]; then
    local backlog_count=0
    local _in_backlog=false
    while IFS= read -r _line; do
        if echo "$_line" | grep -q "^## .*Backlog"; then _in_backlog=true
        elif echo "$_line" | grep -q "^## "; then _in_backlog=false
        elif [ "$_in_backlog" = true ] && echo "$_line" | grep -q "^- \[ \]"; then
            backlog_count=$((backlog_count + 1))
        fi
    done < "${AGENT_DIR}/TASKS.md"
    if [ "$backlog_count" -gt 0 ]; then
        check_pass "${backlog_count} task(s) in backlog"
    else
        check_warn "No tasks in backlog (use 'gitcrew task add' to seed tasks)"
    fi
fi
echo ""

# --- Test infrastructure ---
echo -e "${GITCREW_BOLD}Test Infrastructure:${GITCREW_NC}"
if [ -f "${AGENT_DIR}/run-tests.sh" ]; then
    # Check if the test script has been customized (not just the template)
    if grep -q "# TODO: Replace" "${AGENT_DIR}/run-tests.sh" 2>/dev/null; then
        check_warn "run-tests.sh appears uncustomized — edit it for your project"
    else
        check_pass "run-tests.sh configured"
    fi
fi

# Check for common test frameworks
if [ -f "package.json" ]; then
    if grep -q "\"test\"" "package.json" 2>/dev/null; then
        check_pass "npm test script found"
    else
        check_warn "package.json exists but no 'test' script defined"
    fi
fi

if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    if command -v pytest &>/dev/null; then
        check_pass "pytest available"
    else
        check_warn "Python project detected but pytest not found in PATH"
    fi
fi

if [ -f "Cargo.toml" ]; then
    if command -v cargo &>/dev/null; then
        check_pass "cargo available for Rust tests"
    else
        check_warn "Cargo.toml found but cargo not in PATH"
    fi
fi

if [ -f "go.mod" ]; then
    if command -v go &>/dev/null; then
        check_pass "go available for Go tests"
    else
        check_warn "go.mod found but go not in PATH"
    fi
fi
echo ""

# --- Git hooks ---
echo -e "${GITCREW_BOLD}Git Hooks:${GITCREW_NC}"
HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || echo "")
if [ -n "$HOOKS_PATH" ] && [ -f "${HOOKS_PATH}/pre-push" ]; then
    check_pass "pre-push hook installed (${HOOKS_PATH}/pre-push)"
elif [ -f ".githooks/pre-push" ]; then
    if [ "$HOOKS_PATH" = ".githooks" ]; then
        check_pass "pre-push hook installed"
    else
        check_warn ".githooks/pre-push exists but hooks path not configured"
        if [ "$AUTO_FIX" = true ]; then
            git config core.hooksPath .githooks
            echo -e "    ${GITCREW_GREEN}Fixed:${GITCREW_NC} Set core.hooksPath to .githooks"
        fi
    fi
else
    check_warn "No pre-push hook (run 'gitcrew hooks' to install)"
fi
echo ""

# --- Agent CLI tools ---
echo -e "${GITCREW_BOLD}Agent CLI Tools:${GITCREW_NC}"
# Check cursor's 'agent' CLI separately (different binary name)
if command -v agent &>/dev/null; then
    check_pass "cursor (agent) CLI available"
else
    check_warn "cursor (agent) CLI not found in PATH"
fi
for tool in claude aider codex; do
    if command -v "$tool" &>/dev/null; then
        check_pass "${tool} CLI available"
    else
        check_warn "${tool} CLI not found in PATH"
    fi
done
echo ""

# --- Summary ---
echo -e "${GITCREW_BOLD}Summary:${GITCREW_NC} ${GITCREW_GREEN}${PASS} passed${GITCREW_NC}, ${GITCREW_YELLOW}${WARN} warnings${GITCREW_NC}, ${GITCREW_RED}${FAIL} failed${GITCREW_NC}"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo -e "Fix the failures above before spawning agents."
    exit 1
elif [ "$WARN" -gt 2 ]; then
    echo ""
    echo -e "Several warnings — review them to ensure agents run smoothly."
fi
