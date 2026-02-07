#!/usr/bin/env bash
# Tests for the main gitcrew CLI entry point

test_version_flag() {
    local output
    output=$("$GITCREW" --version 2>&1)
    assert_contains "$output" "gitcrew v"
}

test_help_flag() {
    local output
    output=$("$GITCREW" --help 2>&1)
    assert_contains "$output" "USAGE"
    assert_contains "$output" "COMMANDS"
    assert_contains "$output" "init"
    assert_contains "$output" "spawn"
    assert_contains "$output" "monitor"
    assert_contains "$output" "task"
    assert_contains "$output" "doctor"
    assert_contains "$output" "hooks"
}

test_no_args_shows_help() {
    local output
    output=$("$GITCREW" 2>&1)
    assert_contains "$output" "USAGE"
}

test_unknown_command_fails() {
    local exit_code=0
    "$GITCREW" notacommand 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code"
}
