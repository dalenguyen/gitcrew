#!/usr/bin/env bash
# Finish the "Chore: add missing test coverage for doctor" task (Agent-C).
# Run from repo root: bash .agent/finish-doctor-coverage.sh
# After PR is merged, move task to Done in TASKS.md and append LOG.md if not already done.

set -e
cd "$(git rev-parse --show-toplevel)"

echo "1. Creating branch Agent-C/doctor-test-coverage..."
git checkout -b Agent-C/doctor-test-coverage 2>/dev/null || git checkout Agent-C/doctor-test-coverage

echo "2. Staging doctor tests and task board updates..."
git add tests/test_doctor.sh .agent/TASKS.md .agent/LOG.md

echo "3. Running full test suite..."
bash tests/runner.sh full

echo "4. Committing..."
if git diff --cached --quiet; then
    echo "   (no changes to commit; already committed?)"
else
    git commit -m "test: doctor --help, unknown option, --fix coverage"
fi

echo "5. Rebase on main and push..."
git pull --rebase origin main
git push origin Agent-C/doctor-test-coverage

echo "6. Running gitcrew pr flow..."
gitcrew pr flow

echo "7. If TASKS.md was not updated by this run, move task to Done and append LOG.md, then commit and push main."