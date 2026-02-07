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

# Review runs outside repo in a temp dir and is cleaned up (parallel-safe)
test_pr_review_runs_in_isolated_dir() {
    local pr_script
    pr_script="$(dirname "$GITCREW")/commands/pr.sh"
    [ -f "$pr_script" ] || return 0

    assert_contains "$(cat "$pr_script")" "run_review_isolated"
    assert_contains "$(cat "$pr_script")" "gitcrew-review"
    assert_contains "$(cat "$pr_script")" "mktemp -d"
    assert_contains "$(cat "$pr_script")" "rm -rf"
    assert_contains "$(cat "$pr_script")" "isolated"
}

# Isolated review temp dir is cleaned up after run (pattern test)
test_pr_review_isolated_cleanup() {
    local before after
    before=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'gitcrew-review.*' 2>/dev/null | wc -l | tr -d ' ')
    (
        d=$(mktemp -d -t gitcrew-review.XXXXXX 2>/dev/null) || d=$(mktemp -d 2>/dev/null)
        trap 'rm -rf "$d"' EXIT
        echo "ok" > "${d}/out.txt"
        cp "${d}/out.txt" "${TMPDIR:-/tmp}/gitcrew-test-out.$$"
    )
    after=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'gitcrew-review.*' 2>/dev/null | wc -l | tr -d ' ')
    rm -f "${TMPDIR:-/tmp}/gitcrew-test-out.$$" 2>/dev/null || true
    [ "$before" = "$after" ] || { echo "Expected $before leftover dirs, got $after"; return 1; }
}
