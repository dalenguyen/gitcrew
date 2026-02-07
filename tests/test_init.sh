#!/usr/bin/env bash
# Tests for gitcrew init

test_init_creates_agent_directory() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init >/dev/null 2>&1
    assert_dir_exists ".agent"

    teardown_sandbox "$sandbox"
}

test_init_creates_core_files() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init >/dev/null 2>&1

    assert_file_exists ".agent/TASKS.md"
    assert_file_exists ".agent/LOG.md"
    assert_file_exists ".agent/PROMPT.md"
    assert_file_exists ".agent/detect-project.sh"
    assert_file_exists ".agent/run-tests.sh"
    assert_file_exists ".agent/run-loop.sh"
    assert_file_exists ".agent/monitor.sh"

    teardown_sandbox "$sandbox"
}

# Regression: assert_not_contains helper works; init success has no "Error:" in output
test_init_success_output_has_no_error() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local output
    output=$("$GITCREW" init 2>&1)
    assert_not_contains "$output" "Error:" "init success should not print Error"

    teardown_sandbox "$sandbox"
}

test_init_creates_role_files() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init >/dev/null 2>&1

    assert_file_exists ".agent/roles/feature.md"
    assert_file_exists ".agent/roles/bugfix.md"
    assert_file_exists ".agent/roles/quality.md"
    assert_file_exists ".agent/roles/docs.md"
    assert_file_exists ".agent/roles/integration.md"

    teardown_sandbox "$sandbox"
}

test_init_creates_docker_files() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init >/dev/null 2>&1

    assert_file_exists ".agent/spawn-docker.sh"
    assert_file_exists ".agent/docker-compose.agents.yml"

    teardown_sandbox "$sandbox"
}

test_init_creates_git_hooks() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init >/dev/null 2>&1

    assert_file_exists ".githooks/pre-push"

    teardown_sandbox "$sandbox"
}

test_init_scripts_are_executable() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init >/dev/null 2>&1

    [ -x ".agent/detect-project.sh" ] || { echo "detect-project.sh not executable"; return 1; }
    [ -x ".agent/run-tests.sh" ] || { echo "run-tests.sh not executable"; return 1; }
    [ -x ".agent/run-loop.sh" ] || { echo "run-loop.sh not executable"; return 1; }

    teardown_sandbox "$sandbox"
}

test_init_no_docker_flag() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-docker >/dev/null 2>&1

    assert_file_exists ".agent/TASKS.md"
    [ ! -f ".agent/spawn-docker.sh" ] || { echo "spawn-docker.sh should not exist"; return 1; }
    [ ! -f ".agent/docker-compose.agents.yml" ] || { echo "docker-compose.agents.yml should not exist"; return 1; }

    teardown_sandbox "$sandbox"
}

test_init_no_roles_flag() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-roles >/dev/null 2>&1

    assert_file_exists ".agent/TASKS.md"
    [ ! -f ".agent/roles/feature.md" ] || { echo "feature.md should not exist"; return 1; }
    [ ! -f ".agent/roles/bugfix.md" ] || { echo "bugfix.md should not exist"; return 1; }

    teardown_sandbox "$sandbox"
}

test_init_no_hooks_flag() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks >/dev/null 2>&1

    assert_file_exists ".agent/TASKS.md"
    [ ! -f ".githooks/pre-push" ] || { echo "pre-push should not exist"; return 1; }

    teardown_sandbox "$sandbox"
}

test_init_fails_without_git_repo() {
    local sandbox
    sandbox=$(mktemp -d)
    cd "$sandbox"

    local exit_code=0
    "$GITCREW" init >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code"

    cd "$REPO_ROOT"
    rm -rf "$sandbox"
}

test_init_refuses_overwrite_without_force() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init >/dev/null 2>&1

    local exit_code=0
    "$GITCREW" init >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_init_force_overwrites() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init >/dev/null 2>&1
    "$GITCREW" init --force >/dev/null 2>&1

    assert_file_exists ".agent/TASKS.md"

    teardown_sandbox "$sandbox"
}

# Regression: .agent/ may exist for other tools; only refuse overwrite when it's a gitcrew setup
test_init_succeeds_when_agent_dir_exists_but_not_gitcrew() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    mkdir -p .agent
    echo "other tool config" > .agent/some-other-file.txt

    "$GITCREW" init >/dev/null 2>&1

    assert_file_exists ".agent/TASKS.md"
    assert_file_exists ".agent/PROMPT.md"
    assert_file_exists ".agent/run-tests.sh"
    # Original non-gitcrew file still there (init adds/overwrites only its own files)
    assert_file_exists ".agent/some-other-file.txt"

    teardown_sandbox "$sandbox"
}

test_init_refuses_overwrite_when_agent_dir_is_gitcrew() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init >/dev/null 2>&1
    echo "custom" >> .agent/TASKS.md

    local exit_code=0
    "$GITCREW" init >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_init_help_shows_usage() {
    local sandbox exit_code
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local output
    output=$("$GITCREW" init --help 2>&1)
    assert_contains "$output" "USAGE"
    assert_contains "$output" "OPTIONS"
    assert_contains "$output" "--help"
    exit_code=0; "$GITCREW" init --help >/dev/null 2>&1 || exit_code=$?
    assert_eq "0" "$exit_code" "init --help should exit 0"
    exit_code=0; "$GITCREW" init -h >/dev/null 2>&1 || exit_code=$?
    assert_eq "0" "$exit_code" "init -h should exit 0"

    teardown_sandbox "$sandbox"
}

test_init_unknown_option_fails() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local output
    output=$("$GITCREW" init --unknown 2>&1)
    assert_contains "$output" "Unknown option"
    assert_contains "$output" "unknown"
    local exit_code=0
    "$GITCREW" init --unknown >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code" "init --unknown should exit 1"

    teardown_sandbox "$sandbox"
}
