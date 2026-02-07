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
