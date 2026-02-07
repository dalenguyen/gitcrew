#!/bin/bash
# .agent/run-tests.sh — agent-friendly test wrapper
#
# Detects your stack and runs tests with minimal, greppable output.
# The SUMMARY line at the end is what agents look for.
#
# Usage:
#   .agent/run-tests.sh fast   — quick subset (before each commit)
#   .agent/run-tests.sh full   — everything (before merge to main)

set -e
MODE=${1:-fast}  # "fast" (subset) or "full" (everything)

echo "[run-tests] mode=${MODE} started at $(date '+%H:%M:%S')"

# --- Detect and run tests ---

if [ -f "package.json" ]; then
    # Node.js / JavaScript / TypeScript
    if [ "$MODE" = "fast" ]; then
        timeout 300 npm test -- --watchAll=false --bail 2>&1 | tail -20
    else
        timeout 600 npm test -- --watchAll=false 2>&1 | tail -20
        if grep -q "\"lint\"" package.json 2>/dev/null; then
            echo ""
            echo "[run-tests] Running linter..."
            npm run lint 2>&1 | tail -10
        fi
    fi

elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    # Python
    if [ "$MODE" = "fast" ]; then
        timeout 300 python -m pytest -x -q --tb=line 2>&1 | tail -20
    else
        timeout 600 python -m pytest -q --tb=line 2>&1 | tail -20
        # Linting
        if command -v ruff &>/dev/null; then
            echo ""
            echo "[run-tests] Running ruff..."
            ruff check . 2>&1 | tail -10
        elif command -v flake8 &>/dev/null; then
            echo ""
            echo "[run-tests] Running flake8..."
            flake8 . 2>&1 | tail -10
        fi
        # Type checking
        if command -v mypy &>/dev/null; then
            echo ""
            echo "[run-tests] Running mypy..."
            mypy . 2>&1 | tail -10
        fi
    fi

elif [ -f "Cargo.toml" ]; then
    # Rust
    if [ "$MODE" = "fast" ]; then
        timeout 300 cargo test --quiet 2>&1 | tail -20
    else
        timeout 600 cargo test --quiet 2>&1 | tail -20
        echo ""
        echo "[run-tests] Running clippy..."
        cargo clippy --quiet 2>&1 | tail -10
    fi

elif [ -f "go.mod" ]; then
    # Go
    if [ "$MODE" = "fast" ]; then
        timeout 300 go test ./... -count=1 -short 2>&1 | tail -20
    else
        timeout 600 go test ./... -count=1 -v 2>&1 | grep -E "FAIL|PASS|ok" | tail -30
        if command -v golangci-lint &>/dev/null; then
            echo ""
            echo "[run-tests] Running golangci-lint..."
            golangci-lint run 2>&1 | tail -10
        fi
    fi

elif [ -f "Gemfile" ]; then
    # Ruby
    if [ "$MODE" = "fast" ]; then
        timeout 300 bundle exec rake test 2>&1 | tail -20
    else
        timeout 600 bundle exec rake test 2>&1 | tail -20
        if command -v rubocop &>/dev/null; then
            echo ""
            echo "[run-tests] Running rubocop..."
            rubocop 2>&1 | tail -10
        fi
    fi

elif [ -f "Makefile" ]; then
    # Generic Makefile
    timeout 300 make test 2>&1 | tail -30

else
    echo "ERROR: No recognized test framework found"
    echo "Edit .agent/run-tests.sh with your project's test commands."
    exit 1
fi

# --- Summary line (agents look for this) ---
EXIT_CODE=${PIPESTATUS[0]:-$?}
echo ""
if [ $EXIT_CODE -eq 124 ]; then
    echo "SUMMARY: TESTS TIMED OUT"
    exit 1
elif [ $EXIT_CODE -eq 0 ]; then
    echo "SUMMARY: ALL TESTS PASSED"
else
    echo "SUMMARY: TESTS FAILED (exit code $EXIT_CODE)"
fi
exit $EXIT_CODE
