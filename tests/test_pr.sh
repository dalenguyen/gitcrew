#!/usr/bin/env bash
# Tests for gitcrew pr command

test_pr_help_shows_subcommands() {
    local output
    output=$("$GITCREW" pr --help 2>&1)
    assert_contains "$output" "create"
    assert_contains "$output" "review"
    assert_contains "$output" "flow"
    assert_contains "$output" "merge"
    assert_contains "$output" "issue"
}

test_pr_no_args_shows_usage() {
    local output
    output=$("$GITCREW" pr 2>&1)
    assert_contains "$output" "USAGE"
    assert_contains "$output" "create"
    assert_contains "$output" "review"
}

test_pr_create_on_main_fails() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox" || { echo "cd failed"; exit 1; }
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    # On main branch, pr create should fail (need feature branch)
    local output
    output=$("$GITCREW" pr create 2>&1) && return 1
    assert_contains "$output" "feature branch"

    teardown_sandbox "$sandbox"
}

test_pr_create_requires_gh() {
    # If gh is not in PATH, pr create should fail with helpful message
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox" || { echo "cd failed"; exit 1; }
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1
    git checkout -b Agent-Test/some-feature 2>/dev/null

    local output
    if command -v gh &>/dev/null; then
        # gh exists; may pass pre-check and fail later or succeed - skip the "requires gh" assertion
        output=$("$GITCREW" pr create 2>&1) || true
        assert_contains "$output" "gh\|Error\|Creating\|PR"
    else
        output=$("$GITCREW" pr create 2>&1) && return 1
        assert_contains "$output" "gh"
    fi

    teardown_sandbox "$sandbox"
}

test_pr_unknown_subcommand_fails() {
    local output
    output=$("$GITCREW" pr invalid 2>&1) && return 1
    assert_contains "$output" "Unknown subcommand"
}

test_pr_flow_on_main_fails() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox" || { echo "cd failed"; exit 1; }
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" pr flow 2>&1) && return 1
    assert_contains "$output" "feature branch"

    teardown_sandbox "$sandbox"
}

test_pr_flow_help_shows_skip_review() {
    local output
    output=$("$GITCREW" pr flow --help 2>&1)
    assert_contains "$output" "skip-review"
}

test_pr_merge_on_main_fails() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox" || { echo "cd failed"; exit 1; }
    "$GITCREW" init --no-docker --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" pr merge 2>&1) && return 1
    assert_contains "$output" "Not on a feature branch"

    teardown_sandbox "$sandbox"
}

test_pr_review_role_file_exists_after_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox" || { echo "cd failed"; exit 1; }
    "$GITCREW" init --no-hooks >/dev/null 2>&1

    assert_file_exists ".agent/roles/review.md"
    assert_contains "$(cat .agent/roles/review.md)" "Code Reviewer"
    assert_contains "$(cat .agent/roles/review.md)" "Must fix"

    teardown_sandbox "$sandbox"
}
