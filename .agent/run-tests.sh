#!/bin/bash
# .agent/run-tests.sh — test wrapper for the gitcrew project
#
# Usage:
#   .agent/run-tests.sh fast   — quick test run (before each commit)
#   .agent/run-tests.sh full   — full suite (before merge to main)

set -e
MODE=${1:-fast}

echo "[run-tests] mode=${MODE} started at $(date '+%H:%M:%S')"

# Run the gitcrew test suite (with optional timeout)
if command -v timeout &>/dev/null; then
    timeout 300 bash tests/runner.sh "$MODE" 2>&1 | tail -30
else
    bash tests/runner.sh "$MODE" 2>&1 | tail -30
fi

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
