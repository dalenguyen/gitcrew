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

test_hooks_pre_push_blocks_stale_branch() {
    # Setup: create a "remote" bare repo with explicit 'main' default branch
    local remote
    remote=$(mktemp -d)
    git init --bare --quiet --initial-branch=main "$remote" 2>/dev/null \
        || { git init --bare --quiet "$remote"; git -C "$remote" symbolic-ref HEAD refs/heads/main; }

    local working
    working=$(mktemp -d)
    git clone --quiet "$remote" "$working"
    cd "$working"
    git config user.name "Test"
    git config user.email "test@gitcrew.local"

    # Ensure we're on 'main' branch (handles older git that defaults to 'master')
    git checkout -b main 2>/dev/null || true

    # Initialize gitcrew
    "$GITCREW" init --no-hooks 2>&1 >/dev/null

    # Create a simple run-tests.sh that always passes
    cat > .agent/run-tests.sh << 'TESTSEOF'
#!/bin/bash
echo "tests pass"
exit 0
TESTSEOF

    # Initial commit and push to main
    git add -A
    git commit -m "init" --quiet
    git push --quiet origin main 2>/dev/null || git push --quiet -u origin HEAD:main 2>/dev/null

    # Simulate another agent pushing a new commit to main
    local other
    other=$(mktemp -d)
    git clone --quiet -b main "$remote" "$other"
    cd "$other"
    git config user.name "OtherAgent"
    git config user.email "other@gitcrew.local"
    echo "new work" > newfile.txt
    git add newfile.txt
    git commit -m "other agent work" --quiet
    git push --quiet origin main

    # Back to our working dir: create feature branch WITHOUT pulling latest main
    cd "$working"
    git checkout -b Agent-Test/my-feature --quiet
    echo "my work" > myfile.txt
    git add myfile.txt
    git commit -m "my feature" --quiet

    # Install the real pre-push hook from the repo
    mkdir -p .githooks
    cp "${REPO_ROOT}/.githooks/pre-push" .githooks/pre-push
    chmod +x .githooks/pre-push
    git config core.hooksPath .githooks

    # Try to push — should be blocked because we're behind origin/main
    local output
    if output=$(git push origin Agent-Test/my-feature 2>&1); then
        echo "Push should have been blocked but succeeded"
        rm -rf "$remote" "$working" "$other"
        return 1
    fi
    assert_contains "$output" "behind main" "should mention branch is behind main"

    # Cleanup
    cd "$REPO_ROOT"
    rm -rf "$remote" "$working" "$other"
}

test_hooks_pre_push_allows_rebased_branch() {
    # Setup: create a "remote" bare repo with explicit 'main' default branch
    local remote
    remote=$(mktemp -d)
    git init --bare --quiet --initial-branch=main "$remote" 2>/dev/null \
        || { git init --bare --quiet "$remote"; git -C "$remote" symbolic-ref HEAD refs/heads/main; }

    local working
    working=$(mktemp -d)
    git clone --quiet "$remote" "$working"
    cd "$working"
    git config user.name "Test"
    git config user.email "test@gitcrew.local"

    # Ensure we're on 'main' branch
    git checkout -b main 2>/dev/null || true

    # Initialize gitcrew
    "$GITCREW" init --no-hooks 2>&1 >/dev/null

    # Create a simple run-tests.sh that always passes
    cat > .agent/run-tests.sh << 'TESTSEOF'
#!/bin/bash
echo "tests pass"
exit 0
TESTSEOF

    # Initial commit and push to main
    git add -A
    git commit -m "init" --quiet
    git push --quiet origin main 2>/dev/null || git push --quiet -u origin HEAD:main 2>/dev/null

    # Create feature branch (from up-to-date main — no divergence)
    git checkout -b Agent-Test/my-feature --quiet
    echo "my work" > myfile.txt
    git add myfile.txt
    git commit -m "my feature" --quiet

    # Install the real pre-push hook from the repo
    mkdir -p .githooks
    cp "${REPO_ROOT}/.githooks/pre-push" .githooks/pre-push
    chmod +x .githooks/pre-push
    git config core.hooksPath .githooks

    # Push should succeed (branch includes all of origin/main)
    local output
    if ! output=$(git push origin Agent-Test/my-feature 2>&1); then
        echo "Push should have succeeded but was blocked"
        echo "$output"
        rm -rf "$remote" "$working"
        return 1
    fi
    assert_contains "$output" "up to date with main" "should confirm branch is current"

    # Cleanup
    cd "$REPO_ROOT"
    rm -rf "$remote" "$working"
}
