#!/usr/bin/env bash
# Tests for gitcrew spawn

test_spawn_requires_agent_name() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks 2>&1 >/dev/null

    local exit_code=0
    "$GITCREW" spawn 2>&1 >/dev/null || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_spawn_fails_without_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local exit_code=0
    "$GITCREW" spawn Agent-A feature --dry-run --once 2>&1 >/dev/null || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_spawn_dry_run_shows_command() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks 2>&1 >/dev/null

    local output
    output=$("$GITCREW" spawn Agent-A feature --dry-run --once 2>&1)
    assert_contains "$output" "dry-run"
    assert_contains "$output" "claude"

    teardown_sandbox "$sandbox"
}

test_spawn_dry_run_cursor() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks 2>&1 >/dev/null

    local output
    output=$("$GITCREW" spawn Agent-B bugfix --cli cursor --dry-run --once 2>&1)
    assert_contains "$output" "agent -p"

    teardown_sandbox "$sandbox"
}

test_spawn_dry_run_aider() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks 2>&1 >/dev/null

    local output
    output=$("$GITCREW" spawn Agent-B bugfix --cli aider --dry-run --once 2>&1)
    assert_contains "$output" "aider"

    teardown_sandbox "$sandbox"
}

test_spawn_warns_on_missing_role() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-roles --no-docker --no-hooks 2>&1 >/dev/null

    local output
    output=$("$GITCREW" spawn Agent-A norole --dry-run --once 2>&1)
    assert_contains "$output" "Warning"

    teardown_sandbox "$sandbox"
}

test_spawn_creates_logs_directory() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks 2>&1 >/dev/null

    "$GITCREW" spawn Agent-A feature --dry-run --once 2>&1 >/dev/null

    assert_dir_exists ".agent/logs"

    teardown_sandbox "$sandbox"
}

test_spawn_docker_dry_run_passes_once_and_cli() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-hooks 2>&1 >/dev/null

    # With --docker --dry-run, should show spawn-docker.sh with --once and --cli
    local output
    output=$("$GITCREW" spawn Agent-A feature --docker --dry-run --once 2>&1)
    assert_contains "$output" "spawn-docker.sh"
    assert_contains "$output" "--once"
    assert_contains "$output" "Agent-A"
    assert_contains "$output" "feature"

    # --cli should be passed too
    output=$("$GITCREW" spawn Agent-B bugfix --docker --dry-run --cli cursor 2>&1)
    assert_contains "$output" "spawn-docker.sh"
    assert_contains "$output" "cursor"

    teardown_sandbox "$sandbox"
}
