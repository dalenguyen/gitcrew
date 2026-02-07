#!/usr/bin/env bash
#
# tests/test_worktree.sh — worktree list and cleanup
#

test_worktree_fails_without_repo() {
    local sandbox
    sandbox=$(mktemp -d)
    cd "$sandbox"
    local exit_code=0
    "$GITCREW" worktree list >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code" "worktree list should fail outside git repo"
    teardown_sandbox "$sandbox"
}

test_worktree_list_empty_after_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1
    local output
    output=$("$GITCREW" worktree list 2>&1)
    assert_contains "$output" "Agent worktrees"
    assert_contains "$output" "None"
    teardown_sandbox "$sandbox"
}

test_worktree_list_shows_agent_worktrees() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1
    "$GITCREW" task add "Fix: test" >/dev/null 2>&1
    # Start spawn in background to create worktree, then stop
    "$GITCREW" spawn Agent-WT feature --once >/dev/null 2>&1 &
    local pid=$!
    sleep 4
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    local output
    output=$("$GITCREW" worktree list 2>&1)
    assert_contains "$output" "Agent worktrees"
    assert_contains "$output" "workspaces/Agent-WT"
    teardown_sandbox "$sandbox"
}

test_worktree_cleanup_removes_agent_worktrees() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1
    "$GITCREW" task add "Fix: test" >/dev/null 2>&1
    "$GITCREW" spawn Agent-Clean feature --once >/dev/null 2>&1 &
    local pid=$!
    sleep 4
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    [ -d ".agent/workspaces/Agent-Clean" ] || { echo "precondition: worktree should exist"; return 1; }
    local output
    output=$("$GITCREW" worktree cleanup 2>&1)
    assert_contains "$output" "Removed"
    [ ! -d ".agent/workspaces/Agent-Clean" ] || { echo "worktree should be removed"; return 1; }
    output=$("$GITCREW" worktree list 2>&1)
    assert_contains "$output" "None"
    teardown_sandbox "$sandbox"
}

test_worktree_help_shows_usage() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1
    local output
    output=$("$GITCREW" worktree --help 2>&1)
    assert_contains "$output" "worktree"
    assert_contains "$output" "list"
    assert_contains "$output" "cleanup"
    teardown_sandbox "$sandbox"
}

test_worktree_unknown_subcommand_fails() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1
    local exit_code=0
    "$GITCREW" worktree invalid-cmd >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code" "worktree unknown subcommand should exit 1"
    teardown_sandbox "$sandbox"
}
