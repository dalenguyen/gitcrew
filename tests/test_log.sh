#!/usr/bin/env bash
# Tests for gitcrew log

test_log_append() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks 2>&1 >/dev/null

    local output
    output=$("$GITCREW" log Agent-Test "Fixed the login bug" 2>&1)
    assert_contains "$output" "Logged by Agent-Test"

    # Check it was written to LOG.md
    local log_content
    log_content=$(cat .agent/LOG.md)
    assert_contains "$log_content" "Agent-Test"
    assert_contains "$log_content" "Fixed the login bug"

    teardown_sandbox "$sandbox"
}

test_log_show() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks 2>&1 >/dev/null
    "$GITCREW" log Agent-Test "Entry one" 2>&1 >/dev/null

    local output
    output=$("$GITCREW" log show 2>&1)
    assert_contains "$output" "Entry one"

    teardown_sandbox "$sandbox"
}

test_log_requires_message() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks 2>&1 >/dev/null

    local exit_code=0
    "$GITCREW" log Agent-Test 2>&1 >/dev/null || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_log_fails_without_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local exit_code=0
    "$GITCREW" log Agent-Test "hello" 2>&1 >/dev/null || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}
