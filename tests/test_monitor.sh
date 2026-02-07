#!/usr/bin/env bash
# Tests for gitcrew monitor

test_monitor_once_shows_dashboard() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" monitor --once 2>&1)
    assert_contains "$output" "GITCREW AGENT MONITOR"
    assert_contains "$output" "Task Status"
    assert_contains "$output" "Recent Commits"

    teardown_sandbox "$sandbox"
}

test_monitor_shows_task_counts() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1
    "$GITCREW" task add "Test task 1" >/dev/null 2>&1
    "$GITCREW" task add "Test task 2" >/dev/null 2>&1

    local output
    output=$("$GITCREW" monitor --once 2>&1)
    assert_contains "$output" "Backlog: 2"

    teardown_sandbox "$sandbox"
}

test_monitor_fails_without_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local exit_code=0
    "$GITCREW" monitor --once >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_monitor_help_shows_usage() {
    local sandbox exit_code
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local output
    output=$("$GITCREW" monitor --help 2>&1)
    assert_contains "$output" "USAGE"
    assert_contains "$output" "OPTIONS"
    assert_contains "$output" "--help"
    assert_contains "$output" "--interval"
    assert_contains "$output" "--once"
    exit_code=0; "$GITCREW" monitor --help >/dev/null 2>&1 || exit_code=$?
    assert_eq "0" "$exit_code" "monitor --help should exit 0"
    exit_code=0; "$GITCREW" monitor -h >/dev/null 2>&1 || exit_code=$?
    assert_eq "0" "$exit_code" "monitor -h should exit 0"

    teardown_sandbox "$sandbox"
}

test_monitor_unknown_option_fails() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local output
    output=$("$GITCREW" monitor --unknown 2>&1)
    assert_contains "$output" "Unknown option"
    assert_contains "$output" "unknown"
    local exit_code=0
    "$GITCREW" monitor --unknown >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code" "monitor --unknown should exit 1"

    teardown_sandbox "$sandbox"
}

# --interval N must consume N so it is not treated as unknown option
test_monitor_interval_consumes_argument() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" monitor --interval 5 --once 2>&1)
    assert_contains "$output" "GITCREW AGENT MONITOR"
    assert_not_contains "$output" "Unknown option '5'"

    teardown_sandbox "$sandbox"
}

# Active Agent Branches lists only branches not merged into main (keeps list short)
test_monitor_active_branches_excludes_merged() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1
    git config user.email "test@test.com" >/dev/null 2>&1
    git config user.name "Test" >/dev/null 2>&1
    touch foo && git add foo && git commit -m "first" >/dev/null 2>&1

    git checkout -b Agent-C/merged-branch >/dev/null 2>&1
    touch bar && git add bar && git commit -m "merged" >/dev/null 2>&1
    git checkout main >/dev/null 2>&1
    git merge --no-edit Agent-C/merged-branch >/dev/null 2>&1

    git checkout -b Agent-D/unmerged-branch >/dev/null 2>&1
    touch baz && git add baz && git commit -m "unmerged" >/dev/null 2>&1

    local output
    output=$("$GITCREW" monitor --once 2>&1)
    assert_contains "$output" "Active Agent Branches"
    assert_contains "$output" "Agent-D/unmerged-branch"
    assert_not_contains "$output" "Agent-C/merged-branch"

    teardown_sandbox "$sandbox"
}

# Monitor shows only last few log lines and hints at full log (keeps dashboard scannable)
test_monitor_recent_log_limited_with_hint() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    # Build a log long enough that we would show only the tail
    local i
    for i in $(seq 1 20); do
        echo "Log line $i" >> "${sandbox}/.agent/LOG.md"
    done
    echo "EARLY_LINE_SHOULD_NOT_APPEAR" >> "${sandbox}/.agent/LOG.md"
    for i in $(seq 21 25); do
        echo "Log line $i" >> "${sandbox}/.agent/LOG.md"
    done

    local output
    output=$("$GITCREW" monitor --once 2>&1)
    assert_contains "$output" "Recent Agent Log"
    assert_contains "$output" "gitcrew log show"
    # Dashboard should not dump the full log (early line should be omitted)
    assert_not_contains "$output" "EARLY_LINE_SHOULD_NOT_APPEAR"

    teardown_sandbox "$sandbox"
}
