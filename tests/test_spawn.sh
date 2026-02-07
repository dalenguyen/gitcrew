#!/usr/bin/env bash
# Tests for gitcrew spawn

test_spawn_requires_agent_name() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    local exit_code=0
    "$GITCREW" spawn >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_spawn_fails_without_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local exit_code=0
    "$GITCREW" spawn Agent-A feature --dry-run --once >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_spawn_dry_run_shows_command() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" spawn Agent-A feature --dry-run --once 2>&1)
    assert_contains "$output" "dry-run"
    assert_contains "$output" "cursor"

    teardown_sandbox "$sandbox"
}

test_spawn_dry_run_cursor() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" spawn Agent-B bugfix --cli cursor --dry-run --once 2>&1)
    assert_contains "$output" "agent -p"

    teardown_sandbox "$sandbox"
}

test_spawn_dry_run_aider() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" spawn Agent-B bugfix --cli aider --dry-run --once 2>&1)
    assert_contains "$output" "aider"

    teardown_sandbox "$sandbox"
}

test_spawn_warns_on_missing_role() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-roles --no-docker --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" spawn Agent-A norole --dry-run --once 2>&1)
    assert_contains "$output" "Warning"

    teardown_sandbox "$sandbox"
}

test_spawn_creates_logs_directory() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    "$GITCREW" spawn Agent-A feature --dry-run --once >/dev/null 2>&1

    assert_dir_exists ".agent/logs"

    teardown_sandbox "$sandbox"
}

test_spawn_docker_dry_run_passes_once_and_cli() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-hooks >/dev/null 2>&1

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

test_spawn_remembers_last_cli() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    # First spawn with --cli aider; should write .agent/agent.env
    "$GITCREW" spawn Agent-A feature --cli aider --dry-run --once >/dev/null 2>&1
    assert_file_exists ".agent/agent.env"
    assert_contains "$(cat .agent/agent.env)" "aider"

    # Second spawn without --cli should use aider (last used)
    local output
    output=$("$GITCREW" spawn Agent-B feature --dry-run --once 2>&1)
    assert_contains "$output" "aider"

    teardown_sandbox "$sandbox"
}

test_spawn_help_shows_no_lock_next() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" spawn --help 2>&1)
    assert_contains "$output" "no-lock-next"
    assert_contains "$output" "assigns the first backlog task"

    teardown_sandbox "$sandbox"
}

# Help and unknown option coverage (match doctor pattern)
test_spawn_help_shows_usage() {
    local sandbox exit_code
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" spawn --help 2>&1)
    assert_contains "$output" "USAGE"
    assert_contains "$output" "OPTIONS"
    assert_contains "$output" "--help"
    exit_code=0; "$GITCREW" spawn --help >/dev/null 2>&1 || exit_code=$?
    assert_eq "0" "$exit_code" "spawn --help should exit 0"
    exit_code=0; "$GITCREW" spawn -h >/dev/null 2>&1 || exit_code=$?
    assert_eq "0" "$exit_code" "spawn -h should exit 0"

    teardown_sandbox "$sandbox"
}

test_spawn_unknown_option_fails() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" spawn --unknown 2>&1)
    assert_contains "$output" "Unknown option"
    assert_contains "$output" "unknown"
    local exit_code=0
    "$GITCREW" spawn --unknown >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code" "spawn --unknown should exit 1"

    teardown_sandbox "$sandbox"
}

test_spawn_auto_assigns_by_default() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1
    "$GITCREW" task add "Fix: test bug" >/dev/null 2>&1

    # Default: spawn assigns first task, then starts agent; run in background and stop after 3s
    local outfile="${sandbox}/spawn_out"
    "$GITCREW" spawn Agent-B bugfix --once > "$outfile" 2>&1 &
    local pid=$!
    sleep 3
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    local output
    output=$(cat "$outfile")
    assert_contains "$output" "Assigned first backlog task"
    output=$("$GITCREW" status 2>&1)
    assert_contains "$output" "in progress"

    teardown_sandbox "$sandbox"
}

test_spawn_no_lock_next_skips_assign() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1
    "$GITCREW" task add "Fix: test bug" >/dev/null 2>&1

    # With --no-lock-next, we should not assign; dry-run so we don't start the agent
    local output
    output=$("$GITCREW" spawn Agent-B bugfix --no-lock-next --dry-run --once 2>&1)
    assert_contains "$output" "No task pre-assigned"
    # Task should still be in backlog (we didn't lock)
    output=$("$GITCREW" status 2>&1)
    assert_contains "$output" "backlog"

    teardown_sandbox "$sandbox"
}
