#!/usr/bin/env bash
# Tests for gitcrew hooks

test_hooks_installs_pre_push() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks 2>&1 >/dev/null
    "$GITCREW" hooks 2>&1 >/dev/null

    assert_file_exists ".githooks/pre-push"
    [ -x ".githooks/pre-push" ] || { echo "pre-push should be executable"; return 1; }

    teardown_sandbox "$sandbox"
}

test_hooks_sets_git_config() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks 2>&1 >/dev/null
    "$GITCREW" hooks 2>&1 >/dev/null

    local hooks_path
    hooks_path=$(git config core.hooksPath)
    assert_eq ".githooks" "$hooks_path"

    teardown_sandbox "$sandbox"
}

test_hooks_remove() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks 2>&1 >/dev/null
    "$GITCREW" hooks 2>&1 >/dev/null
    "$GITCREW" hooks --remove 2>&1 >/dev/null

    local hooks_path
    hooks_path=$(git config core.hooksPath 2>/dev/null || echo "")
    assert_eq "" "$hooks_path"

    teardown_sandbox "$sandbox"
}
