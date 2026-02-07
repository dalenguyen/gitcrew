#!/usr/bin/env bash
# Tests for gitcrew init

test_init_creates_agent_directory() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init 2>&1 >/dev/null
    assert_dir_exists ".agent"

    teardown_sandbox "$sandbox"
}

test_init_creates_core_files() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init 2>&1 >/dev/null

    assert_file_exists ".agent/TASKS.md"
    assert_file_exists ".agent/LOG.md"
    assert_file_exists ".agent/PROMPT.md"
    assert_file_exists ".agent/detect-project.sh"
    assert_file_exists ".agent/run-tests.sh"
    assert_file_exists ".agent/run-loop.sh"
    assert_file_exists ".agent/monitor.sh"

    teardown_sandbox "$sandbox"
}

test_init_creates_role_files() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init 2>&1 >/dev/null

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

    "$GITCREW" init 2>&1 >/dev/null

    assert_file_exists ".agent/spawn-docker.sh"
    assert_file_exists ".agent/docker-compose.agents.yml"

    teardown_sandbox "$sandbox"
}

test_init_creates_git_hooks() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init 2>&1 >/dev/null

    assert_file_exists ".githooks/pre-push"

    teardown_sandbox "$sandbox"
}

test_init_scripts_are_executable() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init 2>&1 >/dev/null

    [ -x ".agent/detect-project.sh" ] || { echo "detect-project.sh not executable"; return 1; }
    [ -x ".agent/run-tests.sh" ] || { echo "run-tests.sh not executable"; return 1; }
    [ -x ".agent/run-loop.sh" ] || { echo "run-loop.sh not executable"; return 1; }

    teardown_sandbox "$sandbox"
}

test_init_no_docker_flag() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-docker 2>&1 >/dev/null

    assert_file_exists ".agent/TASKS.md"
    [ ! -f ".agent/spawn-docker.sh" ] || { echo "spawn-docker.sh should not exist"; return 1; }
    [ ! -f ".agent/docker-compose.agents.yml" ] || { echo "docker-compose.agents.yml should not exist"; return 1; }

    teardown_sandbox "$sandbox"
}

test_init_no_roles_flag() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-roles 2>&1 >/dev/null

    assert_file_exists ".agent/TASKS.md"
    [ ! -f ".agent/roles/feature.md" ] || { echo "feature.md should not exist"; return 1; }
    [ ! -f ".agent/roles/bugfix.md" ] || { echo "bugfix.md should not exist"; return 1; }

    teardown_sandbox "$sandbox"
}

test_init_no_hooks_flag() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks 2>&1 >/dev/null

    assert_file_exists ".agent/TASKS.md"
    [ ! -f ".githooks/pre-push" ] || { echo "pre-push should not exist"; return 1; }

    teardown_sandbox "$sandbox"
}

test_init_fails_without_git_repo() {
    local sandbox
    sandbox=$(mktemp -d)
    cd "$sandbox"

    local exit_code=0
    "$GITCREW" init 2>&1 >/dev/null || exit_code=$?
    assert_eq "1" "$exit_code"

    cd "$REPO_ROOT"
    rm -rf "$sandbox"
}

test_init_refuses_overwrite_without_force() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init 2>&1 >/dev/null

    local exit_code=0
    "$GITCREW" init 2>&1 >/dev/null || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_init_force_overwrites() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init 2>&1 >/dev/null
    "$GITCREW" init --force 2>&1 >/dev/null

    assert_file_exists ".agent/TASKS.md"

    teardown_sandbox "$sandbox"
}
