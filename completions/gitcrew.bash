#!/usr/bin/env bash
# Bash completion for gitcrew
#
# Install:
#   source <(gitcrew --completions bash)
#   # or copy to: /etc/bash_completion.d/gitcrew

_gitcrew() {
    local cur prev commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    commands="init spawn monitor task doctor hooks log status docker pr"

    case "$prev" in
        gitcrew)
            COMPREPLY=($(compgen -W "$commands --help --version" -- "$cur"))
            return 0
            ;;
        init)
            COMPREPLY=($(compgen -W "--force --no-roles --no-docker --no-hooks --help" -- "$cur"))
            return 0
            ;;
        spawn)
            COMPREPLY=($(compgen -W "--cli --model --docker --dry-run --once --help" -- "$cur"))
            return 0
            ;;
        --cli)
            COMPREPLY=($(compgen -W "claude cursor aider codex" -- "$cur"))
            return 0
            ;;
        task)
            COMPREPLY=($(compgen -W "list add lock done unlock import clear-done --help" -- "$cur"))
            return 0
            ;;
        monitor)
            COMPREPLY=($(compgen -W "--interval --once --help" -- "$cur"))
            return 0
            ;;
        doctor)
            COMPREPLY=($(compgen -W "--fix --help" -- "$cur"))
            return 0
            ;;
        hooks)
            COMPREPLY=($(compgen -W "--remove --help" -- "$cur"))
            return 0
            ;;
        log)
            COMPREPLY=($(compgen -W "show --help" -- "$cur"))
            return 0
            ;;
        status)
            COMPREPLY=($(compgen -W "--help" -- "$cur"))
            return 0
            ;;
        docker)
            COMPREPLY=($(compgen -W "build test ps stop logs clean --help" -- "$cur"))
            return 0
            ;;
        pr)
            COMPREPLY=($(compgen -W "create review flow merge --help" -- "$cur"))
            return 0
            ;;
    esac
}

complete -F _gitcrew gitcrew
