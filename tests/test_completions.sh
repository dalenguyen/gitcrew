#!/usr/bin/env bash
# Tests for shell completion scripts

test_completions_bash_outputs_script() {
    local output
    output=$("$GITCREW" --completions bash)
    assert_contains "$output" "complete -F _gitcrew gitcrew" "bash completion contains complete command"
    assert_contains "$output" "COMPREPLY" "bash completion uses COMPREPLY"
}

test_completions_zsh_outputs_script() {
    local output
    output=$("$GITCREW" --completions zsh)
    assert_contains "$output" "#compdef gitcrew" "zsh completion contains compdef"
    assert_contains "$output" "_gitcrew" "zsh completion defines _gitcrew function"
}

test_completions_unknown_shell_fails() {
    local output
    output=$("$GITCREW" --completions fish 2>&1) && return 1
    assert_contains "$output" "No completions for 'fish'" "shows error for unknown shell"
}

test_completions_default_is_bash() {
    local output
    output=$("$GITCREW" --completions)
    assert_contains "$output" "complete -F _gitcrew gitcrew" "default completion is bash"
}
