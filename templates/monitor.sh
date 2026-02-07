#!/bin/bash
# .agent/monitor.sh — standalone agent team monitor
#
# Run in a separate terminal to watch agent activity:
#   bash .agent/monitor.sh
#
# Or use: gitcrew monitor

INTERVAL=${1:-15}

watch -n "$INTERVAL" '
echo "=========================================="
echo "  GITCREW AGENT MONITOR — $(date)"
echo "=========================================="
echo ""

echo "--- Task Status ---"
LOCKED=$(awk "/^## .* Locked/,/^## [^L]/" .agent/TASKS.md 2>/dev/null | grep -c "^- \[" || echo 0)
BACKLOG=$(awk "/^## .* Backlog/,/^## [^B]/" .agent/TASKS.md 2>/dev/null | grep -c "^- \[ \]" || echo 0)
DONE=$(awk "/^## .* Done/,/^## |$/" .agent/TASKS.md 2>/dev/null | grep -c "^- \[x\]" || echo 0)
echo "  In Progress: $LOCKED  |  Backlog: $BACKLOG  |  Done: $DONE"
echo ""

echo "--- Active Agent Branches ---"
git for-each-ref --sort=-committerdate refs/heads refs/remotes/origin --format='%(refname:short)' 2>/dev/null | grep -i "agent" | while read b; do
    LAST=$(git log -1 --format="%ar — %s" "$b" 2>/dev/null)
    echo "  $b ($LAST)"
done
echo ""

echo "--- Recent Commits (all branches) ---"
git log --oneline --all -10 2>/dev/null || echo "  (no commits)"
echo ""

echo "--- Recent Agent Log ---"
tail -15 .agent/LOG.md 2>/dev/null || echo "  (no log entries)"
'
