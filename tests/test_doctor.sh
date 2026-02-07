#!/usr/bin/env bash
# Tests for gitcrew doctor

test_doctor_passes_after_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks >/dev/null 2>&1

    local output
    output=$("$GITCREW" doctor 2>&1)
    assert_contains "$output" "PASS"
    assert_contains "$output" "0 failed"

    teardown_sandbox "$sandbox"
}

test_doctor_fails_without_init() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local exit_code=0
    "$GITCREW" doctor >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code"

    teardown_sandbox "$sandbox"
}

test_doctor_detects_missing_files() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks >/dev/null 2>&1
    rm .agent/PROMPT.md

    local output
    output=$("$GITCREW" doctor 2>&1)
    assert_contains "$output" "FAIL"
    assert_contains "$output" "PROMPT.md"

    teardown_sandbox "$sandbox"
}

test_doctor_detects_tasks_in_backlog() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks >/dev/null 2>&1
    "$GITCREW" task add "Test task" >/dev/null 2>&1

    local output
    output=$("$GITCREW" doctor 2>&1)
    assert_contains "$output" "1 task(s) in backlog"

    teardown_sandbox "$sandbox"
}

# Regression: doctor should warn when run-tests.sh is still the template (has # TODO: Replace)
test_doctor_warns_uncustomized_run_tests() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks >/dev/null 2>&1
    # Template contains "# TODO: Replace"; doctor should warn
    local output
    output=$("$GITCREW" doctor 2>&1)
    assert_contains "$output" "uncustomized"
    assert_contains "$output" "run-tests.sh"

    teardown_sandbox "$sandbox"
}

# When run-tests.sh no longer has the template TODO, doctor should report configured
test_doctor_run_tests_configured_when_customized() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks >/dev/null 2>&1
    # Remove the TODO line so doctor treats it as customized (portable: no sed -i)
    grep -v '# TODO: Replace' .agent/run-tests.sh > .agent/run-tests.sh.tmp
    mv .agent/run-tests.sh.tmp .agent/run-tests.sh
    local output
    output=$("$GITCREW" doctor 2>&1)
    assert_contains "$output" "run-tests.sh configured"

    teardown_sandbox "$sandbox"
}

test_doctor_help_shows_usage() {
    local sandbox exit_code
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local output
    output=$("$GITCREW" doctor --help 2>&1)
    assert_contains "$output" "USAGE"
    assert_contains "$output" "OPTIONS"
    assert_contains "$output" "--fix"
    exit_code=0; "$GITCREW" doctor --help >/dev/null 2>&1 || exit_code=$?
    assert_eq "0" "$exit_code" "doctor --help should exit 0"
    exit_code=0; "$GITCREW" doctor -h >/dev/null 2>&1 || exit_code=$?
    assert_eq "0" "$exit_code" "doctor -h should exit 0"

    teardown_sandbox "$sandbox"
}

test_doctor_unknown_option_fails() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    local output
    output=$("$GITCREW" doctor --unknown 2>&1)
    assert_contains "$output" "Unknown option"
    assert_contains "$output" "unknown"
    local exit_code=0
    "$GITCREW" doctor --unknown >/dev/null 2>&1 || exit_code=$?
    assert_eq "1" "$exit_code" "doctor --unknown should exit 1"

    teardown_sandbox "$sandbox"
}

test_doctor_fix_makes_script_executable() {
    local sandbox
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init --no-hooks >/dev/null 2>&1
    chmod -x .agent/run-tests.sh
    [ ! -x .agent/run-tests.sh ] || { echo "precondition: run-tests.sh should not be executable"; return 1; }

    local output
    output=$("$GITCREW" doctor --fix 2>&1)
    assert_contains "$output" "Fixed"
    assert_contains "$output" "executable"
    [ -x .agent/run-tests.sh ] || { echo "run-tests.sh should be executable after doctor --fix"; return 1; }

    teardown_sandbox "$sandbox"
}
