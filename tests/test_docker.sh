#!/usr/bin/env bash
# Tests for gitcrew docker command

test_docker_help_shows_subcommands() {
    local output
    output=$("$GITCREW" docker --help 2>&1)
    assert_contains "$output" "build" "help shows build subcommand"
    assert_contains "$output" "test" "help shows test subcommand"
    assert_contains "$output" "ps" "help shows ps subcommand"
    assert_contains "$output" "stop" "help shows stop subcommand"
    assert_contains "$output" "logs" "help shows logs subcommand"
    assert_contains "$output" "clean" "help shows clean subcommand"
}

test_docker_no_args_shows_usage() {
    local output
    output=$("$GITCREW" docker 2>&1)
    assert_contains "$output" "USAGE" "no args shows usage"
    assert_contains "$output" "gitcrew docker" "shows command format"
}

test_docker_unknown_subcommand_fails() {
    local output
    output=$("$GITCREW" docker foobar 2>&1) && return 1
    assert_contains "$output" "Unknown docker subcommand" "shows error for unknown subcommand"
}

test_docker_logs_requires_agent_name() {
    # Skip if docker is not available (e.g., running inside a container)
    if ! command -v docker &>/dev/null; then
        echo "SKIP: docker not available"
        return 0
    fi
    local output
    output=$("$GITCREW" docker logs 2>&1) && return 1
    assert_contains "$output" "Agent name required" "logs requires agent name"
}

test_docker_ps_runs_without_error() {
    # docker ps should work even with no containers
    if ! command -v docker &>/dev/null; then
        echo "SKIP: docker not available"
        return 0
    fi
    local output
    output=$("$GITCREW" docker ps 2>&1)
    # Should either show containers or "No running" message
    echo "$output" | grep -qE "(gitcrew|No running)" || {
        echo "Expected container list or 'No running' message"
        echo "Got: $output"
        return 1
    }
}
