#!/usr/bin/env bash
#
# tests/runner.sh — minimal bash test runner for gitcrew
#
# Zero dependencies. Runs each test_*.sh file, tallies pass/fail,
# prints a SUMMARY line that agents and CI can grep.
#
# Usage:
#   bash tests/runner.sh          # run all tests
#   bash tests/runner.sh fast     # run only fast tests (skip slow)
#

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
MODE="${1:-full}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
DIM='\033[2m'
NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0
FAILURES=""

# --- Test helpers (exported for test files) ---

# GITCREW path — available to all tests
export GITCREW="${REPO_ROOT}/gitcrew"

# Sandbox: creates a temp git repo and prints its path.
# IMPORTANT: caller must `cd "$sandbox"` after calling this.
setup_sandbox() {
    local sandbox
    sandbox=$(mktemp -d)
    git -C "$sandbox" init --quiet
    git -C "$sandbox" config user.name "Test"
    git -C "$sandbox" config user.email "test@gitcrew.local"
    git -C "$sandbox" commit --allow-empty -m "init" --quiet
    echo "$sandbox"
}

# Cleanup: removes the sandbox directory
teardown_sandbox() {
    local sandbox="$1"
    cd "$REPO_ROOT"
    rm -rf "$sandbox"
}

# Assert: check condition
assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-expected '$expected', got '$actual'}"
    if [ "$expected" = "$actual" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $msg"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-output should contain '$needle'}"
    if echo "$haystack" | grep -q "$needle"; then
        return 0
    else
        echo "  ASSERT FAILED: $msg"
        echo "    looking for: $needle"
        echo "    in output:   $(echo "$haystack" | head -5)"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local msg="${2:-file '$file' should exist}"
    if [ -f "$file" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $msg"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local msg="${2:-directory '$dir' should exist}"
    if [ -d "$dir" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $msg"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-exit code should be $expected, got $actual}"
    if [ "$expected" -eq "$actual" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $msg"
        return 1
    fi
}

# Export helpers so test files can use them
export -f setup_sandbox teardown_sandbox assert_eq assert_contains \
          assert_file_exists assert_dir_exists assert_exit_code 2>/dev/null || true
export REPO_ROOT

# --- Run tests ---

echo ""
echo "gitcrew test suite"
echo "=================="
echo "mode: ${MODE}"
echo ""

for test_file in "$TESTS_DIR"/test_*.sh; do
    [ -f "$test_file" ] || continue

    test_name=$(basename "$test_file" .sh)

    # Skip slow tests in fast mode
    if [ "$MODE" = "fast" ] && head -5 "$test_file" | grep -q "# SLOW"; then
        echo -e "${YELLOW}SKIP${NC}  ${test_name} (slow test, use 'full' mode)"
        continue
    fi

    # Source the test file and run all functions starting with "test_"
    # Each test file defines functions like test_init_creates_agent_dir()
    source "$test_file"

    # Find all test_ functions defined in the file
    test_functions=$(declare -F | awk '{print $3}' | grep "^test_" || true)

    for func in $test_functions; do
        TOTAL=$((TOTAL + 1))
        label="${test_name}::${func}"

        if output=$($func 2>&1); then
            echo -e "${GREEN}PASS${NC}  ${label}"
            PASSED=$((PASSED + 1))
        else
            echo -e "${RED}FAIL${NC}  ${label}"
            if [ -n "$output" ]; then
                echo "$output" | head -10 | while IFS= read -r line; do
                    echo -e "       ${DIM}${line}${NC}"
                done
            fi
            FAILED=$((FAILED + 1))
            FAILURES="${FAILURES}\n  - ${label}"
        fi

        # Unset the function to avoid re-running across files
        unset -f "$func"
    done
done

# --- Summary ---

echo ""
echo "------------------"
echo -e "Total: ${TOTAL}  ${GREEN}Passed: ${PASSED}${NC}  ${RED}Failed: ${FAILED}${NC}"

if [ "$FAILED" -gt 0 ]; then
    echo -e "\nFailed tests:${FAILURES}"
    echo ""
    echo "SUMMARY: TESTS FAILED (${FAILED}/${TOTAL})"
    exit 1
else
    echo ""
    echo "SUMMARY: ALL TESTS PASSED (${PASSED}/${TOTAL})"
    exit 0
fi
