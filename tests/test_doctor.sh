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
