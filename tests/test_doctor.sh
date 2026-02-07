#!/usr/bin/env bash
# Tests for gitcrew doctor

test_doctor_passes_after_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks 2>&1 >/dev/null

    local output
    output=$("$GITCREW" doctor 2>&1)
    assert_contains "$output" "PASS"
    assert_contains "$output" "0 failed"

    teardown_sandbox "$sandbox"
}

test_doctor_fails_without_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local exit_code=0
    "$GITCREW" doctor 2>&1 >/dev/null || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_doctor_detects_missing_files() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks 2>&1 >/dev/null
    rm .agent/PROMPT.md

    local output
    output=$("$GITCREW" doctor 2>&1)
    assert_contains "$output" "FAIL"
    assert_contains "$output" "PROMPT.md"

    teardown_sandbox "$sandbox"
}

test_doctor_detects_tasks_in_backlog() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks 2>&1 >/dev/null
    "$GITCREW" task add "Test task" 2>&1 >/dev/null

    local output
    output=$("$GITCREW" doctor 2>&1)
    assert_contains "$output" "1 task(s) in backlog"

    teardown_sandbox "$sandbox"
}
