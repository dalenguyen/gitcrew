#!/usr/bin/env bash
# Finish the "Fix: monitor --interval N" task (Agent-C).
# Run from repo root: bash .agent/finish-monitor-interval-fix.sh
# Deletes itself after step 7 so you don't run it twice.

set -e
cd "$(git rev-parse --show-toplevel)"

echo "1. Creating branch Agent-C/monitor-interval-fix..."
git checkout -b Agent-C/monitor-interval-fix 2>/dev/null || git checkout Agent-C/monitor-interval-fix

echo "2. Staging monitor fix and test..."
git add commands/monitor.sh tests/test_monitor.sh

echo "3. Running full test suite..."
bash tests/runner.sh full

echo "4. Committing..."
if git diff --cached --quiet; then
    echo "   (no changes to commit; already committed?)"
else
    git commit -m "fix: monitor --interval consumes argument"
fi

echo "5. Rebase on main and push..."
git pull --rebase origin main
git push origin Agent-C/monitor-interval-fix

echo "6. Running gitcrew pr flow..."
gitcrew pr flow

echo "7. Update TASKS.md and LOG.md (move task to Done, append log)."
echo "   Then delete this script: rm .agent/finish-monitor-interval-fix.sh"
