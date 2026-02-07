#!/usr/bin/env bash
# Tests for gitcrew task

_setup_with_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1
    echo "$sandbox"
}

test_task_list_empty() {
    local sandbox
    sandbox=$(_setup_with_init)
    cd "$sandbox"

    local output
    output=$("$GITCREW" task list 2>&1)
    assert_contains "$output" "Backlog"
    assert_contains "$output" "none"

    teardown_sandbox "$sandbox"
}

test_task_add() {
    local sandbox
    sandbox=$(_setup_with_init)
    cd "$sandbox"

    local output
    output=$("$GITCREW" task add "Fix: login bug" 2>&1)
    assert_contains "$output" "Added task"
    assert_contains "$output" "Fix: login bug"

    teardown_sandbox "$sandbox"
}

test_task_add_shows_in_list() {
    local sandbox
    sandbox=$(_setup_with_init)
    cd "$sandbox"

    "$GITCREW" task add "Fix: login bug" >/dev/null 2>&1
    "$GITCREW" task add "Feature: export CSV" >/dev/null 2>&1

    local output
    output=$("$GITCREW" task list 2>&1)
    assert_contains "$output" "Fix: login bug"
    assert_contains "$output" "Feature: export CSV"

    teardown_sandbox "$sandbox"
}

test_task_lock() {
    local sandbox
    sandbox=$(_setup_with_init)
    cd "$sandbox"

    "$GITCREW" task add "Fix: login bug" >/dev/null 2>&1

    local output
    output=$("$GITCREW" task lock 1 Agent-Test 2>&1)
    assert_contains "$output" "Locked"
    assert_contains "$output" "Agent-Test"

    # Should appear in locked section now
    local list_output
    list_output=$("$GITCREW" task list 2>&1)
    assert_contains "$list_output" "login bug"
    assert_contains "$list_output" "Agent-Test"

    teardown_sandbox "$sandbox"
}

test_task_lock_removes_from_backlog() {
    local sandbox
    sandbox=$(_setup_with_init)
    cd "$sandbox"

    "$GITCREW" task add "Fix: login bug" >/dev/null 2>&1
    "$GITCREW" task add "Feature: export CSV" >/dev/null 2>&1
    "$GITCREW" task lock 1 Agent-Test >/dev/null 2>&1

    # Backlog should still have 1 item
    local output
    output=$("$GITCREW" task list 2>&1)
    assert_contains "$output" "#1"

    teardown_sandbox "$sandbox"
}

test_task_done() {
    local sandbox
    sandbox=$(_setup_with_init)
    cd "$sandbox"

    "$GITCREW" task add "Fix: login bug" >/dev/null 2>&1
    "$GITCREW" task lock 1 Agent-Test >/dev/null 2>&1

    local output
    output=$("$GITCREW" task done 1 "Fixed with token refresh" 2>&1)
    assert_contains "$output" "Completed"

    local list_output
    list_output=$("$GITCREW" task list 2>&1)
    assert_contains "$list_output" "1 task(s) completed"

    teardown_sandbox "$sandbox"
}

test_task_unlock() {
    local sandbox
    sandbox=$(_setup_with_init)
    cd "$sandbox"

    "$GITCREW" task add "Fix: login bug" >/dev/null 2>&1
    "$GITCREW" task lock 1 Agent-Test >/dev/null 2>&1

    local output
    output=$("$GITCREW" task unlock 1 2>&1)
    assert_contains "$output" "Unlocked"
    assert_contains "$output" "backlog"

    teardown_sandbox "$sandbox"
}

test_task_add_requires_description() {
    local sandbox
    sandbox=$(_setup_with_init)
    cd "$sandbox"

    local exit_code=0
    "$GITCREW" task add >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_task_lock_invalid_number_fails() {
    local sandbox
    sandbox=$(_setup_with_init)
    cd "$sandbox"

    local exit_code=0
    "$GITCREW" task lock 99 Agent-Test >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_task_fails_without_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local exit_code=0
    "$GITCREW" task list >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_task_import() {
    local sandbox
    sandbox=$(_setup_with_init)
    cd "$sandbox"

    cat > tasks.txt << 'EOF'
Fix: authentication timeout
Feature: dark mode toggle
Chore: update dependencies
EOF

    "$GITCREW" task import tasks.txt >/dev/null 2>&1

    local output
    output=$("$GITCREW" task list 2>&1)
    assert_contains "$output" "authentication timeout"
    assert_contains "$output" "dark mode toggle"
    assert_contains "$output" "update dependencies"

    teardown_sandbox "$sandbox"
}
