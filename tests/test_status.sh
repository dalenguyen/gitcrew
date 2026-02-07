#!/usr/bin/env bash
# Tests for gitcrew status

test_status_shows_overview() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" status 2>&1)
    assert_contains "$output" "gitcrew status"
    assert_contains "$output" "Tasks:"
    assert_contains "$output" "Last commit:"
    assert_contains "$output" "Working tree:"

    teardown_sandbox "$sandbox"
}

test_status_shows_task_counts() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1
    "$GITCREW" task add "Task one" >/dev/null 2>&1
    "$GITCREW" task add "Task two" >/dev/null 2>&1

    local output
    output=$("$GITCREW" status 2>&1)
    assert_contains "$output" "2 backlog"

    teardown_sandbox "$sandbox"
}

test_status_fails_without_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local exit_code=0
    "$GITCREW" status >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}
